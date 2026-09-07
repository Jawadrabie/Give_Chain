import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/features/auth/data/auth_models.dart';
import 'package:give_chain_app/features/benefits/data/benefit_models.dart';
import 'package:give_chain_app/features/catalog/data/catalog_models.dart';
import 'package:give_chain_app/features/complaints/data/complaint_models.dart';
import 'package:give_chain_app/features/profile/data/profile_repository.dart';

/// Covers the backend contract changes dated 2026-08-30
/// (`BACKEND_CHANGES_FOR_MOBILE.md` and `MOBILE_API_CHANGES.md`).
void main() {
  group('case detail exposes needs and updates', () {
    // Shape taken verbatim from BACKEND_CHANGES_FOR_MOBILE.md section 3.
    Map<String, dynamic> caseJson() => {
      'id': 'case-1',
      'charityId': 'charity-1',
      'title': 'حالة إنسانية',
      'status': 0,
      'priority': 1,
      'publishedAt': '2026-08-28T18:44:45.8230783',
      // Shapes mirror live production needs: a money need carries `amount`
      // only, an in-kind one carries `quantity`/`unit`. Note caseNeedType 2
      // appears on money needs upstream — deliberately not DonationType.
      'caseNeeds': [
        {
          'id': 'need-1',
          'caseId': 'case-1',
          'name': 'رسوم دراسية',
          'caseNeedType': 2,
          'quantity': null,
          'unit': null,
          'amount': 500.0,
          'description': 'دواء ADHD',
          'fulfilledQuantity': null,
          'fulfilledAmount': 150.0,
        },
        {
          'id': 'need-2',
          'caseId': 'case-1',
          'name': 'بطانيات',
          'caseNeedType': 1,
          'quantity': 10,
          'unit': 3,
          'amount': null,
          'fulfilledQuantity': 10,
          'fulfilledAmount': null,
        },
      ],
      'caseUpdates': [
        {
          'id': 'update-1',
          'caseId': 'case-1',
          'postedById': 'user-1',
          'content': 'تم شراء الدواء',
          'postedAt': '2026-08-20T10:00:00Z',
          'medias': [
            {'url': '/media/update-1.jpg'},
          ],
        },
        {
          'id': 'update-2',
          'caseId': 'case-1',
          'postedById': 'user-1',
          'content': 'تحديث أحدث',
          'postedAt': '2026-08-29T10:00:00Z',
          'medias': <Map<String, dynamic>>[],
        },
      ],
    };

    test('parses caseNeeds with the documented field names', () {
      final item = CatalogItem.fromJson(caseJson());

      expect(item.caseNeeds, hasLength(2));
      final money = item.caseNeeds.first;
      expect(money.id, 'need-1');
      expect(money.name, 'رسوم دراسية');
      expect(money.caseNeedType, 2);
      expect(money.amount, 500.0);
      expect(money.fulfilledAmount, 150.0);
      expect(money.description, 'دواء ADHD');
      // Progress follows the measure the need is expressed in.
      expect(money.progress, closeTo(0.3, 1e-9));
      expect(money.isFulfilled, isFalse);
    });

    test('an item need measures progress by quantity, not amount', () {
      final need = CatalogItem.fromJson(caseJson()).caseNeeds[1];

      expect(need.caseNeedType, 1);
      expect(need.unitLabel, 'قطعة');
      expect(need.progress, 1.0);
      expect(need.isFulfilled, isTrue);
    });

    test('the type label comes from the need shape, not caseNeedType', () {
      // CaseNeedType is 0-3 while DonationType is 1-3: they are different
      // enums whose member names the backend has not published, so the raw
      // value must never be shown or copied into a donation's type.
      // Live data confirms it: caseNeedType 2 appears on money needs
      // (amount only) while DonationType 2 means an in-kind donation.
      final needs = CatalogItem.fromJson(caseJson()).caseNeeds;

      expect(needs[0].typeLabel, 'مالي'); // amount 500, caseNeedType 2
      expect(needs[1].typeLabel, 'عيني'); // quantity 10, caseNeedType 1
    });

    test('a service need with neither amount nor quantity stays unlabelled', () {
      // Taken from live case 45438dae: caseNeedType 3, everything else null.
      final item = CatalogItem.fromJson({
        'id': 'case-5',
        'priority': 0,
        'caseNeeds': [
          {
            'id': 'need-svc',
            'name': 'صيانة كرسي متحرك',
            'caseNeedType': 3,
            'quantity': null,
            'unit': null,
            'amount': null,
          },
        ],
      });

      final need = item.caseNeeds.single;
      expect(need.typeLabel, isEmpty);
      expect(need.progress, isNull);
      expect(need.isFulfilled, isFalse);
    });

    test('accepts the `needs` spelling proposed in the bug report', () {
      final item = CatalogItem.fromJson({
        'id': 'case-2',
        'priority': 0,
        'needs': [
          {'id': 'need-9', 'title': 'مأوى', 'type': 3, 'targetQuantity': 4},
        ],
      });

      expect(item.caseNeeds, hasLength(1));
      expect(item.caseNeeds.single.name, 'مأوى');
      expect(item.caseNeeds.single.caseNeedType, 3);
      expect(item.caseNeeds.single.quantity, 4);
    });

    test('drops needs with no id, which cannot be donated to', () {
      final item = CatalogItem.fromJson({
        'id': 'case-3',
        'priority': 0,
        'caseNeeds': [
          {'name': 'بلا معرف'},
          {'id': 'need-ok', 'name': 'صالح'},
        ],
      });

      expect(item.caseNeeds.map((need) => need.id), ['need-ok']);
    });

    test('orders updates newest first and reads their media', () {
      final item = CatalogItem.fromJson(caseJson());

      expect(item.caseUpdates.map((update) => update.id), [
        'update-2',
        'update-1',
      ]);
      expect(item.caseUpdates.last.mediaUrls, ['/media/update-1.jpg']);
      expect(item.caseUpdates.first.content, 'تحديث أحدث');
    });

    test('list payloads without the fields yield empty lists', () {
      final item = CatalogItem.fromJson({'id': 'case-4', 'priority': 0});

      expect(item.caseNeeds, isEmpty);
      expect(item.caseUpdates, isEmpty);
    });
  });

  group('complaint target type', () {
    test('a platform complaint parses with a null charity', () {
      final complaint = Complaint.fromJson({
        'id': 'complaint-1',
        'complaintNumber': 'C-1',
        'targetType': 0,
        'charityId': null,
        'complaintType': 0,
        'description': 'شكوى على المنصة',
        'severity': 1,
        'status': 0,
        'createdAt': '2026-08-30T10:00:00Z',
      });

      expect(complaint.charityId, isNull);
      expect(complaint.isAgainstCharity, isFalse);
      expect(complaint.targetLabel, 'منصة GiveChain');
    });

    test('an empty Guid charity id is treated as absent', () {
      final complaint = Complaint.fromJson({
        'id': 'complaint-2',
        'complaintNumber': 'C-2',
        'charityId': '00000000-0000-0000-0000-000000000000',
        'complaintType': 0,
        'description': 'شكوى',
        'severity': 0,
        'status': 0,
        'createdAt': '2026-08-30T10:00:00Z',
      });

      expect(complaint.charityId, isNull);
      // With no charity and no explicit targetType, it must read as a
      // platform complaint rather than a charity one with a broken id.
      expect(complaint.targetType, ComplaintTargetType.admin);
    });

    test('a charity complaint keeps its charity and name', () {
      final complaint = Complaint.fromJson({
        'id': 'complaint-3',
        'complaintNumber': 'C-3',
        'targetType': 1,
        'charityId': 'charity-1',
        'charityName': 'جمعية الرحمة',
        'complaintType': 2,
        'description': 'شكوى على جمعية',
        'severity': 3,
        'status': 1,
        'createdAt': '2026-08-30T10:00:00Z',
      });

      expect(complaint.charityId, 'charity-1');
      expect(complaint.isAgainstCharity, isTrue);
      expect(complaint.targetLabel, 'جمعية الرحمة');
    });
  });

  group('benefit type charity id and field types', () {
    test('an empty Guid charityId is normalised away', () {
      final type = BenefitType.fromJson({
        'id': 'type-1',
        'charityId': '00000000-0000-0000-0000-000000000000',
        'name': 'مساعدة إيوائية',
        'questions': <Map<String, dynamic>>[],
      });

      expect(type.charityId, isEmpty);
    });

    test('a real charityId is kept', () {
      final type = BenefitType.fromJson({
        'id': 'type-2',
        'charityId': 'charity-7',
        'name': 'مساعدة',
        'questions': <Map<String, dynamic>>[],
      });

      expect(type.charityId, 'charity-7');
    });

    test('questions parse a string fieldType as well as an ordinal', () {
      // The live Mobile swagger types FieldType as an integer enum (0-6) and
      // production sends integers, so the ordinal is the real contract; the
      // "Numeric" spelling in MOBILE_API_CHANGES.md was illustrative only.
      // Both are accepted so a string enum converter being switched on
      // server-side cannot silently degrade every question to a text box.
      final type = BenefitType.fromJson({
        'id': 'type-3',
        'charityId': 'charity-7',
        'name': 'مساعدة',
        'questions': [
          {
            'id': 'q1',
            'questionText': 'عدد أفراد الأسرة',
            'fieldType': 'Numeric',
            'order': 1,
            'isRequired': true,
            'options': <String>[],
          },
          {
            'id': 'q2',
            'questionText': 'نوع السكن',
            'fieldType': 'MultiOption',
            'order': 2,
            'isRequired': false,
            'options': ['شقة', 'غرفة'],
          },
          {
            'id': 'q3',
            'questionText': 'تاريخ الميلاد',
            'fieldType': 3,
            'order': 3,
            'isRequired': false,
            'options': <String>[],
          },
        ],
      });

      expect(type.questions.map((q) => q.fieldType), [1, 6, 3]);
      expect(type.questions[1].options, ['شقة', 'غرفة']);
    });

    test('questions come back ordered by `order`', () {
      final type = BenefitType.fromJson({
        'id': 'type-4',
        'name': 'مساعدة',
        'questions': [
          {'id': 'b', 'questionText': 'ثانٍ', 'order': 2},
          {'id': 'a', 'questionText': 'أول', 'order': 1},
        ],
      });

      expect(type.questions.map((q) => q.id), ['a', 'b']);
    });
  });

  group('phone number on person', () {
    test('sign-up omits a blank phone number', () {
      final fields = const SignUpRequest(
        firstName: 'أحمد',
        lastName: 'محمد',
        userName: 'ahmad',
        email: 'ahmad@example.com',
        password: 'Passw0rd!',
        gender: 0,
      ).toMultipartFields();

      expect(fields.containsKey('PhoneNumber'), isFalse);
    });

    test('sign-up sends a supplied phone number', () {
      final fields = const SignUpRequest(
        firstName: 'أحمد',
        lastName: 'محمد',
        userName: 'ahmad',
        email: 'ahmad@example.com',
        password: 'Passw0rd!',
        gender: 0,
        phoneNumber: ' 0791234567 ',
      ).toMultipartFields();

      expect(fields['PhoneNumber'], '0791234567');
    });

    test('AuthResponse reads the new phoneNumber field', () {
      final response = AuthResponse.fromJson({
        'message': 'ok',
        'data': {
          'userId': 'user-1',
          'token': 'jwt',
          'email': 'ahmad@example.com',
          'phoneNumber': '0791234567',
        },
      });

      expect(response.phoneNumber, '0791234567');
    });

    test('AuthResponse tolerates a legacy payload with no phone', () {
      final response = AuthResponse.fromJson({
        'message': 'ok',
        'data': {'userId': 'user-1', 'token': 'jwt'},
      });

      expect(response.phoneNumber, isEmpty);
    });

    test('UserProfile reads phoneNumber from the person payload', () {
      final profile = UserProfile.fromJson({
        'id': 'person-1',
        'firstName': 'أحمد',
        'lastName': 'محمد',
        'phoneNumber': '0791234567',
        'gender': 0,
        'user': {'email': 'ahmad@example.com', 'userName': 'ahmad'},
      });

      expect(profile.phoneNumber, '0791234567');
    });

    test('profile update sends null to clear a saved phone number', () {
      final json = const UpdateProfileRequest(phoneNumber: '').toJson();

      expect(json.containsKey('phoneNumber'), isTrue);
      expect(json['phoneNumber'], isNull);
    });

    test('profile update omits the phone when it is not being edited', () {
      final json = const UpdateProfileRequest(firstName: 'Sara').toJson();

      expect(json.containsKey('phoneNumber'), isFalse);
    });
  });

  group('benefit request list gaps', () {
    // Verbatim from a live GET /api/mobile/benefits response: the server
    // drops every field except the id, requestNumber and status.
    Map<String, dynamic> liveBenefitJson() => {
      'id': '3ae77cbe-01a4-48e7-a584-2ee22df13cd6',
      'benefitTypeId': '00000000-0000-0000-0000-000000000000',
      'benefitTypeName': '',
      'personId': '00000000-0000-0000-0000-000000000000',
      'person': null,
      'requestNumber': '9d8ea6747d',
      'submittedAt': '0001-01-01T00:00:00',
      'status': 0,
      'reviewNotes': null,
      'reviewedAt': null,
      'answers': <Map<String, dynamic>>[],
    };

    test('DateTime.MinValue is reported as no date at all', () {
      // Rendering 0001-01-01 verbatim shows the user a nonsense date, so the
      // screens hide the row instead.
      final request = BenefitRequest.fromJson(liveBenefitJson());

      expect(request.submittedAtOrNull, isNull);
    });

    test('a real submission date survives', () {
      final request = BenefitRequest.fromJson({
        ...liveBenefitJson(),
        'submittedAt': '2026-08-30T10:00:00Z',
      });

      expect(request.submittedAtOrNull, isNotNull);
      expect(request.submittedAtOrNull!.year, 2026);
    });

    test('copyWith backfills only the fields the server left empty', () {
      final request = BenefitRequest.fromJson(liveBenefitJson());

      final merged = request.copyWith(
        benefitTypeName: 'مساعدة إيوائية',
        submittedAt: DateTime.utc(2026, 8, 30),
        answers: const [BenefitAnswer(questionId: 'q1', answer: '7')],
      );

      expect(merged.benefitTypeName, 'مساعدة إيوائية');
      expect(merged.submittedAtOrNull, isNotNull);
      expect(merged.answers.single.answer, '7');
      // Fields the server did send must be preserved untouched.
      expect(merged.id, request.id);
      expect(merged.requestNumber, '9d8ea6747d');
      expect(merged.status, 0);
    });
  });
}
