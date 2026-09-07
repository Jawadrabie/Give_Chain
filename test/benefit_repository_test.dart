import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/core/cache/api_response_cache.dart';
import 'package:give_chain_app/core/network/api_client.dart';
import 'package:give_chain_app/core/network/api_failure.dart';
import 'package:give_chain_app/core/storage/token_storage.dart';
import 'package:give_chain_app/features/benefits/data/benefit_models.dart';
import 'package:give_chain_app/features/benefits/data/benefit_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves canned responses per path so the repository's endpoint choice — the
/// whole point of the lookup/fallback logic — can be asserted directly.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handlers);

  /// Path (without query) → the response to serve.
  final Map<String, ResponseBody Function(RequestOptions)> handlers;

  /// Every path requested, in order, so a test can assert the fallback fired.
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri.path);
    final handler = handlers[options.uri.path];
    if (handler == null) {
      return ResponseBody.fromString('', 404, headers: _jsonHeaders);
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

const _jsonHeaders = {
  Headers.contentTypeHeader: ['application/json'],
};

ResponseBody _json(Object? data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: _jsonHeaders,
);

/// Wraps a payload the way every endpoint on this backend does.
Map<String, dynamic> _envelope(Object? data) => {
  'message': null,
  'data': data,
  'errors': null,
  'isSuccess': true,
};

/// An unexpired JWT, which is all [TokenStorage.hasSession] checks.
String _validJwt() {
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
  return '${part({'alg': 'none', 'typ': 'JWT'})}'
      '.${part({
        'uid': 'user-1',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      })}'
      '.signature';
}

Map<String, dynamic> _type(String id, {String charityId = 'charity-1'}) => {
  'id': id,
  'name': 'منفعة $id',
  'charityId': charityId,
  'isActive': true,
  'questions': <Map<String, dynamic>>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lookupPath = '/api/lookup/benefit-types';
  const charityId = 'charity-1';
  final charityPath = '/api/mobile/charities/$charityId/benefit-types';

  late _FakeAdapter adapter;

  /// Builds a repository whose HTTP goes through [adapter].
  ///
  /// [BenefitRepository] latches whether the lookup endpoint exists in a
  /// static field, so each test resets it to keep the cases independent.
  BenefitRepository buildRepository(
    Map<String, ResponseBody Function(RequestOptions)> handlers,
  ) {
    adapter = _FakeAdapter(handlers);
    ApiClient.initialize();
    ApiClient.instance.debugHttpAdapter = adapter;
    BenefitRepository.debugResetLookupProbe();
    return BenefitRepository(ApiClient.instance);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiResponseCache.initialize();
    // The repository caches lookups for two hours; a shared cache would let
    // one test answer another's request.
    await ApiResponseCache.clear();
  });

  group('benefitTypes', () {
    test('uses the lookup endpoint when the backend serves it', () async {
      final repository = buildRepository({
        lookupPath: (_) => _json(_envelope([_type('bt-1')])),
      });

      final types = await repository.benefitTypes(charityId: charityId);

      expect(types.single.id, 'bt-1');
      expect(adapter.requested, [lookupPath]);
    });

    test('passes charityId through to the lookup', () async {
      String? seenCharityId;
      final repository = buildRepository({
        lookupPath: (options) {
          seenCharityId = options.uri.queryParameters['charityId'];
          return _json(_envelope([_type('bt-1')]));
        },
      });

      await repository.benefitTypes(charityId: charityId);

      expect(seenCharityId, charityId);
    });

    test('omits charityId when listing across charities', () async {
      Map<String, String>? seenQuery;
      final repository = buildRepository({
        lookupPath: (options) {
          seenQuery = options.uri.queryParameters;
          return _json(_envelope([_type('bt-1')]));
        },
      });

      await repository.benefitTypes();

      expect(seenQuery, isEmpty);
    });

    test('falls back to the charity path when the lookup 404s', () async {
      final repository = buildRepository({
        // lookupPath deliberately unhandled -> 404
        charityPath: (_) => _json(_envelope([_type('bt-9')])),
      });

      final types = await repository.benefitTypes(charityId: charityId);

      expect(types.single.id, 'bt-9');
      expect(adapter.requested, [lookupPath, charityPath]);
    });

    test('pauses re-probing briefly after a 404', () async {
      final repository = buildRepository({
        charityPath: (_) => _json(_envelope([_type('bt-9')])),
      });

      await repository.benefitTypes(charityId: charityId);
      await ApiResponseCache.clear();
      await repository.benefitTypes(charityId: charityId);

      // The second call must not pay for another doomed lookup request.
      expect(
        adapter.requested,
        [lookupPath, charityPath, charityPath],
      );
    });

    test('returns to the lookup once the pause lapses', () async {
      final repository = buildRepository({
        charityPath: (_) => _json(_envelope([_type('bt-9')])),
      });

      await repository.benefitTypes(charityId: charityId);
      await ApiResponseCache.clear();

      // Standing in for the retry delay elapsing — the endpoint is expected to
      // ship, so a 404 must never park the app on the fallback for good.
      BenefitRepository.debugResetLookupProbe();
      await repository.benefitTypes(charityId: charityId);

      expect(
        adapter.requested,
        [lookupPath, charityPath, lookupPath, charityPath],
      );
    });

    test('fans out across charities when no charity is given', () async {
      final repository = buildRepository({
        // lookupPath unhandled -> 404, so the fan-out stands in for it.
        '/api/mobile/charities': (_) => _json(
          _envelope({
            'items': [
              {'id': 'charity-1', 'charityName': 'جمعية أ'},
              {'id': 'charity-2', 'charityName': 'جمعية ب'},
            ],
          }),
        ),
        charityPath: (_) => _json(_envelope([_type('bt-1')])),
        '/api/mobile/charities/charity-2/benefit-types': (_) =>
            _json(_envelope([_type('bt-2', charityId: 'charity-2')])),
      });

      final types = await repository.benefitTypes();

      expect(types.map((type) => type.id), ['bt-1', 'bt-2']);
      // The picker groups by charity, so each type must carry its name.
      expect(types.map((type) => type.charityName), ['جمعية أ', 'جمعية ب']);
    });

    test('keeps the charities that load when one fails', () async {
      final repository = buildRepository({
        '/api/mobile/charities': (_) => _json(
          _envelope({
            'items': [
              {'id': 'charity-1', 'charityName': 'جمعية أ'},
              {'id': 'charity-2', 'charityName': 'جمعية ب'},
            ],
          }),
        ),
        charityPath: (_) => _json(_envelope([_type('bt-1')])),
        // charity-2 unhandled -> 404.
      });

      final types = await repository.benefitTypes();

      // A partial picker beats an error screen when only one charity is down.
      expect(types.map((type) => type.id), ['bt-1']);
    });

    test('rethrows a non-404 lookup failure instead of falling back', () async {
      final repository = buildRepository({
        lookupPath: (_) => _json(_envelope(null), status: 500),
        charityPath: (_) => _json(_envelope([_type('bt-9')])),
      });

      await expectLater(
        repository.benefitTypes(charityId: charityId),
        throwsA(isA<ApiFailure>()),
      );
    });

    test('drops inactive types', () async {
      final repository = buildRepository({
        lookupPath: (_) => _json(
          _envelope([
            _type('bt-1'),
            {..._type('bt-2'), 'isActive': false},
          ]),
        ),
      });

      final types = await repository.benefitTypes(charityId: charityId);

      expect(types.map((type) => type.id), ['bt-1']);
    });
  });

  group('offerings', () {
    test('groups by name and puts the most available help first', () async {
      final repository = buildRepository({
        lookupPath: (_) => _json(
          _envelope([
            {..._type('bt-1'), 'name': 'مساعدة طبية'},
            {
              ..._type('bt-2', charityId: 'charity-2'),
              'name': 'مساعدة غذائية',
              'charityName': 'جمعية ب',
            },
            {
              ..._type('bt-3', charityId: 'charity-3'),
              'name': 'مساعدة غذائية',
              'charityName': 'جمعية ج',
            },
          ]),
        ),
      });

      final offerings = await repository.offerings();

      // Two charities offer food aid and one offers medical, so food leads.
      expect(offerings.map((o) => o.name), ['مساعدة غذائية', 'مساعدة طبية']);
      expect(offerings.first.types, hasLength(2));
      expect(offerings.first.isSingleCharity, isFalse);
      expect(offerings.last.isSingleCharity, isTrue);
    });
  });

  group('submit', () {
    setUp(() async {
      // Submitting is authenticated, so the client needs a live session
      // before it will even reach the transport.
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({'access_token': _validJwt()});
      await TokenStorage.initialize();
    });

    test('posts the documented body', () async {
      Object? seenBody;
      final repository = buildRepository({
        '/api/mobile/benefits': (options) {
          seenBody = options.data;
          return _json(_envelope({'id': 'r1'}));
        },
      });

      await repository.submit(
        benefitTypeId: 'bt-1',
        answers: const [
          BenefitAnswer(
            questionId: 'q1',
            answer: '4',
            questionText: 'عدد الأفراد',
          ),
        ],
      );

      // Only benefitTypeId and answers travel: the charity is implied by the
      // benefit type, and questionText is display-only.
      expect(seenBody, {
        'benefitTypeId': 'bt-1',
        'answers': [
          {'questionId': 'q1', 'answer': '4'},
        ],
      });
    });
  });

  group('mine', () {
    const benefitsPath = '/api/mobile/benefits';

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({'access_token': _validJwt()});
      await TokenStorage.initialize();
    });

    Map<String, dynamic> request(String id, String benefitTypeId) => {
      'id': id,
      'benefitTypeId': benefitTypeId,
      'benefitTypeName': 'منفعة',
      'requestNumber': 'REQ-$id',
      'submittedAt': '2026-08-01T10:00:00Z',
      'status': 0,
      'answers': <Map<String, dynamic>>[],
    };

    Map<String, dynamic> page(List<Map<String, dynamic>> items) => {
      'items': items,
      'totalCount': items.length,
      'page': 1,
      'pageSize': 20,
      'totalPages': 1,
    };

    test('returns every request when no charity is given', () async {
      final repository = buildRepository({
        benefitsPath: (_) => _json(
          _envelope(page([request('r1', 'bt-1'), request('r2', 'bt-2')])),
        ),
      });

      final result = await repository.mine();

      expect(result.items.map((item) => item.id), ['r1', 'r2']);
      // Without a charity there is nothing to filter against, so the
      // benefit-type lookup must not be fetched at all.
      expect(adapter.requested, [benefitsPath]);
    });

    test('sends the charity filter so a server-side one can take over',
        () async {
      String? seenCharityId;
      final repository = buildRepository({
        benefitsPath: (options) {
          seenCharityId = options.uri.queryParameters['charityId'];
          return _json(_envelope(page([])));
        },
      });

      await repository.mine(charityId: charityId);

      expect(seenCharityId, charityId);
    });

    test('filters locally to the charity that owns the benefit types',
        () async {
      final repository = buildRepository({
        // The backend ignores charityId today and returns everything.
        benefitsPath: (_) => _json(
          _envelope(page([request('r1', 'bt-1'), request('r2', 'other-bt')])),
        ),
        charityPath: (_) => _json(_envelope([_type('bt-1')])),
      });

      final result = await repository.mine(charityId: charityId);

      expect(result.items.map((item) => item.id), ['r1']);
      // The surviving request is tagged so the UI knows its charity.
      expect(result.items.single.charityId, charityId);
    });

    test('keeps the unfiltered page when the type lookup fails', () async {
      final repository = buildRepository({
        benefitsPath: (_) => _json(_envelope(page([request('r1', 'bt-1')]))),
        // charityPath unhandled -> 404, and the lookup 404s too.
      });

      final result = await repository.mine(charityId: charityId);

      // Dropping everything here would read as "you never applied", which is
      // a worse lie than showing a slightly wide list.
      expect(result.items.map((item) => item.id), ['r1']);
    });

    test('trusts an explicit charityId over the benefit-type lookup', () async {
      final repository = buildRepository({
        benefitsPath: (_) => _json(
          _envelope(
            page([
              {...request('r1', 'bt-1'), 'charityId': charityId},
              {...request('r2', 'bt-2'), 'charityId': 'other-charity'},
            ]),
          ),
        ),
      });

      final result = await repository.mine(charityId: charityId);

      expect(result.items.map((item) => item.id), ['r1']);
      // Every item already knew its charity, so no lookup was needed.
      expect(adapter.requested, [benefitsPath]);
    });

    test('reports the server paging, not the filtered count', () async {
      final repository = buildRepository({
        benefitsPath: (_) => _json(
          _envelope({
            'items': [request('r1', 'other-bt')],
            'totalCount': 40,
            'page': 1,
            'pageSize': 20,
            'totalPages': 2,
          }),
        ),
        charityPath: (_) => _json(_envelope([_type('bt-1')])),
      });

      final result = await repository.mine(charityId: charityId);

      // Nothing on this page survived the filter, but more pages remain: a
      // caller that stops here would miss the user's actual requests.
      expect(result.items, isEmpty);
      expect(result.hasMore, isTrue);
    });
  });
}
