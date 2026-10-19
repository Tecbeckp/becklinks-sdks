import 'package:becklinks_rating/becklinks_rating.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 10, 20, 12);

const RatingPolicy _policy = RatingPolicy(
  enabled: true,
  minSessions: 5,
  minDaysSinceInstall: 3,
  minDaysBetweenPrompts: 90,
  maxPromptsPerYear: 3,
);

RatingCounters _counters({
  int sessions = 6,
  Duration sinceInstall = const Duration(days: 10),
  List<Duration> promptsAgo = const <Duration>[],
}) =>
    RatingCounters(
      sessions: sessions,
      firstOpen: _now.subtract(sinceInstall),
      lastSession: _now,
      prompts: <DateTime>[for (final ago in promptsAgo) _now.subtract(ago)],
    );

void main() {
  group('decideRating', () {
    test('asks when every threshold is met', () {
      expect(decideRating(_policy, _counters(), _now), RatingDecision.ask);
    });

    test('never asks while the policy is off', () {
      const off = RatingPolicy.disabled();
      expect(decideRating(off, _counters(), _now), RatingDecision.disabled);
    });

    test('the session threshold is "at least": one short waits, equal asks',
        () {
      expect(
        decideRating(_policy, _counters(sessions: 4), _now),
        RatingDecision.notEnoughSessions,
      );
      expect(decideRating(_policy, _counters(sessions: 5), _now),
          RatingDecision.ask);
    });

    test('the install threshold is exact to the moment', () {
      expect(
        decideRating(
          _policy,
          _counters(
              sinceInstall:
                  const Duration(days: 3) - const Duration(seconds: 1)),
          _now,
        ),
        RatingDecision.tooSoonAfterInstall,
      );
      expect(
        decideRating(
            _policy, _counters(sinceInstall: const Duration(days: 3)), _now),
        RatingDecision.ask,
      );
    });

    test('zero days since install allows the first open to count at once', () {
      const policy = RatingPolicy(
        enabled: true,
        minSessions: 1,
        minDaysSinceInstall: 0,
        minDaysBetweenPrompts: 1,
        maxPromptsPerYear: 1,
      );
      expect(
        decideRating(
            policy, _counters(sessions: 1, sinceInstall: Duration.zero), _now),
        RatingDecision.ask,
      );
    });

    test('an unknown first open waits', () {
      expect(
        decideRating(_policy, const RatingCounters(sessions: 99), _now),
        RatingDecision.tooSoonAfterInstall,
      );
    });

    test('waits for the days between prompts', () {
      expect(
        decideRating(
          _policy,
          _counters(promptsAgo: const [Duration(days: 89)]),
          _now,
        ),
        RatingDecision.tooSoonAfterPrompt,
      );
      expect(
        decideRating(
            _policy, _counters(promptsAgo: const [Duration(days: 90)]), _now),
        RatingDecision.ask,
      );
    });

    test(
        'stops at the prompts of the last 365 days, and counts older ones as gone',
        () {
      final three = <Duration>[
        const Duration(days: 300),
        const Duration(days: 200),
        const Duration(days: 100),
      ];
      expect(
        decideRating(_policy, _counters(promptsAgo: three), _now),
        RatingDecision.yearlyLimitReached,
      );
      // The oldest prompt is now more than a year old: only two count.
      final aged = <Duration>[
        const Duration(days: 366),
        const Duration(days: 200),
        const Duration(days: 100),
      ];
      expect(decideRating(_policy, _counters(promptsAgo: aged), _now),
          RatingDecision.ask);
    });

    test('a lower yearly maximum is honoured', () {
      const strict = RatingPolicy(
        enabled: true,
        minSessions: 1,
        minDaysSinceInstall: 0,
        minDaysBetweenPrompts: 1,
        maxPromptsPerYear: 1,
      );
      expect(
        decideRating(
            strict, _counters(promptsAgo: const [Duration(days: 200)]), _now),
        RatingDecision.yearlyLimitReached,
      );
    });

    test('takes the clock in any time zone', () {
      expect(decideRating(_policy, _counters(), _now.toLocal()),
          RatingDecision.ask);
    });
  });

  group('RatingPolicy.fromJson', () {
    const good = <String, Object?>{
      'enabled': true,
      'min_sessions': 8,
      'min_days_since_install': 5,
      'min_days_between_prompts': 120,
      'max_prompts_per_year': 2,
    };

    test('reads a complete answer and round-trips', () {
      final policy = RatingPolicy.fromJson(good);
      expect(policy.enabled, isTrue);
      expect(policy.minSessions, 8);
      expect(policy.maxPromptsPerYear, 2);
      expect(RatingPolicy.fromJson(policy.toJson()), policy);
      expect(policy.hashCode, RatingPolicy.fromJson(good).hashCode);
      expect(policy.toString(), contains('enabled: true'));
    });

    test('reads anything incomplete, mistyped or out of range as disabled', () {
      const disabled = RatingPolicy.disabled();
      expect(RatingPolicy.fromJson(const {}), disabled);
      expect(RatingPolicy.fromJson({...good, 'enabled': 'yes'}), disabled);
      expect(RatingPolicy.fromJson({...good, 'min_sessions': 0}), disabled);
      expect(RatingPolicy.fromJson({...good, 'min_sessions': '8'}), disabled);
      expect(RatingPolicy.fromJson({...good, 'max_prompts_per_year': 4}),
          disabled);
      expect(RatingPolicy.fromJson({...good, 'min_days_between_prompts': 800}),
          disabled);
      expect(RatingPolicy.fromJson({...good}..remove('min_days_since_install')),
          disabled);
      expect(disabled.enabled, isFalse);
    });
  });

  group('RatingCounters', () {
    test('round-trips through its stored form', () {
      final counters = _counters(promptsAgo: const [Duration(days: 5)]);
      final back = RatingCounters.fromJson(counters.toJson());
      expect(back.sessions, counters.sessions);
      expect(back.firstOpen, counters.firstOpen);
      expect(back.prompts, counters.prompts);
    });

    test('starts from zero when the stored form is damaged', () {
      for (final broken in <Object?>[
        null,
        'x',
        7,
        <Object?>[],
        {'sessions': -3}
      ]) {
        final counters = RatingCounters.fromJson(broken);
        expect(counters.sessions, 0, reason: '$broken');
        expect(counters.prompts, isEmpty);
      }
      final partial = RatingCounters.fromJson({
        'sessions': 4,
        'first_open': 'not a date',
        'prompts': ['2026-01-01T00:00:00Z', 5, 'nope'],
      });
      expect(partial.sessions, 4);
      expect(partial.firstOpen, isNull);
      expect(partial.prompts, [DateTime.utc(2026)]);
    });
  });
}
