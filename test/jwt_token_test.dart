import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/core/security/jwt_token.dart';

String _token(Map<String, dynamic> payload) {
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none', 'typ': 'JWT'})}.${part(payload)}.signature';
}

void main() {
  test('JwtTokenInfo parses supported claims', () {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final info = JwtTokenInfo.tryParse(
      _token({
        'uid': 'user-1',
        'iss': 'GiveChain',
        'aud': 'GiveChainUsers',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      }),
    );

    expect(info, isNotNull);
    expect(info!.userId, 'user-1');
    expect(info.issuer, 'GiveChain');
    expect(info.audience, 'GiveChainUsers');
    expect(info.isExpired, isFalse);
  });

  test('JwtTokenInfo marks an old token as expired', () {
    final info = JwtTokenInfo.tryParse(
      _token({
        'exp':
            DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }),
    );

    expect(info, isNotNull);
    expect(info!.isExpired, isTrue);
  });

  test('JwtTokenInfo rejects malformed tokens', () {
    expect(JwtTokenInfo.tryParse('not-a-token'), isNull);
  });
}
