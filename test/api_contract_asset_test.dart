import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled API contract matches the backend mobile guide', () async {
    final raw = await rootBundle.loadString(
      'assets/config/givechain_api_contract.json',
    );
    final document = jsonDecode(raw) as Map<String, dynamic>;
    final operations = Map<String, dynamic>.from(
      document['confirmedOperations'] as Map,
    );

    expect((operations['login'] as Map)['path'], '/api/mobile/auth/login');
    expect(
      (operations['register'] as Map)['path'],
      '/api/mobile/auth/register',
    );
    expect(
      (operations['campaignDonate'] as Map)['path'],
      '/api/mobile/campaigns/{id}/donate',
    );
    expect((operations['profilePassword'] as Map)['method'], 'PUT');
    // `donationConfirmPayment` was dropped after the backend confirmed the
    // endpoint never existed (BACKEND_ANSWERS.md #6), taking the count 49 -> 48.
    expect(operations.containsKey('donationConfirmPayment'), isFalse);
    expect(operations.length, 48);
    expect(raw, isNot(contains('eyJ')));
    expect(raw, isNot(contains('gmail.com')));
  });
}
