// ignore_for_file: avoid_print
import 'package:becklinks_core/becklinks_core.dart';

/// Replace with the publishable key (pk_test_... or pk_live_...) of your Beck Links project:
/// `dart run example/lib/main.dart --define=BECKLINKS_KEY=pk_test_yourkey` or edit the default.
const String apiKey = String.fromEnvironment(
  'BECKLINKS_KEY',
  defaultValue: 'pk_test_replaceWithYourKey',
);

/// Calls the Beck Links SDK API the way the feature packages do: a checked key, retries with
/// backoff on network failures, 5xx and 429, and one exception type for every failure.
Future<void> main() async {
  final client = BeckLinksApiClient(
    apiKey: apiKey,
    sdkName: 'my_package',
    sdkVersion: '1.0.0',
  );
  try {
    final answer = await client.postJson('/v1/sdk/app-version', {
      'platform': 'ios',
      'app_version': '2.1.0',
    });
    print(answer);
  } on BeckLinksException catch (error) {
    print('${error.code}: ${error.message}');
  } finally {
    client.close();
  }
}
