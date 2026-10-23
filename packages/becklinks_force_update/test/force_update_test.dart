import 'dart:convert';

import 'package:becklinks_core/becklinks_core.dart';
import 'package:becklinks_force_update/becklinks_force_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _key = 'pk_test_AbCdEfGh12345678';
const String _store =
    'https://play.google.com/store/apps/details?id=com.acme.shop';

http.Response _answer(Map<String, Object?> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

const Map<String, Object?> _required = <String, Object?>{
  'status': 'update_required',
  'minimum_version': '2.0.0',
  'latest_version': '2.3.0',
  'store_url': _store,
  'title': 'Update needed',
  'message': 'Please update.',
};

BeckLinksForceUpdate _checker(
  Future<http.Response> Function(http.Request) handler, {
  String version = '1.9.0',
  TargetPlatform platform = TargetPlatform.android,
  UpdateCache? cache,
  List<http.Request>? seen,
}) =>
    BeckLinksForceUpdate(
      apiKey: _key,
      client: BeckLinksApiClient(
        apiKey: _key,
        sdkName: 'becklinks_force_update',
        sdkVersion: '0.1.1',
        maxRetries: 0,
        httpClient: MockClient((request) {
          seen?.add(request);
          return handler(request);
        }),
      ),
      appVersion: () async => version,
      platform: platform,
      cache: cache ?? MemoryUpdateCache(),
    );

void main() {
  test('asks with the platform and the running version and reads the verdict',
      () async {
    final seen = <http.Request>[];
    final result =
        await _checker((request) async => _answer(_required), seen: seen)
            .check();
    expect(result.status, UpdateStatus.updateRequired);
    expect(result.isRequired, isTrue);
    expect(result.minimumVersion, '2.0.0');
    expect(result.storeUrl, _store);
    expect(result.title, 'Update needed');
    expect(result.fromCache, isFalse);
    expect(seen.single.url.path, '/v1/sdk/app-version');
    expect(jsonDecode(seen.single.body),
        {'platform': 'android', 'app_version': '1.9.0'});
    expect(seen.single.headers['x-sdk-name'], 'becklinks_force_update');
  });

  test('asks as ios on iOS', () async {
    final seen = <http.Request>[];
    await _checker(
      (request) async => _answer({'status': 'ok'}),
      platform: TargetPlatform.iOS,
      seen: seen,
    ).check();
    expect(jsonDecode(seen.single.body), containsPair('platform', 'ios'));
  });

  test('reads an available update and an ok answer', () async {
    final available = await _checker(
      (request) async => _answer({..._required, 'status': 'update_available'}),
    ).check();
    expect(available.isAvailable, isTrue);
    expect(available.isRequired, isFalse);
    final ok =
        await _checker((request) async => _answer({'status': 'ok'})).check();
    expect(ok.status, UpdateStatus.ok);
  });

  test('does not ask on other platforms and survives an unreadable app version',
      () async {
    final seen = <http.Request>[];
    final desktop = await _checker(
      (request) async => _answer(_required),
      platform: TargetPlatform.windows,
      seen: seen,
    ).check();
    expect(desktop.status, UpdateStatus.ok);
    expect(seen, isEmpty);

    final broken = BeckLinksForceUpdate(
      apiKey: _key,
      appVersion: () async => throw StateError('no package info'),
      platform: TargetPlatform.android,
      cache: MemoryUpdateCache(),
    );
    expect((await broken.check()).status, UpdateStatus.ok);
  });

  test(
      'an unknown status or an update without an https store URL means nothing to do',
      () async {
    expect(
      (await _checker(
                  (request) async => _answer({'status': 'brand_new_status'}))
              .check())
          .status,
      UpdateStatus.ok,
    );
    expect(
      (await _checker(
        (request) async =>
            _answer({..._required, 'store_url': 'http://example.com'}),
      ).check())
          .status,
      UpdateStatus.ok,
    );
    expect(
      (await _checker(
                  (request) async => _answer({..._required, 'store_url': null}))
              .check())
          .status,
      UpdateStatus.ok,
    );
  });

  group('when the network fails', () {
    test('fails open for a fresh install', () async {
      final result = await _checker(
          (request) async => throw http.ClientException('offline')).check();
      expect(result.status, UpdateStatus.ok);
    });

    test('remembers an update that was required for this version', () async {
      final cache = MemoryUpdateCache();
      await _checker((request) async => _answer(_required), cache: cache)
          .check();
      final offline = await _checker(
        (request) async => throw http.ClientException('offline'),
        cache: cache,
      ).check();
      expect(offline.isRequired, isTrue);
      expect(offline.fromCache, isTrue);
      expect(offline.storeUrl, _store);
    });

    test(
        'forgets it for a newer version of the app, and once the policy is lifted',
        () async {
      final cache = MemoryUpdateCache();
      await _checker((request) async => _answer(_required), cache: cache)
          .check();
      final updated = await _checker(
        (request) async => throw http.ClientException('offline'),
        version: '2.1.0',
        cache: cache,
      ).check();
      expect(updated.status, UpdateStatus.ok);

      await _checker((request) async => _answer({'status': 'ok'}), cache: cache)
          .check();
      expect(await cache.read(), isNull);
    });

    test(
        'fails open when the API refuses the key or the stored answer is damaged',
        () async {
      final cache = MemoryUpdateCache();
      await cache.write('not json');
      final refused = await _checker(
        (request) async => _answer({'code': 'invalid_api_key'}, 401),
        cache: cache,
      ).check();
      expect(refused.status, UpdateStatus.ok);
    });
  });

  test('refuses a secret key when created', () {
    expect(
      () => BeckLinksForceUpdate(apiKey: 'sk_live_AbCdEfGh12345678'),
      throwsA(isA<BeckLinksException>()),
    );
  });

  test('result JSON round-trips and compares by value', () {
    final result = UpdateCheckResult.fromJson(_required);
    expect(UpdateCheckResult.fromJson(result.toJson()), result);
    expect(result.hashCode, UpdateCheckResult.fromJson(_required).hashCode);
    expect(result.toString(), contains('update_required'));
  });
}
