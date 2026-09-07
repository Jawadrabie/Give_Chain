import 'package:flutter/foundation.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';
import '../../catalog/data/catalog_models.dart';
import 'benefit_models.dart';
import 'benefit_request_store.dart';

/// Data access for the Benefits feature: browsing the benefit types a charity
/// offers, applying for one, and listing the requests the signed-in user has
/// submitted.
class BenefitRepository {
  BenefitRepository(this._client, [this._submissions]);
  final ApiClient _client;

  /// Caches what each submission contained, to paper over the fields the
  /// list endpoint currently drops. Optional so tests can omit it.
  final BenefitRequestStore? _submissions;

  /// How long a 404 from the lookup endpoint suppresses further attempts.
  ///
  /// The lookup is the real contract; it simply has not been deployed yet. So
  /// a 404 must never be treated as permanent — it only earns a short pause,
  /// after which the endpoint is tried again. That way an app left open across
  /// the deployment starts using the lookup on its own, within a minute,
  /// instead of staying on the fallback until it is restarted.
  static const _lookupRetryDelay = Duration(minutes: 1);

  /// When the lookup last 404d, or null if it has not (or the pause lapsed).
  static DateTime? _lookupMissingSince;

  static bool get _shouldTryLookup {
    final since = _lookupMissingSince;
    if (since == null) return true;
    if (DateTime.now().difference(since) < _lookupRetryDelay) return false;
    _lookupMissingSince = null;
    return true;
  }

  /// Forgets a recorded 404 so a test starts from "not yet known".
  @visibleForTesting
  static void debugResetLookupProbe() => _lookupMissingSince = null;

  /// Benefit types the user can apply for.
  ///
  /// Pass [charityId] to scope the list to one charity (the Benefits tab of a
  /// charity); omit it to list active types across every charity (the Add flow
  /// opened from the profile).
  ///
  /// `/api/lookup/benefit-types` is the endpoint this feature is built on. It
  /// is not deployed yet, so while it answers 404 the per-charity path — which
  /// serves an identical payload — stands in, and a charity-less call is
  /// served by fanning out across the charity list. Both are transparent: the
  /// caller gets the same result either way, and once the lookup ships every
  /// call goes straight to it with no code change.
  Future<List<BenefitType>> benefitTypes({
    String charityId = '',
    bool forceRefresh = false,
  }) async {
    final scoped = charityId.trim();

    if (_shouldTryLookup) {
      try {
        final raw = await _client.get(
          ApiPaths.benefitTypesLookup,
          query: {if (scoped.isNotEmpty) 'charityId': scoped},
          requiresAuth: false,
          cacheTtl: const Duration(hours: 2),
          forceRefresh: forceRefresh,
        );
        _lookupMissingSince = null;
        return _activeTypes(raw);
      } on ApiFailure catch (failure) {
        if (failure.statusCode != 404) rethrow;
        _lookupMissingSince = DateTime.now();
      }
    }

    return scoped.isEmpty
        ? _allCharityBenefitTypes(forceRefresh: forceRefresh)
        : charityBenefitTypes(scoped, forceRefresh: forceRefresh);
  }

  /// Every benefit on offer, grouped by name across charities.
  ///
  /// Backs the "هل تحتاج إلى مساعدة؟" flow, which asks what the user needs
  /// before which charity provides it. Offerings are ordered by how many
  /// charities provide them, so the most widely available help surfaces first.
  Future<List<BenefitOffering>> offerings() async {
    final types = await benefitTypes();
    final grouped = BenefitOffering.group(types)
      ..sort((a, b) {
        final byReach = b.types.length.compareTo(a.types.length);
        return byReach != 0 ? byReach : a.name.compareTo(b.name);
      });
    return grouped;
  }

  /// Stands in for the cross-charity lookup by asking each charity in turn.
  ///
  /// Only used while the lookup endpoint is missing. Charities are capped and
  /// fetched concurrently so the picker still opens promptly; a charity whose
  /// types fail to load is skipped rather than failing the whole list, since a
  /// partial picker is far more useful than an error screen.
  Future<List<BenefitType>> _allCharityBenefitTypes({
    bool forceRefresh = false,
  }) async {
    final raw = await _client.get(
      ApiPaths.charities,
      query: {'page': 1, 'pageSize': _fanOutCharityLimit},
      requiresAuth: false,
      cacheTtl: const Duration(hours: 2),
      forceRefresh: forceRefresh,
    );

    final charities = JsonHelpers.objectList(raw)
        .map((json) => (
          id: JsonHelpers.text(json, const ['id']),
          name: JsonHelpers.text(json, const ['charityName', 'name']),
        ))
        .where((charity) => charity.id.isNotEmpty)
        .toList();
    if (charities.isEmpty) return const [];

    final batches = await Future.wait([
      for (final charity in charities)
        charityBenefitTypes(charity.id, forceRefresh: forceRefresh)
            // The list endpoint labels the charity; the per-charity types
            // endpoint does not, so carry the name over for the picker.
            .then(
              (types) => [
                for (final type in types)
                  type.charityName.isEmpty && charity.name.isNotEmpty
                      ? type.withCharity(id: charity.id, name: charity.name)
                      : type,
              ],
            )
            .catchError((_) => const <BenefitType>[]),
    ]);

    return [for (final batch in batches) ...batch];
  }

  /// Upper bound on the fan-out above, so a large deployment cannot turn one
  /// picker into hundreds of requests.
  static const _fanOutCharityLimit = 50;

  /// The benefit types a single charity offers.
  Future<List<BenefitType>> charityBenefitTypes(
    String charityId, {
    bool forceRefresh = false,
  }) async {
    final raw = await _client.get(
      ApiPaths.charityBenefitTypes(charityId),
      requiresAuth: false,
      cacheTtl: const Duration(hours: 2),
      forceRefresh: forceRefresh,
    );
    return _activeTypes(raw);
  }

  List<BenefitType> _activeTypes(dynamic raw) => JsonHelpers.objectList(raw)
      .map(BenefitType.fromJson)
      .where((item) => item.isActive && item.id.isNotEmpty)
      .toList();

  /// Submits an application. [benefitTypeId] alone identifies the charity, so
  /// no charity id travels in the body.
  ///
  /// [benefitTypeName] and the charity labels are not sent anywhere — they
  /// are cached locally so the user's own list can show what the request was
  /// for, which the server does not currently echo back.
  Future<void> submit({
    required String benefitTypeId,
    required List<BenefitAnswer> answers,
    String benefitTypeName = '',
    String charityId = '',
    String charityName = '',
  }) async {
    final raw = await _client.post(
      ApiPaths.benefits,
      body: {
        'benefitTypeId': benefitTypeId,
        'answers': answers.map((item) => item.toJson()).toList(),
      },
    );
    final store = _submissions;
    if (store == null) return;
    final data = JsonHelpers.unwrap(raw);
    final requestId = data is Map
        ? JsonHelpers.text(Map<String, dynamic>.from(data), const ['id'])
        : '';
    if (requestId.isEmpty) return;
    await store.add(
      BenefitSubmissionRecord(
        requestId: requestId,
        benefitTypeId: benefitTypeId,
        benefitTypeName: benefitTypeName,
        charityId: charityId,
        charityName: charityName,
        submittedAt: DateTime.now(),
        answers: {
          for (final answer in answers) answer.questionId: answer.answer,
        },
      ),
    );
  }

  /// The signed-in user's benefit requests, newest first.
  ///
  /// [charityId] scopes the list to one charity. The backend has no such
  /// filter today and ignores the parameter, so the results are also filtered
  /// locally against the charity's own benefit-type ids — see
  /// [_charityFiltered]. Sending the parameter anyway means the server-side
  /// filter takes over automatically once it ships.
  Future<PageResult<BenefitRequest>> mine({
    int page = 1,
    int pageSize = 20,
    String benefitTypeId = '',
    String charityId = '',
  }) async {
    final scopedCharity = charityId.trim();
    final scopedType = benefitTypeId.trim();
    final raw = await _client.get(
      ApiPaths.benefits,
      query: {
        'page': page,
        'pageSize': pageSize,
        if (scopedType.isNotEmpty) 'benefitTypeId': scopedType,
        if (scopedCharity.isNotEmpty) 'charityId': scopedCharity,
      },
    );
    final items = JsonHelpers.objectList(raw)
        .map(BenefitRequest.fromJson)
        .map(_withCachedSubmission)
        .toList();
    final hasMore = JsonHelpers.hasMorePage(
      raw,
      page: page,
      pageSize: pageSize,
      receivedCount: items.length,
    );

    return PageResult(
      items: scopedCharity.isEmpty
          ? items
          : await _charityFiltered(items, scopedCharity),
      // `hasMore` must describe the *server's* paging, not the filtered list:
      // a page whose every item belonged to another charity still has to
      // advance, or the caller stops paging one page early.
      hasMore: hasMore,
    );
  }

  /// Fills in the fields the list endpoint drops from the local cache.
  ///
  /// Anything the server actually sent is left untouched, so this becomes a
  /// no-op as soon as the backend returns complete requests.
  BenefitRequest _withCachedSubmission(BenefitRequest request) {
    final cached = _submissions?.readAll()[request.id];
    if (cached == null) return request;
    return request.copyWith(
      benefitTypeId: request.benefitTypeId.isEmpty
          ? cached.benefitTypeId
          : null,
      benefitTypeName: request.benefitTypeName.isEmpty
          ? cached.benefitTypeName
          : null,
      charityId: request.charityId.isEmpty ? cached.charityId : null,
      charityName: request.charityName.isEmpty ? cached.charityName : null,
      submittedAt: request.submittedAtOrNull == null
          ? cached.submittedAt
          : null,
      answers: request.answers.isEmpty
          ? cached.answers.entries
                .map(
                  (entry) => BenefitAnswer(
                    questionId: entry.key,
                    answer: entry.value,
                  ),
                )
                .toList()
          : null,
    );
  }

  /// Keeps only the requests belonging to [charityId].
  ///
  /// Requests rarely carry a charity id of their own, so the charity's benefit
  /// types are fetched (cached for two hours) and used as the membership test,
  /// which also backfills [BenefitRequest.charityId] for the UI. If that
  /// lookup fails there is nothing safe to filter against — dropping every
  /// item would falsely read as "you have never applied here" — so the
  /// unfiltered page is returned instead.
  Future<List<BenefitRequest>> _charityFiltered(
    List<BenefitRequest> items,
    String charityId,
  ) async {
    if (items.isEmpty) return items;
    if (items.every((item) => item.charityId.isNotEmpty)) {
      return items.where((item) => item.charityId == charityId).toList();
    }

    final List<BenefitType> types;
    try {
      // Goes through [benefitTypes] rather than the per-charity path directly,
      // so this filter uses the lookup endpoint too once it is deployed.
      types = await benefitTypes(charityId: charityId);
    } on ApiFailure {
      return items;
    }
    final owned = types.map((type) => type.id).toSet();
    if (owned.isEmpty) return const [];

    return items
        .where(
          (item) => item.charityId.isEmpty
              ? owned.contains(item.benefitTypeId)
              : item.charityId == charityId,
        )
        .map((item) => item.copyWith(charityId: charityId))
        .toList();
  }

  /// Loads one request by id.
  ///
  /// There is no by-id endpoint, so this walks the user's own paged list.
  /// Bounded at 20 pages so a paging bug can never spin forever.
  Future<BenefitRequest> findMine(String id) async {
    const pageSize = 50;
    for (var page = 1; page <= 20; page++) {
      final result = await mine(page: page, pageSize: pageSize);
      for (final item in result.items) {
        if (item.id == id) return item;
      }
      if (!result.hasMore) break;
    }
    throw const ApiFailure('تعذر العثور على طلب المنفعة ضمن حسابك.');
  }
}
