import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/token_storage.dart';

/// Remembers what the user actually submitted with each benefit request.
///
/// `GET /api/mobile/benefits` currently returns `benefitTypeId` and
/// `personId` as `Guid.Empty`, an empty `benefitTypeName`, an empty `answers`
/// list and `submittedAt = 0001-01-01`, so the server copy alone renders as a
/// blank card. The request id *is* returned correctly, so the submission is
/// cached here under that id and merged back in by
/// [BenefitRepository.mine].
///
/// This is a display-only fallback: anything the server does send always
/// wins, so the cache becomes dead weight the moment the backend is fixed.
class BenefitRequestStore {
  BenefitRequestStore(this._preferences);

  static const _baseKey = 'givechain_benefit_requests_v1';
  static const maxRecords = 100;

  final SharedPreferences _preferences;

  static Future<BenefitRequestStore> create() async =>
      BenefitRequestStore(await SharedPreferences.getInstance());

  /// Cached submissions, keyed by the server's request id.
  Map<String, BenefitSubmissionRecord> readAll() {
    final raw = _preferences.getString(_currentKey);
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      final records = decoded
          .whereType<Map>()
          .map(
            (item) => BenefitSubmissionRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.requestId.isNotEmpty);
      return {for (final item in records) item.requestId: item};
    } catch (_) {
      return const {};
    }
  }

  Future<void> add(BenefitSubmissionRecord record) async {
    if (record.requestId.isEmpty) return;
    final merged = <String, BenefitSubmissionRecord>{
      record.requestId: record,
      ...readAll(),
    };
    final ordered = merged.values.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    await _preferences.setString(
      _currentKey,
      jsonEncode(
        ordered.take(maxRecords).map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> clear() => _preferences.remove(_currentKey);

  String get _currentKey {
    final userId = TokenStorage.tokenInfo?.userId?.trim();
    return userId == null || userId.isEmpty
        ? '$_baseKey:guest'
        : '$_baseKey:$userId';
  }
}

/// The parts of a submission the server does not echo back.
class BenefitSubmissionRecord {
  const BenefitSubmissionRecord({
    required this.requestId,
    required this.benefitTypeId,
    required this.benefitTypeName,
    required this.submittedAt,
    this.charityId = '',
    this.charityName = '',
    this.answers = const {},
  });

  final String requestId;
  final String benefitTypeId;
  final String benefitTypeName;
  final String charityId;
  final String charityName;
  final DateTime submittedAt;

  /// Answer text keyed by question id.
  final Map<String, String> answers;

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'benefitTypeId': benefitTypeId,
    'benefitTypeName': benefitTypeName,
    'charityId': charityId,
    'charityName': charityName,
    'submittedAt': submittedAt.toIso8601String(),
    'answers': answers,
  };

  factory BenefitSubmissionRecord.fromJson(Map<String, dynamic> json) =>
      BenefitSubmissionRecord(
        requestId: json['requestId']?.toString() ?? '',
        benefitTypeId: json['benefitTypeId']?.toString() ?? '',
        benefitTypeName: json['benefitTypeName']?.toString() ?? '',
        charityId: json['charityId']?.toString() ?? '',
        charityName: json['charityName']?.toString() ?? '',
        submittedAt:
            DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
            DateTime.now(),
        answers: (json['answers'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        ),
      );
}
