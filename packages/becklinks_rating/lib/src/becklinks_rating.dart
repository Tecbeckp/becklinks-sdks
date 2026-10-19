import 'dart:convert';

import 'package:becklinks_core/becklinks_core.dart';
import 'package:flutter/foundation.dart';

import 'rating_policy.dart';
import 'rating_rules.dart';
import 'rating_store.dart';
import 'review_requester.dart';
import 'sdk_info.dart';

const Duration _sessionGap = Duration(minutes: 30);
const Duration _policyFresh = Duration(hours: 24);
const Duration _policyUsable = Duration(days: 7);

/// Asks for a store review at the right moment.
///
/// ```dart
/// final rating = BeckLinksRating(apiKey: 'pk_live_YOUR_KEY');
/// await rating.recordSession();            // once per launch, early
/// // later, after something good happened (an order, a finished level):
/// await rating.maybeRequestReview();
/// ```
///
/// The thresholds come from the Beck Links dashboard and are applied to counters kept on the device;
/// nothing about the person leaves it. Every uncertainty means "do not ask": a policy that cannot be
/// had, or one older than a week, never makes the app prompt.
class BeckLinksRating {
  /// Creates the helper. Throws [BeckLinksException] for a secret or malformed key.
  ///
  /// [apiUrl], [client], [store], [requester], [platform] and [clock] exist for tests and
  /// self-hosted setups; apps leave them out.
  BeckLinksRating({
    required String apiKey,
    Uri? apiUrl,
    LogLevel logLevel = LogLevel.error,
    BeckLinksApiClient? client,
    RatingStore? store,
    ReviewRequester? requester,
    TargetPlatform? platform,
    DateTime Function()? clock,
  })  : _client = client ??
            BeckLinksApiClient(
              apiKey: apiKey,
              baseUrl: apiUrl,
              sdkName: sdkName,
              sdkVersion: sdkVersion,
              logger: BeckLinksLogger(tag: 'BeckLinksRating', level: logLevel),
            ),
        _logger = BeckLinksLogger(tag: 'BeckLinksRating', level: logLevel),
        _store = store ?? const SharedPreferencesRatingStore(),
        _requester = requester ?? const InAppReviewRequester(),
        _platform = platform,
        _clock = clock ?? DateTime.now;

  final BeckLinksApiClient _client;
  final BeckLinksLogger _logger;
  final RatingStore _store;
  final ReviewRequester _requester;
  final TargetPlatform? _platform;
  final DateTime Function() _clock;

  String? get _platformName => switch (_platform ?? defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

  /// Counts one open of the app. Call it once per launch, early. Calls less than 30 minutes after
  /// the previous counted one (a hot restart, a quick return) are not counted again.
  Future<void> recordSession() async {
    if (_platformName == null) return;
    final now = _clock().toUtc();
    final counters = await _readCounters();
    final last = counters.lastSession;
    if (last != null && now.difference(last) < _sessionGap) return;
    await _writeCounters(
      counters.copyWith(
        sessions: counters.sessions + 1,
        firstOpen: counters.firstOpen ?? now,
        lastSession: now,
      ),
    );
  }

  /// Says whether the app may ask now, without asking. Never throws.
  Future<RatingDecision> check() async {
    if (_platformName == null) return RatingDecision.unsupportedPlatform;
    final policy = await _policy();
    return decideRating(policy, await _readCounters(), _clock());
  }

  /// Asks the system for the review dialog when every threshold is met, and remembers that it did.
  /// Returns true when the request was made (the store still decides whether to show it). Never
  /// throws, so it is safe to call from any good moment.
  Future<bool> maybeRequestReview() async {
    try {
      if (await check() != RatingDecision.ask) return false;
      if (!await _requester.isAvailable()) {
        _logger.info('The system cannot show a review dialog here.');
        return false;
      }
      // Recorded before the request: if the dialog crashes the app, the next launch must not ask
      // again at once.
      final now = _clock().toUtc();
      final counters = await _readCounters();
      await _writeCounters(
          counters.copyWith(prompts: <DateTime>[...counters.prompts, now]));
      await _requester.request();
      return true;
    } on Object catch (error) {
      _logger.error('Could not request a review: $error');
      return false;
    }
  }

  Future<RatingPolicy> _policy() async {
    final now = _clock().toUtc();
    final cached = await _readCachedPolicy();
    if (cached != null && now.difference(cached.fetchedAt) < _policyFresh) {
      return cached.policy;
    }
    try {
      final json =
          await _client.postJson('/v1/sdk/rating-policy', <String, Object?>{
        'platform': _platformName,
      });
      final policy = RatingPolicy.fromJson(json);
      await _store.write(
        'policy',
        jsonEncode(<String, Object?>{
          'fetched_at': now.toIso8601String(),
          'policy': policy.toJson(),
        }),
      );
      return policy;
    } on BeckLinksException catch (error) {
      _logger.error('Could not get the rating policy: $error');
    } on Object catch (error) {
      _logger.error('Could not store the rating policy: $error');
    }
    // The server cannot be reached: a policy up to a week old still stands, older means no prompt.
    if (cached != null && now.difference(cached.fetchedAt) < _policyUsable) {
      return cached.policy;
    }
    return const RatingPolicy.disabled();
  }

  Future<({RatingPolicy policy, DateTime fetchedAt})?>
      _readCachedPolicy() async {
    try {
      final stored = await _store.read('policy');
      if (stored == null) return null;
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, Object?>) return null;
      final fetched = decoded['fetched_at'];
      final policy = decoded['policy'];
      final at = fetched is String ? DateTime.tryParse(fetched)?.toUtc() : null;
      if (at == null || policy is! Map<String, Object?>) return null;
      return (policy: RatingPolicy.fromJson(policy), fetchedAt: at);
    } on Object catch (error) {
      _logger.error('Could not read the stored policy: $error');
      return null;
    }
  }

  Future<RatingCounters> _readCounters() async {
    try {
      final stored = await _store.read('counters');
      return stored == null
          ? const RatingCounters()
          : RatingCounters.fromJson(jsonDecode(stored));
    } on Object catch (error) {
      _logger.error('Could not read the counters: $error');
      return const RatingCounters();
    }
  }

  Future<void> _writeCounters(RatingCounters counters) async {
    try {
      await _store.write('counters', jsonEncode(counters.toJson()));
    } on Object catch (error) {
      _logger.error('Could not store the counters: $error');
    }
  }

  /// Releases the network client.
  void dispose() => _client.close();
}
