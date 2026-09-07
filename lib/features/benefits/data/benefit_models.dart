import '../../../core/constants/api_enums.dart';
import '../../../core/network/json_helpers.dart';

class BenefitQuestion {
  const BenefitQuestion({
    required this.id,
    required this.text,
    this.fieldType = 0,
    this.order = 0,
    this.isRequired = false,
    this.options = const [],
  });
  final String id;
  final String text;
  final int fieldType;
  final int order;
  final bool isRequired;
  final List<String> options;

  factory BenefitQuestion.fromJson(Map<String, dynamic> json) =>
      BenefitQuestion(
        id: JsonHelpers.text(json, const ['id', 'questionId']),
        text: JsonHelpers.text(json, const ['questionText', 'text', 'name']),
        fieldType: _fieldType(json['fieldType']),
        order: _int(json['order']) ?? 0,
        isRequired: JsonHelpers.boolean(json, const ['isRequired', 'required']),
        options: (json['options'] as List? ?? const [])
            .map(
              (value) => value is Map
                  ? JsonHelpers.text(Map<String, dynamic>.from(value), const [
                      'label',
                      'name',
                      'value',
                    ])
                  : value.toString(),
            )
            .where((value) => value.isNotEmpty)
            .toList(),
      );
}

class BenefitType {
  const BenefitType({
    required this.id,
    required this.name,
    this.charityId = '',
    this.charityName = '',
    this.description = '',
    this.isActive = true,
    this.questions = const [],
  });
  final String id;
  final String name;

  /// The charity offering this type. Always present on the lookup response, so
  /// picking a type implicitly picks its charity — which is why submitting a
  /// request needs nothing but [id].
  final String charityId;

  /// Only some backends label the charity inline; falls back to empty, in
  /// which case the UI simply omits the charity subtitle.
  final String charityName;
  final String description;
  final bool isActive;
  final List<BenefitQuestion> questions;

  /// Labels this type with the charity it came from.
  ///
  /// The per-charity endpoint does not name the charity, so the caller that
  /// already knows it supplies it here for the picker to display.
  BenefitType withCharity({required String id, required String name}) =>
      BenefitType(
        id: this.id,
        name: this.name,
        charityId: charityId.isEmpty ? id : charityId,
        charityName: name,
        description: description,
        isActive: isActive,
        questions: questions,
      );

  factory BenefitType.fromJson(Map<String, dynamic> json) => BenefitType(
    id: JsonHelpers.text(json, const ['id']),
    name: JsonHelpers.text(json, const ['name'], fallback: 'منفعة'),
    charityId: _guid(json['charityId']),
    charityName: JsonHelpers.text(json, const ['charityName']),
    description: JsonHelpers.text(json, const ['description']),
    isActive: JsonHelpers.boolean(json, const ['isActive'], fallback: true),
    questions: (json['questions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => BenefitQuestion.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order)),
  );
}

/// One benefit as the user thinks of it — "مساعدة غذائية" — together with
/// every charity that offers it.
///
/// Charities configure their own [BenefitType] rows, so the same benefit shows
/// up once per charity with a different id and its own questions. The
/// help-request flow asks the user *what* they need before *who* provides it,
/// so those rows are grouped by name here; picking a charity then selects the
/// concrete [BenefitType] whose questions get asked.
class BenefitOffering {
  const BenefitOffering({required this.name, required this.types});

  /// The shared display name, e.g. "مساعدة غذائية".
  final String name;

  /// Every charity's version of this benefit, in charity-name order.
  final List<BenefitType> types;

  /// True when only one charity offers it, so the charity step can be skipped.
  bool get isSingleCharity => types.length == 1;

  /// A description to show under the name; the first non-empty one wins, since
  /// charities describe the same benefit in their own words.
  String get description =>
      types.map((type) => type.description).firstWhere(
        (value) => value.isNotEmpty,
        orElse: () => '',
      );

  /// Groups [types] by name, preserving first-seen order.
  ///
  /// Names are matched on a trimmed, case- and whitespace-normalised form so
  /// "مساعدة  غذائية" and "مساعدة غذائية" do not split into two entries; the
  /// first spelling encountered is the one displayed.
  ///
  /// A charity can hold several rows for the same benefit — production has one
  /// charity with three identical "مساعدة غذائية" types — and listing it once
  /// per row would show the same name repeatedly with nothing to choose
  /// between. So each charity appears once per offering, represented by its
  /// most detailed row (see [_richest]).
  static List<BenefitOffering> group(List<BenefitType> types) {
    final buckets = <String, Map<String, BenefitType>>{};
    final labels = <String, String>{};

    for (final type in types) {
      final key = _normalize(type.name);
      if (key.isEmpty) continue;
      // Fall back to the type's own id so two charities that both lack a
      // charity id stay separate rather than collapsing into one.
      final charityKey = type.charityId.isNotEmpty
          ? type.charityId
          : _normalize(type.charityName).isNotEmpty
          ? _normalize(type.charityName)
          : type.id;

      final byCharity = buckets.putIfAbsent(key, () => {});
      byCharity[charityKey] = _richest(byCharity[charityKey], type);
      labels.putIfAbsent(key, () => type.name.trim());
    }

    return [
      for (final entry in buckets.entries)
        BenefitOffering(
          name: labels[entry.key]!,
          types: entry.value.values.toList()
            ..sort((a, b) => a.charityName.compareTo(b.charityName)),
        ),
    ];
  }

  /// Picks between duplicate rows of one benefit at one charity.
  ///
  /// Prefers the one that asks more questions, then the one with a
  /// description — the row carrying the most information is the most likely to
  /// be the maintained one. Ties keep the earlier row so the result is stable.
  static BenefitType _richest(BenefitType? current, BenefitType candidate) {
    if (current == null) return candidate;
    if (candidate.questions.length != current.questions.length) {
      return candidate.questions.length > current.questions.length
          ? candidate
          : current;
    }
    if (current.description.isEmpty && candidate.description.isNotEmpty) {
      return candidate;
    }
    return current;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class BenefitAnswer {
  const BenefitAnswer({
    required this.questionId,
    required this.answer,
    this.questionText = '',
  });
  final String questionId;
  final String answer;
  final String questionText;
  Map<String, dynamic> toJson() => {'questionId': questionId, 'answer': answer};
  factory BenefitAnswer.fromJson(Map<String, dynamic> json) => BenefitAnswer(
    questionId: JsonHelpers.text(json, const ['questionId']),
    questionText: JsonHelpers.text(json, const ['questionText']),
    answer: JsonHelpers.text(json, const ['answer']),
  );
}

class BenefitRequest {
  const BenefitRequest({
    required this.id,
    required this.benefitTypeId,
    required this.benefitTypeName,
    required this.requestNumber,
    required this.submittedAt,
    required this.status,
    this.charityId = '',
    this.charityName = '',
    this.personId = '',
    this.personName = '',
    this.reviewNotes = '',
    this.reviewedAt,
    this.answers = const [],
  });
  final String id;
  final String benefitTypeId;
  final String benefitTypeName;

  /// The charity the request was submitted to.
  ///
  /// The list endpoint does not reliably return this today, so it is often
  /// empty; [BenefitRepository.mine] backfills it from the benefit-type
  /// lookup when a charity-scoped list is requested. Never treat an empty
  /// value as "belongs to no charity".
  final String charityId;
  final String charityName;
  final String personId;
  final String personName;
  final String requestNumber;
  final DateTime submittedAt;
  final int status;
  final String reviewNotes;
  final DateTime? reviewedAt;
  final List<BenefitAnswer> answers;
  String get statusLabel => ApiEnums.benefitStatus[status] ?? 'غير معروف';

  /// `submittedAt` only when the server actually sent one.
  ///
  /// `GET /api/mobile/benefits` currently returns `0001-01-01T00:00:00`
  /// (`DateTime.MinValue`) for every request, so rendering it verbatim shows
  /// the donor a nonsense date. Screens use this and omit the line instead.
  DateTime? get submittedAtOrNull =>
      submittedAt.year <= 1 ? null : submittedAt;

  /// `reviewNotes`/`reviewedAt` only carry meaning once a reviewer has acted,
  /// so the UI hides the whole review block while the request is pending.
  bool get isReviewed => status != 0;

  BenefitRequest copyWith({
    String? charityId,
    String? charityName,
    String? benefitTypeId,
    String? benefitTypeName,
    DateTime? submittedAt,
    List<BenefitAnswer>? answers,
  }) => BenefitRequest(
    id: id,
    benefitTypeId: benefitTypeId ?? this.benefitTypeId,
    benefitTypeName: benefitTypeName ?? this.benefitTypeName,
    requestNumber: requestNumber,
    submittedAt: submittedAt ?? this.submittedAt,
    status: status,
    charityId: charityId ?? this.charityId,
    charityName: charityName ?? this.charityName,
    personId: personId,
    personName: personName,
    reviewNotes: reviewNotes,
    reviewedAt: reviewedAt,
    answers: answers ?? this.answers,
  );

  factory BenefitRequest.fromJson(Map<String, dynamic> json) => BenefitRequest(
    id: JsonHelpers.text(json, const ['id']),
    benefitTypeId: JsonHelpers.text(json, const ['benefitTypeId']),
    benefitTypeName: JsonHelpers.text(json, const ['benefitTypeName']),
    charityId: _guid(json['charityId']),
    charityName: JsonHelpers.text(json, const ['charityName']),
    personId: JsonHelpers.text(json, const ['personId']),
    personName: _personName(json['person']),
    requestNumber: JsonHelpers.text(json, const [
      'requestNumber',
    ], fallback: 'طلب'),
    submittedAt:
        DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
        DateTime.now(),
    status: _int(json['status']) ?? 0,
    reviewNotes: JsonHelpers.text(json, const ['reviewNotes']),
    reviewedAt: DateTime.tryParse(json['reviewedAt']?.toString() ?? ''),
    answers: (json['answers'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => BenefitAnswer.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
  );
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

/// Resolves a `QuestionFieldType` to its numeric value.
///
/// The contract sends the integer, but a serializer configured with a string
/// enum converter sends the member name instead; accepting both keeps a server
/// configuration change from silently degrading every question to a text box.
/// Anything unrecognised falls back to `0` (Text), which can capture any
/// answer rather than rendering an unusable control.
int _fieldType(dynamic value) {
  final numeric = _int(value);
  if (numeric != null) return numeric;
  return switch (value?.toString().trim().toLowerCase()) {
    'text' => 0,
    'numeric' || 'number' => 1,
    'boolean' || 'bool' => 2,
    'date' || 'datetime' => 3,
    'attachment' || 'file' => 4,
    'option' || 'select' => 5,
    'multioption' || 'multiselect' => 6,
    _ => 0,
  };
}

const _emptyGuid = '00000000-0000-0000-0000-000000000000';

/// An all-zero Guid means "unset" as surely as a null does; the benefit-types
/// endpoint shipped exactly that in place of the real charity id.
String _guid(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null' || text == _emptyGuid) return '';
  return text;
}


String _personName(dynamic value) {
  if (value is! Map) return '';
  final json = Map<String, dynamic>.from(value);
  final first = json['firstName']?.toString().trim() ?? '';
  final last = json['lastName']?.toString().trim() ?? '';
  final combined = [first, last].where((part) => part.isNotEmpty).join(' ');
  return combined.isNotEmpty
      ? combined
      : JsonHelpers.text(json, const ['name', 'fullName']);
}
