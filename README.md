# Beck Links Flutter packages

Flutter packages of [Beck Links](https://becklinks.com) beyond deep linking. Each is published to
pub.dev on its own and can be installed alone.

| Package                                              | What it does                                                                | Depends on        |
| ---------------------------------------------------- | --------------------------------------------------------------------------- | ----------------- |
| [`becklinks_core`](packages/becklinks_core)          | Shared base: API key checks, network with retries, errors, logging          | -                 |
| [`becklinks_force_update`](packages/becklinks_force_update) | Ask whether the running app version is too old; required or optional update | `becklinks_core`  |
| [`becklinks_rating`](packages/becklinks_rating) | Ask for a store review at the right moment; thresholds from the dashboard, rules on the device | `becklinks_core` |

Deep linking, deferred deep linking and install attribution stay in their own package,
[`becklinks_flutter`](https://github.com/Tecbeckp/becklinks-flutter).

## Working here

A pub workspace: one `flutter pub get` at the root resolves all packages against each other.

```sh
flutter pub get
cd packages/becklinks_core && flutter analyze && flutter test
cd ../becklinks_force_update && flutter analyze && flutter test
cd ../becklinks_rating && flutter analyze && flutter test
```

Release order: `becklinks_core` first, then the packages that depend on it (pub.dev must know the
core version before it accepts them). Each package has its own version and its own tag, for example
`becklinks_core-v0.1.0`.

MIT licensed.
