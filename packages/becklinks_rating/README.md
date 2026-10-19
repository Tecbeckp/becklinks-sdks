# becklinks_rating

Ask for a store review at the right moment in Flutter apps on Android and iOS, by
[Beck Links](https://becklinks.com). You set the thresholds in the Beck Links dashboard (how many opens,
how many days, how often); the app applies them to counters kept **on the device** and asks the system
for its own review dialog. It works on its own: no deep links and no other Beck Links package are
needed.

- **Right moment:** not on the first launch. The prompt waits for a number of opens, a number of days
  since the first open, and a pause since the previous prompt.
- **Within the stores' limits:** at most three prompts in 365 days (iOS shows its dialog three times a
  year at most; Android has its own quota that the app cannot see). The store decides whether the dialog
  appears.
- **Change it without a release:** the thresholds live in the dashboard.
- **Private:** the request holds only the platform. The counters never leave the device, and Beck Links
  does not learn who was asked or whether anyone reviewed.
- **Cautious:** if the thresholds cannot be had, or are older than a week, the app does not ask.

## Install

```sh
flutter pub add becklinks_rating
```

## Set the thresholds

In the Beck Links dashboard open the project, **Settings**, and fill **Rating prompt** for the
environment (test or live): turn it on, then set the opens, the days since install, the days between
prompts and the prompts per year, and select **Save rating prompt**. It is off until you do.

## Use it

```dart
import 'package:becklinks_rating/becklinks_rating.dart';

final rating = BeckLinksRating(apiKey: 'pk_live_YOUR_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rating.recordSession(); // once per launch, early
  runApp(const MyApp());
}

// After something good happened: an order, a finished level, a saved item.
Future<void> onOrderPlaced() async {
  await rating.maybeRequestReview();
}
```

`recordSession()` counts one open (calls within 30 minutes of the previous counted one are ignored, so
a hot restart does not count twice). `maybeRequestReview()` checks every threshold and, when they are
all met, asks the system for the review dialog and remembers the time. It returns `true` when it asked
and never throws. `check()` answers why it would not ask (`RatingDecision`) without asking.

Use the publishable key (`pk_test_...` or `pk_live_...`). A secret key (`sk_...`) is refused.

## Requirements

Flutter 3.27 or newer. Android and iOS: other platforms never ask. Uninstalling the app or clearing
its data starts the counters again.

## Documentation

[docs.becklinks.com/rating-prompt](https://docs.becklinks.com/rating-prompt) · MIT licensed.
