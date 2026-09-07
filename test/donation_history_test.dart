import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/features/donations/data/donation_history_store.dart';
import 'package:give_chain_app/features/donations/data/donation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DonationRequest serializes an item donation', () {
    final fields = const DonationRequest(
      targetId: 'case-1',
      targetType: 2,
      donationType: 2,
      itemName: 'مواد غذائية',
      itemDescription: 'مواد معلبة',
      quantity: 3,
      unit: 4,
      deliveryMethod: 1,
    ).toMultipartFields(includeTarget: true);

    expect(fields['caseId'], 'case-1');
    expect(fields.containsKey('campaignId'), isFalse);
    expect(fields['itemName'], 'مواد غذائية');
    expect(fields['quantity'], 3);
  });

  test('DonationHistoryStore persists and clears records', () async {
    final store = await DonationHistoryStore.create();
    const request = DonationRequest(
      targetId: 'campaign-1',
      targetType: 1,
      donationType: 1,
      amount: 50,
      paymentMethod: 3,
      clientReference: 'client-1',
    );
    final record = DonationRecord.fromSubmission(
      request: request,
      response: DonationResponse(
        id: 'donation-1',
        donationType: 1,
        targetType: 1,
        status: 0,
        donationDate: DateTime.utc(2026, 7, 18),
      ),
      targetTitle: 'حملة اختبار',
    );

    await store.add(record);
    final records = store.readAll();
    expect(records, hasLength(1));
    expect(records.first.remoteId, 'donation-1');
    expect(records.first.targetTitle, 'حملة اختبار');

    await store.clear();
    expect(store.readAll(), isEmpty);
  });

  test('DonationResponse parses documented payment fields', () {
    final response = DonationResponse.fromJson({
      'data': {
        'id': 'donation-2',
        'donationType': 1,
        'targetType': 1,
        'campaignId': 'campaign-1',
        'campaignName': 'حملة',
        'donationDate': '2026-07-18T08:00:00Z',
        'status': 1,
        'amount': 75,
        'paymentMethod': 3,
        'paymentStatus': 1,
        'paymentUrl': 'https://checkout.example.test',
      },
      'isSuccess': true,
    });

    expect(response.id, 'donation-2');
    // Donor-facing wording for Pledged(1) per the backend guide's label table,
    // not the raw enum name.
    expect(response.statusLabel, 'قيد المراجعة');
    expect(response.paymentUrl, isNotNull);
  });

  test('DonationResponse reads isTrusted from the nested campaign object', () {
    final trusted = DonationResponse.fromJson({
      'data': {
        'id': 'donation-trusted',
        'donationType': 1,
        'targetType': 1,
        'donationDate': '2026-09-06T08:00:00Z',
        'status': 1,
        'campaign': {
          'id': 'campaign-1',
          'campaignName': 'حملة موثوقة',
          'status': 0,
          'startDate': '2026-01-01T00:00:00Z',
          'isTrusted': true,
        },
      },
      'isSuccess': true,
    });
    expect(trusted.isTrusted, isTrue);
    expect(trusted.campaignName, 'حملة موثوقة');

    // A case/charity donation carries no nested campaign object at all.
    final untrusted = DonationResponse.fromJson({
      'data': {
        'id': 'donation-case',
        'donationType': 1,
        'targetType': 2,
        'donationDate': '2026-09-06T08:00:00Z',
        'status': 1,
      },
      'isSuccess': true,
    });
    expect(untrusted.isTrusted, isFalse);
  });

  test('DonationResponse keeps the donor-entered item description', () {
    final response = DonationResponse.fromJson({
      'data': {
        'id': 'donation-3',
        'donationType': 2,
        'targetType': 2,
        'entityId': 'need-9',
        'entityName': 'سلال غذائية',
        'donationDate': '2026-08-23T08:00:00Z',
        'status': 1,
        'itemName': 'بطانيات',
        'itemDescription': 'بطانيات شتوية جديدة، مقاس كبير',
        'quantity': 5,
      },
      'isSuccess': true,
    });

    expect(response.itemDescription, 'بطانيات شتوية جديدة، مقاس كبير');

    // The local record must keep the description rather than substituting the
    // item name, and must resolve its target from the documented entityId.
    final record = DonationRecord.fromServer({
      'id': response.id,
      'donationType': response.donationType,
      'targetType': response.targetType,
      'entityId': response.entityId,
      'entityName': response.entityName,
      'itemName': response.itemName,
      'itemDescription': response.itemDescription,
      'status': response.status,
      'donationDate': response.donationDate.toIso8601String(),
    });
    expect(record.itemDescription, 'بطانيات شتوية جديدة، مقاس كبير');
    expect(record.targetId, 'need-9');
    expect(record.targetType, 'case');
  });

  test('a charity-pool donation is labelled and slugged as charity', () {
    final response = DonationResponse.fromJson({
      'data': {
        'id': 'donation-4',
        'donationType': 1,
        'targetType': 3,
        'charityId': 'charity-1',
        'donationDate': '2026-08-23T08:00:00Z',
        'status': 1,
        'amount': 100,
      },
      'isSuccess': true,
    });

    // No entityName came back, so the fallback must not claim it is a campaign.
    expect(response.targetName, 'تبرع مباشر للجمعية');

    final record = DonationRecord.fromServer({
      'id': response.id,
      'donationType': response.donationType,
      'targetType': response.targetType,
      'status': response.status,
      'donationDate': response.donationDate.toIso8601String(),
    });
    expect(record.targetType, 'charity');
  });
}
