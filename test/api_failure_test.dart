import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/core/network/api_failure.dart';

void main() {
  group('ApiFailure.fromPayload', () {
    test('accepts successful GiveChain envelope', () {
      final failure = ApiFailure.fromPayload({
        'message': null,
        'data': {'id': '1'},
        'errors': null,
        'isSuccess': true,
      });

      expect(failure, isNull);
    });

    test('extracts nested validation errors from failed envelope', () {
      final failure = ApiFailure.fromPayload({
        'message': 'فشل التحقق',
        'data': null,
        'errors': {
          'email': ['البريد غير صالح'],
          'password': ['كلمة المرور قصيرة'],
        },
        'isSuccess': false,
      });

      expect(failure, isNotNull);
      expect(failure!.message, 'فشل التحقق');
      expect(
        failure.validationErrors,
        containsAll(['البريد غير صالح', 'كلمة المرور قصيرة']),
      );
    });

    test('decodes JSON returned as text/plain', () {
      final failure = ApiFailure.fromPayload(
        '{"isSuccess":false,"message":"رفض الخادم","errors":null}',
      );

      expect(failure, isNotNull);
      expect(failure!.message, 'رفض الخادم');
    });
  });
}
