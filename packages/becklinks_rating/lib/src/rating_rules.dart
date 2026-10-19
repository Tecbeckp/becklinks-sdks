import 'package:meta/meta.dart';

import 'rating_policy.dart';

/// What the app has done on this device, kept locally and never sent anywhere.
@immutable
class RatingCounters {
  /// Creates counters.
  const RatingCounters({
    this.sessions = 0,
    this.firstOpen,
    this.lastSession,
    this.prompts = const <DateTime>[],
  });

  /// Reads the stored form; anything malformed starts from zero (which only delays a prompt).
  factory RatingCounters.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const RatingCounters();
    DateTime? time(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toUtc() : null;
    final sessions = json['sessions'];
    final prompts = json['prompts'];
    return RatingCounters(
      sessions: sessions is int && sessions >= 0 ? sessions : 0,
      firstOpen: time(json['first_open']),
      lastSession: time(json['last_session']),
      prompts: prompts is List<Object?>
          ? <DateTime>[
              for (final entry in prompts)
                if (time(entry) case final DateTime moment) moment,
            ]
          : const <DateTime>[],
    );
  }

  /// Opens of the app counted so far.
  final int sessions;

  /// When the first open was counted, UTC.
  final DateTime? firstOpen;

  /// When the latest open was counted, UTC.
  final DateTime? lastSession;

  /// When earlier prompts were requested, UTC, oldest first.
  final List<DateTime> prompts;

  /// A copy with the given fields replaced.
  RatingCounters copyWith({
    int? sessions,
    DateTime? firstOpen,
    DateTime? lastSession,
    List<DateTime>? prompts,
  }) =>
      RatingCounters(
        sessions: sessions ?? this.sessions,
        firstOpen: firstOpen ?? this.firstOpen,
        lastSession: lastSession ?? this.lastSession,
        prompts: prompts ?? this.prompts,
      );

  /// The form kept on the device.
  Map<String, Object?> toJson() => <String, Object?>{
        'sessions': sessions,
        'first_open': firstOpen?.toIso8601String(),
        'last_session': lastSession?.toIso8601String(),
        'prompts': <String>[
          for (final moment in prompts) moment.toIso8601String()
        ],
      };
}

/// Why the app may or may not ask now.
enum RatingDecision {
  /// All thresholds are met: ask.
  ask,

  /// The owner turned the prompt off, or no policy could be had.
  disabled,

  /// The app has not been opened often enough yet.
  notEnoughSessions,

  /// The first open is too recent.
  tooSoonAfterInstall,

  /// The previous prompt is too recent.
  tooSoonAfterPrompt,

  /// The prompts of the last 365 days are used up.
  yearlyLimitReached,

  /// This platform is not Android or iOS.
  unsupportedPlatform,
}

/// Decides, from the policy and the device's counters, whether to ask now. A pure function: the
/// clock is a parameter, so every threshold is tested at its edge.
RatingDecision decideRating(
    RatingPolicy policy, RatingCounters counters, DateTime now) {
  if (!policy.enabled) return RatingDecision.disabled;
  final current = now.toUtc();
  if (counters.sessions < policy.minSessions) {
    return RatingDecision.notEnoughSessions;
  }

  final first = counters.firstOpen;
  if (first == null ||
      current.difference(first) < Duration(days: policy.minDaysSinceInstall)) {
    return RatingDecision.tooSoonAfterInstall;
  }

  final lastYear = counters.prompts
      .where((moment) => current.difference(moment) < const Duration(days: 365))
      .toList()
    ..sort();
  if (lastYear.length >= policy.maxPromptsPerYear) {
    return RatingDecision.yearlyLimitReached;
  }
  if (lastYear.isNotEmpty &&
      current.difference(lastYear.last) <
          Duration(days: policy.minDaysBetweenPrompts)) {
    return RatingDecision.tooSoonAfterPrompt;
  }
  return RatingDecision.ask;
}
