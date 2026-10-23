# becklinks_core

The shared API client of the [Beck Links](https://becklinks.com) Flutter packages that are not the
deep linking SDK (`becklinks_force_update` and `becklinks_rating`): publishable key checks, HTTP with
retries and backoff, one exception type and a small logger. It is published on its own so those
packages can be installed alone.

```dart
import 'package:becklinks_core/becklinks_core.dart';

final client = BeckLinksApiClient(
  apiKey: 'pk_live_yourPublishableKey',
  sdkName: 'my_package',
  sdkVersion: '1.0.0',
);
final answer = await client.postJson('/v1/sdk/app-version', {
  'platform': 'ios',
  'app_version': '2.1.0',
});
```

A complete example is in [`example/lib/main.dart`](example/lib/main.dart).

## What it does

- **Keys:** `pk_test_...` and `pk_live_...` only; a secret key (`sk_...`) is refused with the advice
  to revoke it.
- **Retries:** network failures, `5xx` and `429` are retried (twice by default) with backoff; a
  `Retry-After` longer than five seconds is not waited for.
- **Errors:** every failure is a `BeckLinksException` with a `code` (`network`, `invalid_key`,
  `rate_limited`, `invalid_request`, `server`, ...), the API's own `apiCode` and the request ID.
- **Logging:** a small logger that never writes keys.

## Do I need it?

Usually you do not add it yourself: install a feature package such as
[`becklinks_force_update`](https://pub.dev/packages/becklinks_force_update) or
[`becklinks_rating`](https://pub.dev/packages/becklinks_rating) and this comes with it. Use it
directly when you build your own client for the Beck Links SDK API.

## More Beck Links packages for Flutter

- [`becklinks_flutter`](https://pub.dev/packages/becklinks_flutter): deep links, deferred deep links
  and install attribution.
- [`becklinks_force_update`](https://pub.dev/packages/becklinks_force_update): require or suggest an
  app update.
- [`becklinks_rating`](https://pub.dev/packages/becklinks_rating): ask for a store review at the
  right moment.

MIT licensed.
