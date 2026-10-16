# becklinks_core

The shared base of the [Beck Links](https://becklinks.com) Flutter packages that are not the deep
linking SDK (`becklinks_force_update`, later `becklinks_rating`): API key checks, the network client
with retries, one exception type and a small logger.

You normally do not install it yourself: install a feature package such as
[`becklinks_force_update`](https://pub.dev/packages/becklinks_force_update) and this comes with it.
Deep linking has its own package, [`becklinks_flutter`](https://pub.dev/packages/becklinks_flutter).

```dart
final client = BeckLinksApiClient(
  apiKey: 'pk_live_YOUR_KEY',
  sdkName: 'my_package',
  sdkVersion: '1.0.0',
);
final answer = await client.postJson('/v1/sdk/app-version', {'platform': 'ios', 'app_version': '2.1.0'});
```

- Keys: `pk_test_...` and `pk_live_...` only; a secret key (`sk_...`) is refused with the advice to
  revoke it.
- Retries: network failures, `5xx` and `429` are retried (twice by default) with backoff; a
  `Retry-After` longer than five seconds is not waited for.
- Errors: every failure is a `BeckLinksException` with a `code` (`network`, `invalid_key`,
  `rate_limited`, `invalid_request`, `server`, ...), the API's own `apiCode` and the request ID.

MIT licensed.
