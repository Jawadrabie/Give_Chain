import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/features/catalog/data/catalog_models.dart';

/// The detail screen's funding headline is derived, not read straight from the
/// payload: every campaign and case in production leaves `targetAmount` and
/// `achievedAmount` null, and the real money sits on `caseNeeds`.
void main() {
  group('case funding aggregates from caseNeeds', () {
    // Verbatim shape from live case 494757d1 (money need, part funded).
    CatalogItem moneyCase() => CatalogItem.fromJson({
      'id': 'case-money',
      'priority': 0,
      'title': 'عائلة نازحة تبحث عن مأوى',
      'targetAmount': null,
      'achievedAmount': null,
      'caseNeeds': [
        {
          'id': 'need-1',
          'name': 'إيجار شهري',
          'caseNeedType': 2,
          'amount': 1500,
          'fulfilledAmount': 250,
          'quantity': null,
          'fulfilledQuantity': null,
        },
      ],
    });

    test('money target and collected come from the needs', () {
      final item = moneyCase();

      expect(item.effectiveGoalAmount, 1500);
      expect(item.effectiveCollectedAmount, 250);
      expect(item.hasMonetaryGoal, isTrue);
    });

    test('progress reflects the real ratio, not a flat zero', () {
      // Reading only the top-level (null) fields would render 0%.
      expect(moneyCase().progress, closeTo(250 / 1500, 1e-9));
    });

    test('remaining is the shortfall across the needs', () {
      expect(moneyCase().remainingAmount, 1250);
    });

    test('several needs sum together', () {
      final item = CatalogItem.fromJson({
        'id': 'case-multi',
        'priority': 0,
        'caseNeeds': [
          {'id': 'a', 'name': 'أ', 'amount': 1000, 'fulfilledAmount': 400},
          {'id': 'b', 'name': 'ب', 'amount': 3000, 'fulfilledAmount': 100},
        ],
      });

      expect(item.effectiveGoalAmount, 4000);
      expect(item.effectiveCollectedAmount, 500);
      expect(item.progress, closeTo(0.125, 1e-9));
    });

    test('an in-kind case reports quantity progress instead', () {
      // Live case f46c7f64 carries quantity 30, fulfilled 10.
      final item = CatalogItem.fromJson({
        'id': 'case-qty',
        'priority': 0,
        'caseNeeds': [
          {
            'id': 'need-q',
            'name': 'سلل غذائية',
            'quantity': 30,
            'fulfilledQuantity': 10,
            'unit': 4,
            'amount': null,
            'fulfilledAmount': null,
          },
        ],
      });

      expect(item.hasMonetaryGoal, isFalse);
      expect(item.effectiveTargetQuantity, 30);
      expect(item.effectiveAchievedQuantity, 10);
      expect(item.quantityProgress, closeTo(1 / 3, 1e-9));
    });
  });

  group('items with no goal at all', () {
    test('a campaign with null goals reports no monetary target', () {
      // All 7 production campaigns look exactly like this.
      final item = CatalogItem.fromJson({
        'id': 'campaign-1',
        'campaignName': 'حملة دعم ذوي الإعاقة',
        'targetAmount': null,
        'achievedAmount': null,
        'targetQuantity': null,
        'achievedQuantity': null,
        'goalType': null,
      });

      expect(item.hasMonetaryGoal, isFalse);
      expect(item.quantityProgress, isNull);
      // The screen shows "تجميع مفتوح" rather than a misleading 0% bar.
      expect(item.progress, 0);
    });
  });

  group('explicit top-level goals still win', () {
    test('a campaign with its own target ignores any needs', () {
      final item = CatalogItem.fromJson({
        'id': 'campaign-2',
        'campaignName': 'حملة',
        'targetAmount': 8000,
        'achievedAmount': 2000,
        'caseNeeds': [
          {'id': 'x', 'name': 'x', 'amount': 999, 'fulfilledAmount': 999},
        ],
      });

      expect(item.effectiveGoalAmount, 8000);
      expect(item.effectiveCollectedAmount, 2000);
      expect(item.progress, closeTo(0.25, 1e-9));
    });
  });

  group('extra backend fields', () {
    test('reference number, lock state and icons are captured', () {
      final item = CatalogItem.fromJson({
        'id': 'case-x',
        'priority': 1,
        'caseNumber': 'CASE-2026-001',
        'isStatusLocked': true,
        'statusLockNote': 'قيد المراجعة القانونية',
        'trustImageUrl': '/Images/trust.png',
        'category': {'id': 'c1', 'name': 'صحة', 'iconUrl': '/Images/c1.png'},
      });

      expect(item.referenceNumber, 'CASE-2026-001');
      expect(item.isStatusLocked, isTrue);
      expect(item.statusLockNote, 'قيد المراجعة القانونية');
      expect(item.trustImageUrl, '/Images/trust.png');
      expect(item.typeIconUrl, '/Images/c1.png');
    });

    test('a campaign reference number reads from campaignNumber', () {
      final item = CatalogItem.fromJson({
        'id': 'campaign-3',
        'campaignName': 'حملة',
        'campaignNumber': 'CMP-77',
      });

      expect(item.referenceNumber, 'CMP-77');
    });

    test('the empty strings production sends today stay empty', () {
      final item = CatalogItem.fromJson({
        'id': 'case-y',
        'priority': 0,
        'caseNumber': '',
        'statusLockNote': null,
      });

      expect(item.referenceNumber, isEmpty);
      expect(item.isStatusLocked, isFalse);
      expect(item.statusLockNote, isEmpty);
    });
  });
}
