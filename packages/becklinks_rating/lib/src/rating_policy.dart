import 'package:meta/meta.dart';

/// The thresholds the project owner set in the Beck Links dashboard.
@immutable
class RatingPolicy {
  /// Creates a policy.
  const RatingPolicy({
    required this.enabled,
    required this.minSessions,
    required this.minDaysSinceInstall,
    required this.minDaysBetweenPrompts,
    required this.maxPromptsPerYear,
  });

  /// The policy of "never ask": what an unreachable, missing or damaged answer means.
  const RatingPolicy.disabled()
      : this(
          enabled: false,
          minSessions: 5,
          minDaysSinceInstall: 3,
          minDaysBetweenPrompts: 90,
          maxPromptsPerYear: 3,
        );

  /// Reads the API's answer. Anything missing, of the wrong type or out of range reads as
  /// [RatingPolicy.disabled]: a damaged answer must never make the app ask more often.
  factory RatingPolicy.fromJson(Map<String, Object?> json) {
    int? whole(String key, int min, int max) {
      final value = json[key];
      return value is int && value >= min && value <= max ? value : null;
    }

    final enabled = json['enabled'];
    final minSessions = whole('min_sessions', 1, 1000);
    final minDays = whole('min_days_since_install', 0, 365);
    final between = whole('min_days_between_prompts', 1, 730);
    final perYear = whole('max_prompts_per_year', 1, 3);
    if (enabled is! bool ||
        minSessions == null ||
        minDays == null ||
        between == null ||
        perYear == null) {
      return const RatingPolicy.disabled();
    }
    return RatingPolicy(
      enabled: enabled,
      minSessions: minSessions,
      minDaysSinceInstall: minDays,
      minDaysBetweenPrompts: between,
      maxPromptsPerYear: perYear,
    );
  }

  /// Off: the app is never told to ask.
  final bool enabled;

  /// Opens of the app before the first prompt.
  final int minSessions;

  /// Days between the first open and the first prompt.
  final int minDaysSinceInstall;

  /// Days between two prompts.
  final int minDaysBetweenPrompts;

  /// Prompts in any 365 days (the stores allow three at most).
  final int maxPromptsPerYear;

  /// The form kept on the device.
  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'min_sessions': minSessions,
        'min_days_since_install': minDaysSinceInstall,
        'min_days_between_prompts': minDaysBetweenPrompts,
        'max_prompts_per_year': maxPromptsPerYear,
      };

  @override
  bool operator ==(Object other) =>
      other is RatingPolicy &&
      other.enabled == enabled &&
      other.minSessions == minSessions &&
      other.minDaysSinceInstall == minDaysSinceInstall &&
      other.minDaysBetweenPrompts == minDaysBetweenPrompts &&
      other.maxPromptsPerYear == maxPromptsPerYear;

  @override
  int get hashCode => Object.hash(
        enabled,
        minSessions,
        minDaysSinceInstall,
        minDaysBetweenPrompts,
        maxPromptsPerYear,
      );

  @override
  String toString() =>
      'RatingPolicy(enabled: $enabled, sessions: $minSessions, '
      'days: $minDaysSinceInstall, between: $minDaysBetweenPrompts, '
      'per year: $maxPromptsPerYear)';
}
