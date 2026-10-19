import 'dart:convert';
import 'dart:io';

import 'package:becklinks_core/becklinks_core.dart';
import 'package:becklinks_rating/becklinks_rating.dart';
import 'package:becklinks_rating/src/sdk_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _key = 'pk_test_AbCdEfGh12345678';

const Map<String, Object?> _on = <String, Object?>{
  'enabled': true,
  'min_sessions': 2,
  'min_days_since_install': 1,
  'min_days_between_prompts': 30,
  'max_prompts_per_year': 3,
};

class _FakeRequester implements ReviewRequester {
  _FakeRequester({this.available = true, this.failing = false});

  final bool available;
  final bool failing;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> request() async {
    requests += 1;
    if (failing) throw StateError('dialog crashed');
  }
}

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 1, 9);
  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

class _Harness {
  _Harness({
    Map<String, Object?> policy = _on,
    this.requester,
    this.networkUp = true,
    TargetPlatform platform = TargetPlatform.android,
    RatingStore? store,
  })  : policy = {...policy},
        store = store ?? MemoryRatingStore(),
        clock = _Clock() {
    fake = requester ?? _FakeRequester();
    rating = BeckLinksRating(
      apiKey: _key,
      client: BeckLinksApiClient(
        apiKey: _key,
        sdkName: 'becklinks_rating',
        sdkVersion: '0.1.0',
        maxRetries: 0,
        httpClient: MockClient((request) async {
          requestsSeen.add(request);
          if (!networkUp) throw http.ClientException('offline');
          return http.Response(jsonEncode(this.policy), 200,
              headers: {'content-type': 'application/json'});
        }),
      ),
      store: this.store,
      requester: fake,
      platform: platform,
      clock: clock.call,
    );
  }

  final Map<String, Object?> policy;
  final _FakeRequester? requester;
  final RatingStore store;
  final _Clock clock;
  bool networkUp;
  late final _FakeRequester fake;
  late final BeckLinksRating rating;
  final List<http.Request> requestsSeen = <http.Request>[];

  /// Two counted opens a day apart, so the default test policy is met.
  Future<void> reachThresholds() async {
    await rating.recordSession();
    clock.advance(const Duration(days: 1, hours: 1));
    await rating.recordSession();
  }
}

void main() {
  test('sends the platform and the SDK headers, anonymously', () async {
    final harness = _Harness(platform: TargetPlatform.iOS);
    await harness.reachThresholds();
    await harness.rating.check();
    final request = harness.requestsSeen.single;
    expect(request.url.path, '/v1/sdk/rating-policy');
    expect(jsonDecode(request.body), {'platform': 'ios'});
    expect(request.headers['x-sdk-name'], 'becklinks_rating');
    expect(request.headers['authorization'], 'Bearer $_key');
  });

  group('recordSession', () {
    test('counts opens, but not a second one within 30 minutes', () async {
      final harness = _Harness();
      await harness.rating.recordSession();
      harness.clock.advance(const Duration(minutes: 10));
      await harness.rating.recordSession();
      expect(await harness.rating.check(), RatingDecision.notEnoughSessions);
      harness.clock.advance(const Duration(hours: 25));
      await harness.rating.recordSession();
      expect(await harness.rating.check(), RatingDecision.ask);
    });

    test('does nothing on platforms other than Android and iOS', () async {
      final harness = _Harness(platform: TargetPlatform.windows);
      await harness.rating.recordSession();
      expect(await harness.store.read('counters'), isNull);
      expect(await harness.rating.check(), RatingDecision.unsupportedPlatform);
      expect(harness.requestsSeen, isEmpty);
    });
  });

  group('maybeRequestReview', () {
    test('asks the system once the thresholds are met, and remembers it',
        () async {
      final harness = _Harness();
      await harness.reachThresholds();
      expect(await harness.rating.maybeRequestReview(), isTrue);
      expect(harness.fake.requests, 1);
      // Asking again at once is too soon after the previous prompt.
      expect(await harness.rating.maybeRequestReview(), isFalse);
      expect(harness.fake.requests, 1);
      expect(await harness.rating.check(), RatingDecision.tooSoonAfterPrompt);
      harness.clock.advance(const Duration(days: 31));
      expect(await harness.rating.check(), RatingDecision.ask);
    });

    test(
        'does not ask before the thresholds are met or while the policy is off',
        () async {
      final early = _Harness();
      await early.rating.recordSession();
      expect(await early.rating.maybeRequestReview(), isFalse);
      expect(early.fake.requests, 0);

      final off = _Harness(policy: {..._on, 'enabled': false});
      await off.reachThresholds();
      expect(await off.rating.maybeRequestReview(), isFalse);
      expect(off.fake.requests, 0);
    });

    test('does not ask when the system cannot show the dialog', () async {
      final harness = _Harness(requester: _FakeRequester(available: false));
      await harness.reachThresholds();
      expect(await harness.rating.maybeRequestReview(), isFalse);
      expect(harness.fake.requests, 0);
      // Nothing was recorded, so a later device state is not penalised.
      expect(await harness.rating.check(), RatingDecision.ask);
    });

    test(
        'records the prompt before asking, so a crashing dialog is not repeated',
        () async {
      final harness = _Harness(requester: _FakeRequester(failing: true));
      await harness.reachThresholds();
      expect(await harness.rating.maybeRequestReview(), isFalse);
      expect(harness.fake.requests, 1);
      expect(await harness.rating.check(), RatingDecision.tooSoonAfterPrompt);
    });
  });

  group('the policy', () {
    test('is fetched once a day, not on every check', () async {
      final harness = _Harness();
      await harness.reachThresholds();
      await harness.rating.check();
      await harness.rating.check();
      expect(harness.requestsSeen, hasLength(1));
      harness.clock.advance(const Duration(hours: 25));
      await harness.rating.check();
      expect(harness.requestsSeen, hasLength(2));
    });

    test('a change in the dashboard is picked up on the next fetch', () async {
      final harness = _Harness(policy: {..._on, 'enabled': false});
      await harness.reachThresholds();
      expect(await harness.rating.check(), RatingDecision.disabled);
      harness.policy['enabled'] = true;
      harness.clock.advance(const Duration(hours: 25));
      expect(await harness.rating.check(), RatingDecision.ask);
    });

    test(
        'without a network, a policy up to a week old still stands, older means no prompt',
        () async {
      final harness = _Harness();
      await harness.reachThresholds();
      expect(await harness.rating.check(), RatingDecision.ask);
      harness.networkUp = false;
      harness.clock.advance(const Duration(days: 3));
      expect(await harness.rating.check(), RatingDecision.ask);
      harness.clock.advance(const Duration(days: 5));
      expect(await harness.rating.check(), RatingDecision.disabled);
    });

    test('without a network and nothing stored, the app does not ask',
        () async {
      final harness = _Harness(networkUp: false);
      await harness.reachThresholds();
      expect(await harness.rating.check(), RatingDecision.disabled);
      expect(await harness.rating.maybeRequestReview(), isFalse);
    });

    test(
        'a damaged answer means do not ask, and a damaged store starts from zero',
        () async {
      final damaged = _Harness(policy: {..._on, 'min_sessions': 0});
      await damaged.reachThresholds();
      expect(await damaged.rating.check(), RatingDecision.disabled);

      final store = MemoryRatingStore();
      await store.write('counters', 'not json');
      await store.write('policy', '{broken');
      final harness = _Harness(store: store);
      expect(await harness.rating.check(), RatingDecision.notEnoughSessions);
    });
  });

  test('refuses a secret key when created', () {
    expect(
      () => BeckLinksRating(apiKey: 'sk_live_AbCdEfGh12345678'),
      throwsA(isA<BeckLinksException>()),
    );
  });

  test('the version sent as X-SDK-Version is the version of pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version: (\S+)', multiLine: true).firstMatch(pubspec);
    expect(sdkVersion, match?.group(1));
  });
}
