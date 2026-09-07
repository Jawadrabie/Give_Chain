import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/storage/offline_storage_manager.dart';
import 'donation_history_store.dart';
import 'donation_models.dart';

class DonationRepository {
  const DonationRepository(this._client, this._historyStore);
  final ApiClient _client;
  final DonationHistoryStore _historyStore;

  Future<DonationResponse> create(
    DonationRequest request, {
    required String targetTitle,
  }) async {
    // Campaign/case donations use the pinned shortcut routes; a direct
    // charity donation has no such shortcut, so it falls back to the
    // general endpoint with the target fields included explicitly.
    final isShortcutTarget = request.targetType == 1 || request.targetType == 2;
    final path = request.targetType == 1
        ? ApiPaths.campaignDonation(request.targetId)
        : request.targetType == 2
            ? ApiPaths.caseDonation(request.targetId)
            : ApiPaths.donations;
    final reference = request.clientReference.trim().isEmpty
        ? 'givechain-${DateTime.now().toUtc().microsecondsSinceEpoch}'
        : request.clientReference.trim();
    final raw = await _client.multipart(
      'POST',
      path,
      fields: request.toMultipartFields(includeTarget: !isShortcutTarget),
      filePaths: request.attachments,
      fileField: 'attachments',
      headers: {'Idempotency-Key': reference},
    );
    final response = DonationResponse.fromJson(raw);
    if (response.id.isEmpty) {
      throw const ApiFailure('أنشأ الخادم استجابة تبرع غير مكتملة دون معرّف.');
    }
    await _historyStore.add(
      DonationRecord.fromSubmission(
        request: DonationRequest(
          targetId: request.targetId,
          targetType: request.targetType,
          donationType: request.donationType,
          caseNeedId: request.caseNeedId,
          message: request.message,
          amount: request.amount,
          paymentMethod: request.paymentMethod,
          itemName: request.itemName,
          itemDescription: request.itemDescription,
          quantity: request.quantity,
          unit: request.unit,
          serviceDescription: request.serviceDescription,
          scheduledAt: request.scheduledAt,
          deliveryMethod: request.deliveryMethod,
          attachments: request.attachments,
          clientReference: reference,
        ),
        response: response,
        targetTitle: targetTitle,
      ),
    );
    return response;
  }

  Future<DonationResponse> createGeneral(
    DonationRequest request, {
    required String targetTitle,
  }) async {
    final raw = await _client.multipart(
      'POST',
      ApiPaths.donations,
      fields: request.toMultipartFields(includeTarget: true),
      filePaths: request.attachments,
      fileField: 'attachments',
    );
    final response = DonationResponse.fromJson(raw);
    if (response.id.isEmpty) {
      throw const ApiFailure('أنشأ الخادم استجابة تبرع غير مكتملة دون معرّف.');
    }
    await _historyStore.add(
      DonationRecord.fromSubmission(
        request: request,
        response: response,
        targetTitle: targetTitle,
      ),
    );
    return response;
  }

  Future<DonationResponse> uploadProof(
    String donationId,
    List<String> filePaths,
  ) async {
    final raw = await _client.multipart(
      'POST',
      ApiPaths.donationProof(donationId),
      fields: const {},
      filePaths: filePaths,
      fileField: 'files',
    );
    final response = DonationResponse.fromJson(raw);
    if (response.id.isNotEmpty) {
      await _historyStore.upsertAll([
        DonationRecord.fromServer(_responseMap(response)),
      ]);
    }
    return response;
  }

  Future<DonationResponse> markDroppedAtCenter(String donationId) async {
    final raw = await _client.post(
      ApiPaths.donationDroppedAtCenter(donationId),
    );
    final response = DonationResponse.fromJson(raw);
    if (response.id.isNotEmpty) {
      await _historyStore.upsertAll([
        DonationRecord.fromServer(_responseMap(response)),
      ]);
    }
    return response;
  }

  Future<DonationHistorySnapshot> history({
    int page = 1,
    int pageSize = 20,
    int? status,
    bool? throughCenter,
  }) async {
    final local = _historyStore.readAll();
    try {
      final query = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        'status': ?status,
        'throughCenter': ?throughCenter,
      };
      final raw = await _client.get(
        ApiPaths.donations,
        query: query,
      );
      final responses = JsonHelpers.objectList(
        raw,
      ).map(DonationResponse.fromJson).toList();
      final serverRecords = responses
          .map((item) => DonationRecord.fromServer(_responseMap(item)))
          .toList();
      await _notifyStatusChanges(local, responses);
      await _historyStore.upsertAll(serverRecords);
      return DonationHistorySnapshot(
        records: _historyStore.readAll(),
        responses: responses,
        isServerBacked: true,
        hasMore: JsonHelpers.hasMorePage(
          raw,
          page: page,
          pageSize: pageSize,
          receivedCount: responses.length,
        ),
        page: page,
      );
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401 || failure.statusCode == 403) {
        rethrow;
      }
      return DonationHistorySnapshot(
        records: local,
        warning: 'تعذر مزامنة السجل مع الخادم، لذلك تُعرض النسخة المحلية.',
        page: page,
      );
    }
  }

  /// Attempts the create/createGeneral call and, when it fails because the
  /// device has no connectivity (an [ApiFailure] with no HTTP status code),
  /// queues the request via [OfflineStorageManager] for [trySyncQueuedDonations]
  /// to retry later instead of losing the donor's submission.
  Future<DonationResponse> createWithOfflineFallback(
    DonationRequest request, {
    required String targetTitle,
    bool useGeneral = false,
  }) async {
    try {
      return useGeneral
          ? await createGeneral(request, targetTitle: targetTitle)
          : await create(request, targetTitle: targetTitle);
    } on ApiFailure catch (failure) {
      if (failure.statusCode != null) rethrow;
      await OfflineStorageManager.enqueueOfflineAction({
        ...request.toQueueJson(),
        'targetTitle': targetTitle,
        'useGeneral': useGeneral,
      });
      throw const ApiFailure(
        'تعذر الاتصال بالإنترنت، فتم حفظ تبرعك محلياً وستتم محاولة إرساله '
        'تلقائياً عند استعادة الاتصال.',
      );
    }
  }

  /// Replays any donations queued by [createWithOfflineFallback] while the
  /// device was offline. Safe to call opportunistically (e.g. whenever the
  /// donor opens their donation history) since it silently keeps failed
  /// items queued for the next attempt.
  Future<void> trySyncQueuedDonations() async {
    final queue = await OfflineStorageManager.getOfflineQueue();
    if (queue.isEmpty) return;
    final stillPending = <Map<String, dynamic>>[];
    for (final action in queue) {
      final request = DonationRequest.fromQueueJson(action);
      final targetTitle = action['targetTitle']?.toString() ?? '';
      try {
        if (action['useGeneral'] == true) {
          await createGeneral(request, targetTitle: targetTitle);
        } else {
          await create(request, targetTitle: targetTitle);
        }
      } catch (_) {
        stillPending.add(action);
      }
    }
    await OfflineStorageManager.setOfflineQueue(stillPending);
  }

  Future<FundFlowGraph> traceAll() async {
    final raw = await _client.get(ApiPaths.donationTraceAll);
    return FundFlowGraph.fromJson(raw);
  }

  Future<FundFlowGraph> traceDonation(String donationId) async {
    final raw = await _client.get(ApiPaths.donationTrace(donationId));
    return FundFlowGraph.fromJson(raw);
  }

  Future<DonationResponse> findInHistory(String donationId) async {
    const pageSize = 50;
    for (var page = 1; page <= 20; page++) {
      final raw = await _client.get(
        ApiPaths.donations,
        query: {'page': page, 'pageSize': pageSize},
      );
      final responses = JsonHelpers.objectList(
        raw,
      ).map(DonationResponse.fromJson).toList();
      for (final item in responses) {
        if (item.id == donationId) return item;
      }
      if (!JsonHelpers.hasMorePage(
        raw,
        page: page,
        pageSize: pageSize,
        receivedCount: responses.length,
      )) {
        break;
      }
    }
    throw const ApiFailure('تعذر العثور على التبرع ضمن سجل حسابك.');
  }

  List<DonationRecord> localHistory() => _historyStore.readAll();
  Future<void> clearLocalHistory() => _historyStore.clear();

  // Kept for compatibility with existing UI. The current API has no donation
  // detail/status endpoint, so refreshing means reading the paged history.
  Future<DonationRecord> refreshStatus(DonationRecord record) async {
    final snapshot = await history(page: 1, pageSize: 100);
    return snapshot.records.firstWhere(
      (item) => item.remoteId == record.remoteId,
      orElse: () => record,
    );
  }

  /// Fires a local notification for every donation whose status changed
  /// since the last time it was cached locally (e.g. moved to "موثّق ✓" or
  /// "تم الاستلام في المركز"), so the donor is alerted without needing a
  /// push-notification backend.
  Future<void> _notifyStatusChanges(
    List<DonationRecord> previous,
    List<DonationResponse> current,
  ) async {
    final previousStatusByRemoteId = {
      for (final record in previous)
        if (record.remoteId != null) record.remoteId!: record.status,
    };
    for (final response in current) {
      final previousStatus = previousStatusByRemoteId[response.id];
      if (previousStatus == null || previousStatus == response.status.toString()) {
        continue;
      }
      await NotificationService.showDonationStatusNotification(
        title: 'تحديث حالة تبرعك',
        body: '${response.targetName}: ${response.statusLabel}',
        payload: response.id,
      );
    }
  }

  Map<String, dynamic> _responseMap(DonationResponse item) => {
    'id': item.id,
    'donationType': item.donationType,
    'targetType': item.targetType,
    'campaignId': item.campaignId,
    'campaignName': item.campaignName,
    'caseId': item.caseId,
    'status': item.status,
    'amount': item.amount,
    'paymentMethod': item.paymentMethod,
    'paymentUrl': item.paymentUrl,
    'itemName': item.itemName,
    'quantity': item.quantity,
    'serviceDescription': item.serviceDescription,
    'donationDate': item.donationDate.toIso8601String(),
  };
}
