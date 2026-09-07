import '../../../core/constants/api_enums.dart';
import '../../../core/network/json_helpers.dart';

/// Who a complaint is filed against.
///
/// `ComplaintTargetType` on the API: 0 = the GiveChain platform itself,
/// 1 = a specific charity (the historical, and still default, behaviour).
abstract final class ComplaintTargetType {
  static const admin = 0;
  static const charity = 1;

  static const labels = {
    admin: 'منصة GiveChain',
    charity: 'جمعية',
  };
}

class ComplaintRequest {
  const ComplaintRequest({
    this.charityId = '',
    this.targetType = ComplaintTargetType.charity,
    required this.complaintType,
    required this.description,
    required this.severity,
    this.attachments = const [],
  });

  /// Required only when [targetType] is [ComplaintTargetType.charity]; the
  /// server ignores it for a platform complaint.
  final String charityId;
  final int targetType;
  final int complaintType;
  final String description;
  final int severity;
  final List<String> attachments;

  bool get isAgainstCharity => targetType == ComplaintTargetType.charity;

  Map<String, dynamic> toFields() => {
    'TargetType': targetType,
    // Sending an empty CharityId for a platform complaint would fail Guid
    // binding, so omit the key entirely unless a charity is actually named.
    if (isAgainstCharity && charityId.trim().isNotEmpty)
      'CharityId': charityId.trim(),
    'ComplaintType': complaintType,
    'Description': description.trim(),
    'Severity': severity,
  };
}

class Complaint {
  const Complaint({
    required this.id,
    required this.complaintNumber,
    this.charityId,
    this.charityName = '',
    this.targetType = ComplaintTargetType.charity,
    required this.complaintType,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.submittedById = '',
    this.resolvedById,
    this.resolvedAt,
    this.resolutionNotes = '',
    this.mediaUrls = const [],
  });
  final String id;
  final String complaintNumber;

  /// Null for a complaint filed against the platform itself.
  final String? charityId;
  final String charityName;
  final int targetType;
  final String submittedById;
  final int complaintType;
  final String description;
  final int severity;
  final int status;
  final DateTime createdAt;
  final String? resolvedById;
  final DateTime? resolvedAt;
  final String resolutionNotes;
  final List<String> mediaUrls;

  String get typeLabel => ApiEnums.complaintType[complaintType] ?? 'شكوى';
  String get severityLabel =>
      ApiEnums.complaintSeverity[severity] ?? 'غير محددة';
  String get statusLabel => ApiEnums.complaintStatus[status] ?? 'غير معروف';

  bool get isAgainstCharity => targetType == ComplaintTargetType.charity;

  /// Who the complaint names, for display: the charity when known, otherwise
  /// the platform (or a neutral label when the charity's name is missing).
  String get targetLabel {
    if (!isAgainstCharity) return ComplaintTargetType.labels[0]!;
    return charityName.isNotEmpty ? charityName : 'جمعية';
  }

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    id: JsonHelpers.text(json, const ['id']),
    complaintNumber: JsonHelpers.text(json, const [
      'complaintNumber',
    ], fallback: 'شكوى'),
    charityId: _nullable(json['charityId']),
    charityName: JsonHelpers.text(json, const ['charityName']),
    // Older payloads may omit targetType; a missing charity then implies a
    // platform complaint, which matches how the server now stores them.
    targetType:
        _int(json['targetType']) ??
        (_nullable(json['charityId']) == null
            ? ComplaintTargetType.admin
            : ComplaintTargetType.charity),
    submittedById: JsonHelpers.text(json, const ['submittedById']),
    complaintType: _int(json['complaintType']) ?? 0,
    description: JsonHelpers.text(json, const ['description']),
    severity: _int(json['severity']) ?? 0,
    status: _int(json['status']) ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    resolvedById: _nullable(json['resolvedById']),
    resolvedAt: DateTime.tryParse(json['resolvedAt']?.toString() ?? ''),
    resolutionNotes: JsonHelpers.text(json, const ['resolutionNotes']),
    mediaUrls: (json['medias'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              JsonHelpers.text(Map<String, dynamic>.from(item), const ['url']),
        )
        .where((url) => url.isNotEmpty)
        .toList(),
  );
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
const _emptyGuid = '00000000-0000-0000-0000-000000000000';

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return null;
  // An all-zero Guid means "unset" just as reliably as a null does, and the
  // API has shipped it in place of null before.
  return text == _emptyGuid ? null : text;
}
