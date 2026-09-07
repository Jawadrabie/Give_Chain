import 'package:flutter_test/flutter_test.dart';

import 'package:give_chain_app/core/config/api_paths.dart';
import 'package:give_chain_app/core/network/json_helpers.dart';
import 'package:give_chain_app/features/auth/data/auth_models.dart';
import 'package:give_chain_app/features/benefits/data/benefit_models.dart';
import 'package:give_chain_app/features/complaints/data/complaint_models.dart';
import 'package:give_chain_app/features/donations/data/donation_models.dart';
import 'package:give_chain_app/features/notifications/data/notification_models.dart';
import 'package:give_chain_app/features/profile/data/profile_repository.dart';

void main() {
  group('official backend routes', () {
    test('write routes match the mobile guide', () {
      expect(ApiPaths.signup, '/api/mobile/auth/register');
      expect(
        ApiPaths.campaignDonation('abc'),
        '/api/mobile/campaigns/abc/donate',
      );
      expect(ApiPaths.caseDonation('abc'), '/api/mobile/cases/abc/donate');
      // Bank transfers are progressed by uploading a receipt; the backend has
      // no confirm-payment endpoint (confirmed 2026-08-23, BACKEND_ANSWERS.md #6).
      expect(ApiPaths.donationProof('abc'), '/api/mobile/donations/abc/proof');
      expect(ApiPaths.profilePassword, '/api/mobile/profile/password');
      expect(
        ApiPaths.notificationReadAll,
        '/api/mobile/notifications/read-all',
      );
    });
  });

  group('registration contract', () {
    test('uses exact multipart field names', () {
      final fields = SignUpRequest(
        firstName: 'Sara',
        lastName: 'Ali',
        userName: 'sara',
        email: 'sara@example.com',
        password: 'valid-pass-9',
        gender: 1,
        birthOfDate: DateTime.utc(2000, 1, 2),
        nationalNumber: 'N-1',
        countryId: 'country-id',
        cityId: 'city-id',
      ).toMultipartFields();

      expect(fields['FirstName'], 'Sara');
      expect(fields['LastName'], 'Ali');
      expect(fields['Username'], 'sara');
      expect(fields['Email'], 'sara@example.com');
      expect(fields['Password'], 'valid-pass-9');
      expect(fields['Gender'], 1);
      expect(fields['CountryId'], 'country-id');
      expect(fields['CityId'], 'city-id');
      expect(fields, isNot(contains('RoleId')));
    });

    test('reset password sends both token and code spellings', () {
      // API_MOBILE.md documents `Token`; the older guide documents `code` and
      // flags the pair as unresolved. Both are sent so the flow works either
      // way — see BACKEND_QUESTIONS_R2.md #9.
      expect(
        const ResetPasswordRequest(
          email: 'a@example.com',
          code: '123456',
          newPassword: 'new-password',
        ).toJson(),
        {
          'email': 'a@example.com',
          'token': '123456',
          'code': '123456',
          'newPassword': 'new-password',
        },
      );
    });
  });

  group('donation multipart contract', () {
    test('campaign endpoint body omits target fields', () {
      final fields = const DonationRequest(
        targetId: 'campaign-id',
        targetType: 1,
        donationType: 1,
        amount: 500,
        paymentMethod: 3,
        message: 'شكراً',
      ).toMultipartFields();

      expect(fields['donationType'], 1);
      expect(fields['amount'], 500);
      expect(fields['paymentMethod'], 3);
      expect(fields, isNot(contains('targetType')));
      expect(fields, isNot(contains('campaignId')));
    });

    test('general donation includes target identifiers', () {
      final fields = const DonationRequest(
        targetId: 'case-id',
        targetType: 2,
        donationType: 2,
        caseNeedId: 'need-id',
        itemName: 'بطانية',
        quantity: 2,
        unit: 3,
        deliveryMethod: 1,
      ).toMultipartFields(includeTarget: true);

      expect(fields['targetType'], 2);
      expect(fields['caseId'], 'case-id');
      expect(fields['caseNeedId'], 'need-id');
      expect(fields['itemName'], 'بطانية');
      expect(fields['quantity'], 2);
      expect(fields['unit'], 3);
      expect(fields['deliveryMethod'], 1);
    });
  });

  test('complaint against a charity uses exact multipart names', () {
    expect(
      const ComplaintRequest(
        charityId: 'charity-id',
        complaintType: 1,
        description: 'وصف مالي واضح',
        severity: 2,
      ).toFields(),
      {
        'TargetType': ComplaintTargetType.charity,
        'CharityId': 'charity-id',
        'ComplaintType': 1,
        'Description': 'وصف مالي واضح',
        'Severity': 2,
      },
    );
  });

  test('complaint against the platform omits the charity id', () {
    // CharityId is required only for a charity complaint; sending an empty
    // string would fail Guid binding server-side.
    expect(
      const ComplaintRequest(
        targetType: ComplaintTargetType.admin,
        complaintType: 0,
        description: 'وصف واضح للشكوى',
        severity: 1,
      ).toFields(),
      {
        'TargetType': ComplaintTargetType.admin,
        'ComplaintType': 0,
        'Description': 'وصف واضح للشكوى',
        'Severity': 1,
      },
    );
  });

  test('profile update supports clearing optional location', () {
    final json = const UpdateProfileRequest(
      firstName: 'Sara',
      countryId: '',
      cityId: '',
    ).toJson();
    expect(json['firstName'], 'Sara');
    expect(json.containsKey('countryId'), isTrue);
    expect(json['countryId'], isNull);
    expect(json.containsKey('cityId'), isTrue);
    expect(json['cityId'], isNull);
  });

  test('benefit and notification response models map official fields', () {
    final benefit = BenefitRequest.fromJson({
      'id': 'b1',
      'benefitTypeId': 't1',
      'benefitTypeName': 'سلة غذائية',
      'requestNumber': 'REQ-1',
      'submittedAt': '2026-07-01T00:00:00Z',
      'status': 1,
      'answers': [
        {'questionId': 'q1', 'questionText': 'عدد الأفراد', 'answer': '5'},
      ],
    });
    expect(benefit.statusLabel, 'مقبول');
    expect(benefit.answers.single.answer, '5');

    final notification = AppNotification.fromJson({
      'id': 'n1',
      'title': 'تحديث',
      'body': 'تم توثيق التبرع',
      'type': 0,
      'isRead': false,
      'referenceId': 'd1',
      'createdAt': '2026-07-01T00:00:00Z',
    });
    expect(notification.isRead, isFalse);
    expect(notification.referenceId, 'd1');
  });

  test('paged envelope reads items and totalPages', () {
    final raw = {
      'isSuccess': true,
      'data': {
        'items': [
          {'id': '1'},
          {'id': '2'},
        ],
        'totalCount': 3,
        'page': 1,
        'pageSize': 2,
        'totalPages': 2,
      },
    };
    expect(JsonHelpers.objectList(raw), hasLength(2));
    expect(
      JsonHelpers.hasMorePage(raw, page: 1, pageSize: 2, receivedCount: 2),
      isTrue,
    );
  });
}
