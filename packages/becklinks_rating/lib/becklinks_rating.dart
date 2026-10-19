/// Ask for a store review at the right moment in Flutter apps on Android and iOS.
///
/// Create one [BeckLinksRating] with the publishable key of your project, call `recordSession()`
/// once per launch and `maybeRequestReview()` after something good happened. The thresholds are set
/// in the Beck Links dashboard; the rules run on the device. It works on its own: no other Beck Links
/// package is needed.
library;

export 'package:becklinks_core/becklinks_core.dart'
    show BeckLinksErrorCode, BeckLinksException, LogLevel;

export 'src/becklinks_rating.dart' show BeckLinksRating;
export 'src/rating_policy.dart' show RatingPolicy;
export 'src/rating_rules.dart'
    show RatingCounters, RatingDecision, decideRating;
export 'src/rating_store.dart'
    show MemoryRatingStore, RatingStore, SharedPreferencesRatingStore;
export 'src/review_requester.dart' show InAppReviewRequester, ReviewRequester;
