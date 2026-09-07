import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/core/network/json_helpers.dart';
import 'package:give_chain_app/features/auth/data/auth_models.dart';
import 'package:give_chain_app/features/catalog/data/catalog_models.dart';
import 'package:give_chain_app/features/donations/data/donation_models.dart';

void main() {
  test('CatalogItem parses the documented CampaignResponse', () {
    final item = CatalogItem.fromJson({
      'id': 'campaign-2',
      'campaignName': 'حملة موثقة',
      'campaignDescription': 'وصف الحملة',
      'targetAmount': 1200,
      'achievedAmount': 300,
      'targetQuantity': 50,
      'achievedQuantity': 10,
      'goalUnit': 'طرد',
      'isTrusted': true,
      'status': 1,
      'startDate': '2026-01-01T00:00:00Z',
      'endDate': '2026-12-31T00:00:00Z',
      'campaignType': {'id': 't1', 'name': 'إغاثة'},
      'medias': [
        {'url': '/media/main.jpg', 'isPrimary': true},
        {'url': '/media/second.jpg'},
      ],
    });

    expect(item.title, 'حملة موثقة');
    expect(item.progress, .25);
    expect(item.quantityProgress, .2);
    expect(item.isTrusted, isTrue);
    expect(item.displayStatus, 'نشطة');
    expect(item.mediaUrls, hasLength(2));
    expect(item.imageUrl, '/media/main.jpg');
  });

  test('CatalogItem parses the documented CaseResponse', () {
    final item = CatalogItem.fromJson({
      'id': 'case-1',
      'title': 'حالة عاجلة',
      'description': 'وصف الحالة',
      'priority': 3,
      'status': 0,
      'publishedAt': '2026-07-01T00:00:00Z',
      'category': {'id': 'cat-1', 'name': 'طبي'},
      'locationDetails': 'دمشق',
    });

    expect(item.isCase, isTrue);
    expect(item.priorityLabel, 'عاجلة');
    expect(item.displayStatus, 'مفتوحة');
    expect(item.typeName, 'طبي');
    expect(item.canDonate, isTrue);
  });

  test('Charity parses documented categories and location', () {
    final charity = Charity.fromJson({
      'id': 'charity-1',
      'name': 'جمعية الخير',
      'country': 'Syria',
      'city': 'Damascus',
      'categories': [
        {'id': 'cat-1', 'name': 'إغاثة'},
      ],
    });

    expect(charity.id, 'charity-1');
    expect(charity.name, 'جمعية الخير');
    expect(charity.categoryNames, contains('إغاثة'));
  });

  test('SignUpRequest emits exact multipart register field names', () {
    final fields = SignUpRequest(
      firstName: 'Ali',
      lastName: 'Ahmad',
      userName: 'ali',
      email: 'ali@example.com',
      password: 'test-password',
      birthOfDate: DateTime.utc(2000, 1, 2),
      nationalNumber: 'N1',
      gender: 1,
      countryId: 'country-id',
      cityId: 'city-id',
    ).toMultipartFields();

    expect(fields['FirstName'], 'Ali');
    expect(fields['Username'], 'ali');
    expect(fields['CountryId'], 'country-id');
    expect(fields['CityId'], 'city-id');
    expect(fields['Gender'], 1);
    expect(fields.containsKey('RoleId'), isFalse);
  });

  test('DonationRequest emits exact target-specific multipart fields', () {
    const request = DonationRequest(
      targetId: 'case-9',
      targetType: 2,
      donationType: 2,
      itemName: 'مواد غذائية',
      quantity: 3,
      unit: 4,
      deliveryMethod: 1,
    );

    final targetSpecific = request.toMultipartFields();
    final generic = request.toMultipartFields(includeTarget: true);
    expect(targetSpecific.containsKey('caseId'), isFalse);
    expect(targetSpecific['donationType'], 2);
    expect(targetSpecific['itemName'], 'مواد غذائية');
    expect(generic['targetType'], 2);
    expect(generic['caseId'], 'case-9');
  });

  test('ResetPasswordRequest sends both token and code spellings', () {
    const request = ResetPasswordRequest(
      email: 'user@example.com',
      code: '123456',
      newPassword: 'new-password',
    );

    // API_MOBILE.md documents `Token`; the older guide documents `code` and
    // lists the pair as unresolved, so both go out until backend confirms
    // (BACKEND_QUESTIONS_R2.md #9).
    expect(request.toJson(), {
      'email': 'user@example.com',
      'token': '123456',
      'code': '123456',
      'newPassword': 'new-password',
    });
  });

  test('JsonHelpers reads PagedResult items inside the API envelope', () {
    final items = JsonHelpers.objectList({
      'data': {
        'items': [
          {'id': 'c1'},
        ],
        'totalCount': 1,
        'page': 1,
        'pageSize': 10,
        'totalPages': 1,
      },
      'isSuccess': true,
    });

    expect(items, hasLength(1));
    expect(items.first['id'], 'c1');
  });
}
