# becklinks_force_update

Force update for Flutter apps on Android and iOS, by [Beck Links](https://becklinks.com). You set the
oldest app version that is still allowed (and the newest one) per platform in the Beck Links
dashboard; the app asks, and either must update, may update, or carries on. It works on its own: no
deep links and no other Beck Links package are needed.

- **Required update:** versions below the minimum get a screen that cannot be left, with a button to
  the store.
- **Optional update:** versions below the latest get a dismissible offer.
- **Fails open:** if the check cannot be made, the app is told it is fine, so a network or dashboard
  problem never locks anybody out. Only an update that was already required for this version stays
  required offline.
- **No tracking:** the check sends the platform and the app version, nothing else: no device or user
  identifier.

## Install

```sh
flutter pub add becklinks_force_update
```

## Set the policy

In the Beck Links dashboard open the project, **Settings**, and fill **Force update** for the
environment (test or live) and platform: minimum version, latest version, the store URL, and an
optional title and message. Turn the platform on and select **Save**. A change reaches apps within a
minute.

## Use it

```dart
import 'package:becklinks_force_update/becklinks_force_update.dart';
import 'package:flutter/material.dart';

final forceUpdate = BeckLinksForceUpdate(apiKey: 'pk_live_YOUR_KEY');

void main() => runApp(
      MaterialApp(
        // Above the navigator, so the screens cover everything.
        builder: (context, child) => ForceUpdateGate(
          forceUpdate: forceUpdate,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeScreen(),
      ),
    );
```

`ForceUpdateGate` checks when the app starts and each time it returns to the foreground (not more
than once a minute). Pass `texts: ForceUpdateTexts(...)` to translate the built-in screens, or
`requiredBuilder` and `availableBuilder` to draw your own.

Without the widget:

```dart
final result = await forceUpdate.check();
if (result.isRequired) {
  // Block the app; open result.storeUrl.
} else if (result.isAvailable) {
  // Offer an update.
}
```

Use the publishable key (`pk_test_...` or `pk_live_...`). A secret key (`sk_...`) is refused.

## Requirements

Flutter 3.27 or newer. Android and iOS: other platforms are told "ok" without a network call.

## More Beck Links packages for Flutter

- [`becklinks_flutter`](https://pub.dev/packages/becklinks_flutter): deep links, deferred deep links and install attribution.
- [`becklinks_rating`](https://pub.dev/packages/becklinks_rating): ask for a store review at the right moment.
- [`becklinks_core`](https://pub.dev/packages/becklinks_core): the shared API client of the packages above.

## Documentation

[docs.becklinks.com/force-update](https://docs.becklinks.com/force-update) · MIT licensed.
