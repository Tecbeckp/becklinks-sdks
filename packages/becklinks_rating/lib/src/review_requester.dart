import 'package:in_app_review/in_app_review.dart';

/// Shows the store's own review dialog. The store decides whether it really appears: the app
/// cannot know, and this package never claims a review happened.
abstract class ReviewRequester {
  /// Whether the system can show the dialog on this device.
  Future<bool> isAvailable();

  /// Asks the system to show the dialog.
  Future<void> request();
}

/// The default: the `in_app_review` package (StoreKit on iOS, Play In-App Review on Android).
class InAppReviewRequester implements ReviewRequester {
  /// Creates the requester.
  const InAppReviewRequester();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> request() => InAppReview.instance.requestReview();
}
