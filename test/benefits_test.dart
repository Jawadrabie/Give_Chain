import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/features/benefits/data/benefit_models.dart';

void main() {
  group('BenefitType', () {
    test('parses the lookup response, including its charity', () {
      final type = BenefitType.fromJson({
        'id': 'bt-1',
        'name': 'مساعدة غذائية',
        'charityId': 'charity-1',
        'questions': [
          {
            'id': 'q2',
            'questionText': 'المدينة',
            'fieldType': 0,
            'order': 2,
            'isRequired': false,
            'options': <String>[],
          },
          {
            'id': 'q1',
            'questionText': 'كم عدد أفراد الأسرة؟',
            'fieldType': 1,
            'order': 1,
            'isRequired': true,
            'options': <String>[],
          },
        ],
      });

      expect(type.charityId, 'charity-1');
      // `order` decides the form's field sequence, so questions must come out
      // sorted no matter how the backend ordered the array.
      expect(type.questions.map((q) => q.id), ['q1', 'q2']);
      expect(type.questions.first.isRequired, isTrue);
      expect(type.questions.first.fieldType, 1);
    });

    test('treats an all-zero charity Guid as absent', () {
      final type = BenefitType.fromJson({
        'id': 'bt-2',
        'name': 'منفعة',
        'charityId': '00000000-0000-0000-0000-000000000000',
      });

      // An empty string means "unknown", which the charity filter must not
      // mistake for a real id that happens to match nothing.
      expect(type.charityId, isEmpty);
    });

    test('accepts a field type sent as its enum name', () {
      final type = BenefitType.fromJson({
        'id': 'bt-3',
        'name': 'منفعة',
        'questions': [
          {'id': 'q1', 'questionText': 'تاريخ الميلاد', 'fieldType': 'Date'},
          {'id': 'q2', 'questionText': 'الخيارات', 'fieldType': 'MultiOption'},
          {'id': 'q3', 'questionText': 'مجهول', 'fieldType': 'Nonsense'},
        ],
      });

      expect(type.questions[0].fieldType, 3);
      expect(type.questions[1].fieldType, 6);
      // An unknown name degrades to Text (0) rather than an unusable control.
      expect(type.questions[2].fieldType, 0);
    });

    test('reads options for single- and multi-select questions', () {
      final type = BenefitType.fromJson({
        'id': 'bt-4',
        'name': 'منفعة',
        'questions': [
          {
            'id': 'q1',
            'questionText': 'حجم الأسرة',
            'fieldType': 5,
            'options': ['أقل من 5 أفراد', '5 أفراد أو أكثر'],
          },
        ],
      });

      expect(type.questions.single.options, hasLength(2));
      expect(type.questions.single.options.first, 'أقل من 5 أفراد');
    });
  });

  group('BenefitRequest', () {
    Map<String, dynamic> requestJson({
      int status = 0,
      String? reviewedAt,
      String reviewNotes = '',
    }) => {
      'id': 'r1',
      'benefitTypeId': 'bt-1',
      'benefitTypeName': 'مساعدة غذائية',
      'requestNumber': 'REQ-100',
      'submittedAt': '2026-08-01T10:00:00Z',
      'status': status,
      'reviewNotes': reviewNotes,
      'reviewedAt': ?reviewedAt,
      'answers': [
        {'questionId': 'q1', 'questionText': 'العدد', 'answer': '4'},
      ],
    };

    test('maps each documented status to its Arabic label', () {
      expect(BenefitRequest.fromJson(requestJson()).statusLabel, 'قيد المراجعة');
      expect(
        BenefitRequest.fromJson(requestJson(status: 1)).statusLabel,
        'مقبول',
      );
      expect(
        BenefitRequest.fromJson(requestJson(status: 2)).statusLabel,
        'مرفوض',
      );
    });

    test('reports a pending request as unreviewed', () {
      // The UI keys the whole review block off this, so a pending request must
      // never read as reviewed even if the backend sent review fields anyway.
      final pending = BenefitRequest.fromJson(
        requestJson(reviewedAt: '2026-08-02T10:00:00Z', reviewNotes: 'ملاحظة'),
      );
      expect(pending.isReviewed, isFalse);

      final accepted = BenefitRequest.fromJson(
        requestJson(status: 1, reviewedAt: '2026-08-02T10:00:00Z'),
      );
      expect(accepted.isReviewed, isTrue);
      expect(accepted.reviewedAt, isNotNull);
    });

    test('leaves reviewedAt null when the backend omits it', () {
      expect(BenefitRequest.fromJson(requestJson()).reviewedAt, isNull);
    });

    test('copyWith backfills the charity without disturbing anything else', () {
      final original = BenefitRequest.fromJson(requestJson(status: 1));
      final tagged = original.copyWith(
        charityId: 'charity-1',
        charityName: 'جمعية البر',
      );

      expect(tagged.charityId, 'charity-1');
      expect(tagged.charityName, 'جمعية البر');
      expect(tagged.id, original.id);
      expect(tagged.status, original.status);
      expect(tagged.answers, original.answers);
      expect(tagged.requestNumber, original.requestNumber);
    });
  });

  group('BenefitOffering', () {
    BenefitType type(String id, String name, String charityName) =>
        BenefitType.fromJson({
          'id': id,
          'name': name,
          'charityId': 'c-$id',
          'charityName': charityName,
        });

    test('groups the same benefit offered by several charities', () {
      final groups = BenefitOffering.group([
        type('1', 'مساعدة غذائية', 'جمعية ب'),
        type('2', 'مساعدة طبية', 'جمعية أ'),
        type('3', 'مساعدة غذائية', 'جمعية أ'),
      ]);

      expect(groups, hasLength(2));
      final food = groups.firstWhere((g) => g.name == 'مساعدة غذائية');
      expect(food.types, hasLength(2));
      expect(food.isSingleCharity, isFalse);
      // Charities are listed alphabetically, not in arrival order.
      expect(food.types.map((t) => t.charityName), ['جمعية أ', 'جمعية ب']);
    });

    test('treats spacing and case differences as the same benefit', () {
      final groups = BenefitOffering.group([
        type('1', 'مساعدة  غذائية', 'جمعية أ'),
        type('2', 'مساعدة غذائية', 'جمعية ب'),
      ]);

      // Two spellings of one benefit must not split the picker into two rows.
      expect(groups, hasLength(1));
      expect(groups.single.types, hasLength(2));
      // The first spelling seen is the one shown.
      expect(groups.single.name, 'مساعدة  غذائية');
    });

    test('flags a benefit only one charity offers', () {
      final groups = BenefitOffering.group([
        type('1', 'مساعدة طبية', 'جمعية أ'),
      ]);

      // Drives skipping the charity step: there is nothing to choose.
      expect(groups.single.isSingleCharity, isTrue);
    });

    test('skips a type whose name is blank', () {
      // fromJson substitutes a fallback name, so a genuinely blank one can
      // only arrive from a directly constructed type.
      final groups = BenefitOffering.group([
        const BenefitType(id: '1', name: '   '),
        type('2', 'مساعدة طبية', 'جمعية أ'),
      ]);

      expect(groups.map((g) => g.name), ['مساعدة طبية']);
    });

    test('lists a charity once even with duplicate types', () {
      // Production has a charity holding three identical "مساعدة غذائية"
      // rows; the picker must not offer the same name three times.
      final groups = BenefitOffering.group([
        BenefitType.fromJson({
          'id': 'a',
          'name': 'مساعدة غذائية',
          'charityId': 'c1',
          'charityName': 'نور الخير',
        }),
        BenefitType.fromJson({
          'id': 'b',
          'name': 'مساعدة غذائية',
          'charityId': 'c1',
          'charityName': 'نور الخير',
        }),
      ]);

      expect(groups.single.types, hasLength(1));
      expect(groups.single.isSingleCharity, isTrue);
    });

    test('keeps the most detailed of a charity duplicate pair', () {
      final groups = BenefitOffering.group([
        BenefitType.fromJson({
          'id': 'sparse',
          'name': 'سلة',
          'charityId': 'c1',
          'questions': <Map<String, dynamic>>[],
        }),
        BenefitType.fromJson({
          'id': 'rich',
          'name': 'سلة',
          'charityId': 'c1',
          'questions': [
            {'id': 'q1', 'questionText': 'العدد', 'fieldType': 1},
          ],
        }),
      ]);

      // The row that actually asks something is the one worth applying to.
      expect(groups.single.types.single.id, 'rich');
    });

    test('keeps charities apart when neither carries a charity id', () {
      final groups = BenefitOffering.group([
        BenefitType.fromJson({
          'id': 'a',
          'name': 'سلة',
          'charityName': 'جمعية أ',
        }),
        BenefitType.fromJson({
          'id': 'b',
          'name': 'سلة',
          'charityName': 'جمعية ب',
        }),
      ]);

      // Falling back to a shared blank key would merge two real charities.
      expect(groups.single.types, hasLength(2));
    });

    test('takes the first non-empty description across charities', () {
      final groups = BenefitOffering.group([
        BenefitType.fromJson({'id': '1', 'name': 'سلة', 'description': ''}),
        BenefitType.fromJson({
          'id': '2',
          'name': 'سلة',
          'description': 'سلة شهرية',
        }),
      ]);

      expect(groups.single.description, 'سلة شهرية');
    });
  });

  group('BenefitAnswer', () {
    test('submits only questionId and answer', () {
      // questionText is display-only; sending it back would not match the
      // documented request body.
      const answer = BenefitAnswer(
        questionId: 'q1',
        answer: 'true',
        questionText: 'هل لديك دخل؟',
      );

      expect(answer.toJson(), {'questionId': 'q1', 'answer': 'true'});
    });
  });
}
