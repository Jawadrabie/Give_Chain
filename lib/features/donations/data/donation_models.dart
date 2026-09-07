import '../../../core/constants/api_enums.dart';
import '../../../core/network/json_helpers.dart';
import '../../catalog/data/catalog_models.dart';

class DonationRouteData {
  const DonationRouteData({
    required this.target,
    required this.targetType,
    this.useGeneralEndpoint = false,
  });

  final CatalogItem target;

  /// 1 campaign, 2 case, 3 charity (direct donation to the charity's
  /// general pool, unassigned to any campaign/case).
  final int targetType;

  /// Uses POST /api/mobile/donations and includes the target fields.
  /// Target-specific entry points keep using /campaigns/{id}/donate or
  /// /cases/{id}/donate as documented by the backend team. A direct
  /// charity donation has no such shortcut and always uses this endpoint.
  final bool useGeneralEndpoint;

  bool get isCampaign => targetType == 1;
  bool get isCase => targetType == 2;
  bool get isCharity => targetType == 3;
}

class DonationRequest {
  const DonationRequest({
    required this.targetId,
    required this.targetType,
    required this.donationType,
    this.caseNeedId,
    this.centerId,
    this.message = '',
    this.amount,
    this.paymentMethod,
    this.itemName = '',
    this.itemDescription = '',
    this.quantity,
    this.unit,
    this.serviceDescription = '',
    this.scheduledAt,
    this.deliveryMethod,
    this.attachments = const [],
    this.clientReference = '',
  });

  final String targetId;
  final int targetType; // 1 campaign, 2 case, 3 charity (general pool)
  final int donationType; // 1 money, 2 item, 3 service
  final String? caseNeedId;
  final String? centerId;
  final String message;
  final double? amount;
  final int? paymentMethod;
  final String itemName;
  final String itemDescription;
  final int? quantity;
  final int? unit;
  final String serviceDescription;
  final DateTime? scheduledAt;
  final int? deliveryMethod;
  final List<String> attachments;
  final String clientReference;

  Map<String, dynamic> toMultipartFields({bool includeTarget = false}) => {
    'donationType': donationType,
    if (includeTarget) 'targetType': targetType,
    if (includeTarget && targetType == 1) 'campaignId': targetId,
    if (includeTarget && targetType == 2) 'caseId': targetId,
    if (includeTarget && targetType == 3) 'charityId': targetId,
    if (caseNeedId?.trim().isNotEmpty == true) 'caseNeedId': caseNeedId!.trim(),
    if (centerId?.trim().isNotEmpty == true) 'centerId': centerId!.trim(),
    if (message.trim().isNotEmpty) 'message': message.trim(),
    if (donationType == 1 && amount != null) 'amount': amount,
    if (donationType == 1 && paymentMethod != null)
      'paymentMethod': paymentMethod,
    if (donationType == 2) 'itemName': itemName.trim(),
    if (donationType == 2 && itemDescription.trim().isNotEmpty)
      'itemDescription': itemDescription.trim(),
    if (donationType == 2 && quantity != null) 'quantity': quantity,
    if (donationType == 2 && unit != null) 'unit': unit,
    if (donationType == 3) 'serviceDescription': serviceDescription.trim(),
    if (donationType == 3 && scheduledAt != null)
      'scheduledAt': scheduledAt!.toIso8601String(),
    if (donationType != 1 && deliveryMethod != null)
      'deliveryMethod': deliveryMethod,
  };

  /// Serializes the request for the offline sync queue (see
  /// [DonationRequest.fromQueueJson]). Kept separate from
  /// [toMultipartFields] because the queue must round-trip every field
  /// regardless of donation type, unlike the API payload above.
  Map<String, dynamic> toQueueJson() => {
    'targetId': targetId,
    'targetType': targetType,
    'donationType': donationType,
    'caseNeedId': caseNeedId,
    'centerId': centerId,
    'message': message,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'itemName': itemName,
    'itemDescription': itemDescription,
    'quantity': quantity,
    'unit': unit,
    'serviceDescription': serviceDescription,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'deliveryMethod': deliveryMethod,
    'attachments': attachments,
    'clientReference': clientReference,
  };

  factory DonationRequest.fromQueueJson(Map<String, dynamic> json) =>
      DonationRequest(
        targetId: json['targetId']?.toString() ?? '',
        targetType: _int(json['targetType']) ?? 1,
        donationType: _int(json['donationType']) ?? 1,
        caseNeedId: _nullable(json['caseNeedId']),
        centerId: _nullable(json['centerId']),
        message: json['message']?.toString() ?? '',
        amount: _double(json['amount']),
        paymentMethod: _int(json['paymentMethod']),
        itemName: json['itemName']?.toString() ?? '',
        itemDescription: json['itemDescription']?.toString() ?? '',
        quantity: _int(json['quantity']),
        unit: _int(json['unit']),
        serviceDescription: json['serviceDescription']?.toString() ?? '',
        scheduledAt: _date(json['scheduledAt']),
        deliveryMethod: _int(json['deliveryMethod']),
        attachments: (json['attachments'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        clientReference: json['clientReference']?.toString() ?? '',
      );
}

class DonationResponse {
  const DonationResponse({
    required this.id,
    required this.donationType,
    required this.targetType,
    required this.status,
    required this.donationDate,
    this.entityId = '',
    this.entityName = '',
    this.campaignId,
    this.campaignName = '',
    this.caseId,
    this.caseNeedId,
    this.charityId = '',
    this.userId = '',
    this.donorName = '',
    this.message = '',
    this.amount,
    this.paymentMethod,
    this.paymentStatus,
    this.paymentReference,
    this.acceptedAmount,
    this.paymentUrl,
    this.itemName = '',
    this.itemDescription = '',
    this.quantity,
    this.unit,
    this.acceptedQuantity,
    this.serviceDescription = '',
    this.scheduledAt,
    this.deliveryMethod,
    this.centerId,
    this.centerConfirmedAt,
    this.centerConfirmationNotes = '',
    this.transferredToCharityAt,
    this.verifiedAt,
    this.verificationNotes = '',
    this.mediaUrls = const [],
    this.isTrusted = false,
    this.isPosted = false,
  });

  final String id;
  final int donationType;
  final int targetType;
  final String entityId;
  final String entityName;
  final String? campaignId;
  final String campaignName;
  final String? caseId;
  final String? caseNeedId;
  final String charityId;
  final String userId;
  final String donorName;
  final String message;
  final DateTime donationDate;
  final int status;
  final double? amount;
  final int? paymentMethod;
  final int? paymentStatus;
  final String? paymentReference;
  final double? acceptedAmount;
  final String? paymentUrl;
  final String itemName;
  final String itemDescription;
  final int? quantity;
  final int? unit;
  final int? acceptedQuantity;
  final String serviceDescription;
  final DateTime? scheduledAt;
  final int? deliveryMethod;
  final String? centerId;
  final DateTime? centerConfirmedAt;
  final String centerConfirmationNotes;
  final DateTime? transferredToCharityAt;
  final DateTime? verifiedAt;
  final String verificationNotes;
  final List<String> mediaUrls;

  /// `campaign.isTrusted` from the backend, only meaningful when
  /// [targetType] is 1 (campaign) — a case/charity donation carries no
  /// nested `campaign` object and always resolves to `false`.
  final bool isTrusted;

  /// Distinguishes the two donor-facing stages the backend collapses onto
  /// `status == 7` for a center-routed donation: `false` means "received at
  /// center, not yet transferred", `true` means "transferred to the
  /// charity" (see [_stepsCompleted] in donation_screen.dart). Meaningless
  /// for any other `status` value.
  final bool isPosted;

  String get statusLabel => ApiEnums.donationStatus[status] ?? 'غير معروف';
  String get typeLabel => ApiEnums.donationType[donationType] ?? 'تبرع';
  String get paymentMethodLabel => paymentMethod == null
      ? ''
      : ApiEnums.paymentMethod[paymentMethod!] ?? 'طريقة دفع';
  String get targetName => entityName.isNotEmpty
      ? entityName
      : campaignName.isNotEmpty
          ? campaignName
          : switch (targetType) {
              2 => 'حالة إنسانية',
              3 => 'تبرع مباشر للجمعية',
              _ => 'حملة',
            };
  /// A bank-transfer money pledge still awaiting review with no proof
  /// attached yet. The backend has no "confirm payment" step (payment is
  /// always settled manually), so the only way to move such a donation
  /// forward is uploading the transfer receipt via
  /// `POST /donations/{id}/proof`.
  bool get needsProofUpload =>
      donationType == 1 &&
      paymentMethod == 1 &&
      mediaUrls.isEmpty &&
      status == 1;

  factory DonationResponse.fromJson(dynamic raw) {
    final data = JsonHelpers.unwrap(raw);
    if (data is String && data.trim().isNotEmpty) {
      return DonationResponse(
        id: data.trim(),
        donationType: 1,
        targetType: 1,
        status: 1,
        donationDate: DateTime.now().toUtc(),
      );
    }
    final json = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    final campaign = json['campaign'];
    final campaignJson = campaign is Map
        ? Map<String, dynamic>.from(campaign)
        : const <String, dynamic>{};
    return DonationResponse(
      id: JsonHelpers.text(json, const ['id', 'donationId', 'uuid']),
      donationType: _int(json['donationType']) ?? 1,
      targetType: _int(json['targetType']) ?? (json['caseId'] != null ? 2 : 1),
      entityId: JsonHelpers.text(json, const ['entityId']),
      entityName: JsonHelpers.text(json, const ['entityName']),
      campaignId: _nullable(json['campaignId']),
      campaignName: JsonHelpers.text(
        json,
        const ['campaignName'],
        fallback: JsonHelpers.text(campaignJson, const ['campaignName']),
      ),
      isTrusted: JsonHelpers.boolean(campaignJson, const ['isTrusted']),
      isPosted: JsonHelpers.boolean(json, const ['isPosted']),
      caseId: _nullable(json['caseId']),
      caseNeedId: _nullable(json['caseNeedId']),
      charityId: JsonHelpers.text(json, const ['charityId']),
      userId: JsonHelpers.text(json, const ['userId']),
      donorName: JsonHelpers.text(json, const ['donorName']),
      message: JsonHelpers.text(json, const ['message']),
      donationDate: _date(json['donationDate']) ?? DateTime.now().toUtc(),
      status: _int(json['status']) ?? 1,
      amount: _double(json['amount']),
      paymentMethod: _int(json['paymentMethod']),
      paymentStatus: _int(json['paymentStatus']),
      paymentReference: _nullable(json['paymentReference']),
      acceptedAmount: _double(json['acceptedAmount']),
      paymentUrl: _nullable(json['paymentUrl']),
      itemName: JsonHelpers.text(json, const ['itemName']),
      itemDescription: JsonHelpers.text(json, const ['itemDescription']),
      quantity: _int(json['quantity']),
      unit: _int(json['unit']),
      acceptedQuantity: _int(json['acceptedQuantity']),
      serviceDescription: JsonHelpers.text(json, const ['serviceDescription']),
      scheduledAt: _date(json['scheduledAt']),
      deliveryMethod: _int(json['deliveryMethod']),
      centerId: _nullable(json['centerId']),
      centerConfirmedAt: _date(json['centerConfirmedAt']),
      centerConfirmationNotes: JsonHelpers.text(json, const ['centerConfirmationNotes']),
      transferredToCharityAt: _date(json['transferredToCharityAt']),
      verifiedAt: _date(json['verifiedAt']),
      verificationNotes: JsonHelpers.text(json, const ['verificationNotes']),
      mediaUrls: _mediaUrls(json['medias']),
    );
  }

  factory DonationResponse.fromQuery(Map<String, String> query) =>
      DonationResponse(
        id: query['donationId'] ?? query['id'] ?? '',
        donationType: int.tryParse(query['donationType'] ?? '') ?? 1,
        targetType: int.tryParse(query['targetType'] ?? '') ?? 1,
        status: _queryStatus(query['status']),
        donationDate: DateTime.now().toUtc(),
        paymentUrl: query['paymentUrl'],
      );
}

class DonationRecord {
  const DonationRecord({
    required this.localId,
    required this.targetId,
    required this.targetTitle,
    required this.targetType,
    required this.amount,
    required this.donationType,
    required this.paymentMethod,
    required this.createdAt,
    required this.status,
    this.remoteId,
    this.paymentUrl,
    this.itemDescription = '',
    this.quantity = 0,
  });

  final String localId;
  final String targetId;
  final String targetTitle;
  final String targetType;
  final double amount;
  final String donationType;
  final String paymentMethod;
  final DateTime createdAt;
  final String status;
  final String? remoteId;
  final String? paymentUrl;
  final String itemDescription;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'targetId': targetId,
    'targetTitle': targetTitle,
    'targetType': targetType,
    'amount': amount,
    'donationType': donationType,
    'paymentMethod': paymentMethod,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'remoteId': remoteId,
    'paymentUrl': paymentUrl,
    'itemDescription': itemDescription,
    'quantity': quantity,
  };

  factory DonationRecord.fromSubmission({
    required DonationRequest request,
    required DonationResponse response,
    required String targetTitle,
  }) => DonationRecord(
    localId: request.clientReference.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : request.clientReference,
    targetId: request.targetId,
    targetTitle: targetTitle,
    targetType: _targetTypeSlug(request.targetType),
    amount: request.amount ?? 0,
    donationType: request.donationType.toString(),
    paymentMethod: request.paymentMethod?.toString() ?? '',
    createdAt: response.donationDate,
    status: response.status.toString(),
    remoteId: response.id,
    paymentUrl: response.paymentUrl,
    itemDescription: request.itemDescription.isNotEmpty
        ? request.itemDescription
        : request.serviceDescription,
    quantity: request.quantity ?? 0,
  );

  factory DonationRecord.fromServer(Map<String, dynamic> json) {
    final response = DonationResponse.fromJson(json);
    return DonationRecord(
      localId: response.id,
      // `entityId` is the documented target reference; campaignId/caseId are
      // not part of DonationResponse and would always resolve to ''.
      targetId: response.entityId.isNotEmpty
          ? response.entityId
          : response.campaignId ?? response.caseId ?? '',
      targetTitle: response.targetName,
      targetType: _targetTypeSlug(response.targetType),
      amount: response.amount ?? 0,
      donationType: response.donationType.toString(),
      paymentMethod: response.paymentMethod?.toString() ?? '',
      createdAt: response.donationDate,
      status: response.status.toString(),
      remoteId: response.id,
      paymentUrl: response.paymentUrl,
      itemDescription: response.itemDescription.isNotEmpty
          ? response.itemDescription
          : response.itemName.isNotEmpty
              ? response.itemName
              : response.serviceDescription,
      quantity: response.quantity ?? 0,
    );
  }

  factory DonationRecord.fromJson(Map<String, dynamic> json) => DonationRecord(
    localId: json['localId']?.toString() ?? '',
    targetId: json['targetId']?.toString() ?? '',
    targetTitle: json['targetTitle']?.toString() ?? 'تبرع',
    targetType: json['targetType']?.toString() ?? 'campaign',
    amount: _double(json['amount']) ?? 0,
    donationType: json['donationType']?.toString() ?? '1',
    paymentMethod: json['paymentMethod']?.toString() ?? '',
    createdAt: _date(json['createdAt']) ?? DateTime.now().toUtc(),
    status: json['status']?.toString() ?? '0',
    remoteId: _nullable(json['remoteId']),
    paymentUrl: _nullable(json['paymentUrl']),
    itemDescription: json['itemDescription']?.toString() ?? '',
    quantity: _int(json['quantity']) ?? 0,
  );

  DonationRecord copyWith({
    String? status,
    String? paymentUrl,
    String? remoteId,
  }) => DonationRecord(
    localId: localId,
    targetId: targetId,
    targetTitle: targetTitle,
    targetType: targetType,
    amount: amount,
    donationType: donationType,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
    status: status ?? this.status,
    remoteId: remoteId ?? this.remoteId,
    paymentUrl: paymentUrl ?? this.paymentUrl,
    itemDescription: itemDescription,
    quantity: quantity,
  );
}

class DonationHistorySnapshot {
  const DonationHistorySnapshot({
    required this.records,
    this.responses = const [],
    this.warning,
    this.isServerBacked = false,
    this.hasMore = false,
    this.page = 1,
  });
  final List<DonationRecord> records;
  final List<DonationResponse> responses;
  final String? warning;
  final bool isServerBacked;
  final bool hasMore;
  final int page;
}

class FundFlowNode {
  const FundFlowNode({
    required this.id,
    required this.type,
    required this.label,
  });
  final String id;
  final int type;
  final String label;
  factory FundFlowNode.fromJson(Map<String, dynamic> json) => FundFlowNode(
    id: JsonHelpers.text(json, const ['id']),
    type: _int(json['type']) ?? 0,
    label: JsonHelpers.text(json, const ['label']),
  );
}

class FundFlowEdge {
  const FundFlowEdge({
    required this.from,
    required this.to,
    required this.amount,
    required this.label,
  });
  final String from;
  final String to;
  final double amount;
  final String label;
  factory FundFlowEdge.fromJson(Map<String, dynamic> json) => FundFlowEdge(
    from: JsonHelpers.text(json, const ['from']),
    to: JsonHelpers.text(json, const ['to']),
    amount: _double(json['amount']) ?? 0,
    label: JsonHelpers.text(json, const ['label']),
  );
}

class FundFlowGraph {
  const FundFlowGraph({required this.nodes, required this.edges});
  final List<FundFlowNode> nodes;
  final List<FundFlowEdge> edges;
  factory FundFlowGraph.fromJson(dynamic raw) {
    final data = JsonHelpers.unwrap(raw);
    final json = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return FundFlowGraph(
      nodes: (json['nodes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) => FundFlowNode.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(),
      edges: (json['edges'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) => FundFlowEdge.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(),
    );
  }
}

/// `DonationTargetType` -> the slug persisted in the local history store.
String _targetTypeSlug(int targetType) => switch (targetType) {
  2 => 'case',
  3 => 'charity',
  _ => 'campaign',
};

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
double? _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');
List<String> _mediaUrls(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => JsonHelpers.text(Map<String, dynamic>.from(item), const [
              'url',
            ]),
          )
          .where((url) => url.isNotEmpty)
          .toList()
    : const [];
int _queryStatus(String? value) {
  final number = int.tryParse(value ?? '');
  if (number != null) return number;
  return switch (value?.toLowerCase()) {
    'paid' || 'completed' || 'verified' || 'success' => 3,
    'failed' || 'cancelled' => 5,
    _ => 0,
  };
}
