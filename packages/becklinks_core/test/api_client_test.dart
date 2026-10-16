import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:becklinks_core/becklinks_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _key = 'pk_test_AbCdEfGh12345678';

http.Response _json(Object body,
        [int status = 200, Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), status, headers: <String, String>{
      'content-type': 'application/json',
      ...headers,
    });

BeckLinksApiClient _client(
  MockClientHandler handler, {
  List<Duration>? sleeps,
  int maxRetries = 2,
  Duration timeout = const Duration(seconds: 10),
}) =>
    BeckLinksApiClient(
      apiKey: _key,
      sdkName: 'becklinks_test',
      sdkVersion: '1.2.3',
      httpClient: MockClient(handler),
      maxRetries: maxRetries,
      timeout: timeout,
      sleep: (duration) async => sleeps?.add(duration),
      random: Random(1),
    );

void main() {
  group('configuration', () {
    test('refuses a secret key and says to revoke it', () {
      expect(
        () => BeckLinksApiClient(
            apiKey: 'sk_live_AbCdEfGh12345678',
            sdkName: 'x',
            sdkVersion: '1.0.0'),
        throwsA(
          isA<BeckLinksException>()
              .having((e) => e.code, 'code',
                  BeckLinksErrorCode.invalidConfiguration)
              .having((e) => e.message, 'message', contains('revoke')),
        ),
      );
    });

    test('refuses empty and malformed keys', () {
      for (final key in ['', 'pk_dev_AbCdEfGh12345678', 'pk_test_short']) {
        expect(() => validatePublishableKey(key),
            throwsA(isA<BeckLinksException>()),
            reason: key);
      }
      expect(validatePublishableKey(_key), _key);
      expect(isTestKey(_key), isTrue);
      expect(isTestKey('pk_live_AbCdEfGh12345678'), isFalse);
    });

    test('accepts http only for localhost', () {
      expect(
        () => BeckLinksApiClient(
          apiKey: _key,
          sdkName: 'x',
          sdkVersion: '1.0.0',
          baseUrl: Uri.parse('http://api.example.com'),
        ),
        throwsA(isA<BeckLinksException>()),
      );
      BeckLinksApiClient(
        apiKey: _key,
        sdkName: 'x',
        sdkVersion: '1.0.0',
        baseUrl: Uri.parse('http://localhost:4100'),
      ).close();
    });
  });

  group('postJson', () {
    test('sends the key, the SDK headers and the body, and returns the object',
        () async {
      late http.Request seen;
      final client = _client((request) async {
        seen = request;
        return _json({'status': 'ok'});
      });
      final result = await client.postJson(
        '/v1/sdk/app-version',
        {'platform': 'ios', 'app_version': '1.0.0'},
        idempotencyKey: 'abc',
      );
      expect(result, {'status': 'ok'});
      expect(
          seen.url.toString(), 'https://api.becklinks.com/v1/sdk/app-version');
      expect(seen.headers['authorization'], 'Bearer $_key');
      expect(seen.headers['x-sdk-name'], 'becklinks_test');
      expect(seen.headers['x-sdk-version'], '1.2.3');
      expect(seen.headers['idempotency-key'], 'abc');
      expect(
          jsonDecode(seen.body), {'platform': 'ios', 'app_version': '1.0.0'});
    });

    test('keeps the path of a custom API URL', () async {
      late Uri seen;
      final client = BeckLinksApiClient(
        apiKey: _key,
        sdkName: 'x',
        sdkVersion: '1.0.0',
        baseUrl: Uri.parse('https://example.com/api/'),
        httpClient: MockClient((request) async {
          seen = request.url;
          return _json(<String, Object?>{});
        }),
      );
      await client.postJson('/v1/x', const {});
      expect(seen.toString(), 'https://example.com/api/v1/x');
    });

    test('maps API errors to codes and keeps the problem details', () async {
      final cases = <int, BeckLinksErrorCode>{
        401: BeckLinksErrorCode.invalidKey,
        403: BeckLinksErrorCode.invalidKey,
        422: BeckLinksErrorCode.invalidRequest,
        404: BeckLinksErrorCode.invalidRequest,
      };
      for (final entry in cases.entries) {
        final client = _client((request) async => _json(
              {'code': 'some_code', 'detail': 'Why.'},
              entry.key,
              {'x-request-id': 'req-1'},
            ));
        await expectLater(
          client.postJson('/v1/x', const {}),
          throwsA(
            isA<BeckLinksException>()
                .having((e) => e.code, 'code', entry.value)
                .having((e) => e.statusCode, 'status', entry.key)
                .having((e) => e.apiCode, 'apiCode', 'some_code')
                .having((e) => e.requestId, 'requestId', 'req-1')
                .having((e) => e.message, 'message', 'Why.')
                .having((e) => e.isRetryable, 'retryable', false),
          ),
        );
      }
    });

    test('retries a 503 with the same idempotency key, then succeeds',
        () async {
      final keys = <String?>[];
      var calls = 0;
      final sleeps = <Duration>[];
      final client = _client((request) async {
        keys.add(request.headers['idempotency-key']);
        calls += 1;
        return calls == 1
            ? _json({'code': 'unavailable'}, 503)
            : _json({'ok': true});
      }, sleeps: sleeps);
      expect(await client.postJson('/v1/x', const {}, idempotencyKey: 'k1'),
          {'ok': true});
      expect(calls, 2);
      expect(keys, ['k1', 'k1']);
      expect(sleeps, hasLength(1));
      expect(sleeps.single, lessThanOrEqualTo(const Duration(seconds: 5)));
    });

    test('gives up after maxRetries and reports the last failure', () async {
      var calls = 0;
      final client = _client((request) async {
        calls += 1;
        return _json({'code': 'unavailable'}, 500);
      }, maxRetries: 1);
      await expectLater(
        client.postJson('/v1/x', const {}),
        throwsA(isA<BeckLinksException>()
            .having((e) => e.code, 'code', BeckLinksErrorCode.server)),
      );
      expect(calls, 2);
    });

    test('obeys a short Retry-After and does not wait for a long one',
        () async {
      var shortCalls = 0;
      final sleeps = <Duration>[];
      final shortClient = _client((request) async {
        shortCalls += 1;
        return shortCalls == 1
            ? _json({'code': 'rate_limited'}, 429, {'retry-after': '3'})
            : _json({'ok': true});
      }, sleeps: sleeps);
      await shortClient.postJson('/v1/x', const {});
      expect(sleeps.single, const Duration(seconds: 3));

      var longCalls = 0;
      final longClient = _client((request) async {
        longCalls += 1;
        return _json({'code': 'rate_limited'}, 429, {'retry-after': '60'});
      });
      await expectLater(
        longClient.postJson('/v1/x', const {}),
        throwsA(
          isA<BeckLinksException>()
              .having((e) => e.code, 'code', BeckLinksErrorCode.rateLimited)
              .having((e) => e.retryAfter, 'retryAfter',
                  const Duration(seconds: 60)),
        ),
      );
      expect(longCalls, 1);
    });

    test(
        'reports a network failure as retryable and a timeout as a network error',
        () async {
      var calls = 0;
      final offline = _client((request) async {
        calls += 1;
        throw http.ClientException('connection refused');
      }, maxRetries: 1);
      await expectLater(
        offline.postJson('/v1/x', const {}),
        throwsA(
          isA<BeckLinksException>()
              .having((e) => e.code, 'code', BeckLinksErrorCode.network)
              .having((e) => e.isRetryable, 'retryable', true),
        ),
      );
      expect(calls, 2);

      final slow = _client(
        (request) => Completer<http.Response>().future,
        maxRetries: 0,
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        slow.postJson('/v1/x', const {}),
        throwsA(isA<BeckLinksException>()
            .having((e) => e.code, 'code', BeckLinksErrorCode.network)),
      );
    });

    test('refuses an answer that is not a JSON object', () async {
      final client = _client((request) async => http.Response('<html>', 200),
          maxRetries: 0);
      await expectLater(
        client.postJson('/v1/x', const {}),
        throwsA(
          isA<BeckLinksException>().having(
              (e) => e.code, 'code', BeckLinksErrorCode.unexpectedResponse),
        ),
      );
      final list = _client((request) async => _json([1, 2]), maxRetries: 0);
      await expectLater(
          list.postJson('/v1/x', const {}), throwsA(isA<BeckLinksException>()));
    });
  });

  group('logger', () {
    test(
        'writes only what the level allows, with the tag, and never anything else',
        () {
      final lines = <String>[];
      const BeckLinksLogger(tag: 'T', level: LogLevel.info, sink: null);
      final logger =
          BeckLinksLogger(tag: 'T', level: LogLevel.info, sink: lines.add);
      logger
        ..error('bad')
        ..info('fine')
        ..debug('noisy');
      expect(lines, ['[T] ERROR: bad', '[T] INFO: fine']);
    });
  });
}
