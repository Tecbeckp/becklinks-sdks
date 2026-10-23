import 'dart:convert';
import 'dart:io';

import 'package:becklinks_core/becklinks_core.dart';
import 'package:becklinks_force_update/becklinks_force_update.dart';
import 'package:becklinks_force_update/src/sdk_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _key = 'pk_test_AbCdEfGh12345678';
const String _store = 'https://apps.apple.com/app/id123456789';

BeckLinksForceUpdate _checker(Map<String, Object?> answer,
        {Future<void> Function()? onAsk}) =>
    BeckLinksForceUpdate(
      apiKey: _key,
      client: BeckLinksApiClient(
        apiKey: _key,
        sdkName: 'becklinks_force_update',
        sdkVersion: '0.1.1',
        maxRetries: 0,
        httpClient: MockClient((request) async {
          await onAsk?.call();
          return http.Response(jsonEncode(answer), 200,
              headers: {'content-type': 'application/json'});
        }),
      ),
      appVersion: () async => '1.0.0',
      platform: TargetPlatform.iOS,
      cache: MemoryUpdateCache(),
    );

Widget _app(
  BeckLinksForceUpdate checker, {
  List<Uri>? opened,
  ForceUpdateTexts texts = const ForceUpdateTexts(),
}) =>
    MaterialApp(
      builder: (context, child) => ForceUpdateGate(
        forceUpdate: checker,
        texts: texts,
        openStore: (url) async => opened?.add(url),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('The app')),
    );

const Map<String, Object?> _requiredAnswer = <String, Object?>{
  'status': 'update_required',
  'minimum_version': '2.0.0',
  'latest_version': '2.0.0',
  'store_url': _store,
  'title': 'Please update',
  'message': 'This version no longer works.',
};

void main() {
  testWidgets('shows only the app while the version is fine', (tester) async {
    await tester.pumpWidget(_app(_checker({'status': 'ok'})));
    await tester.pumpAndSettle();
    expect(find.text('The app'), findsOneWidget);
    expect(find.text('Update'), findsNothing);
  });

  testWidgets('covers the app with an update screen that opens the store',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_app(_checker(_requiredAnswer), opened: opened));
    await tester.pumpAndSettle();

    expect(find.text('Please update'), findsOneWidget);
    expect(find.text('This version no longer works.'), findsOneWidget);
    await tester.tap(find.text('Update'));
    expect(opened, [Uri.parse(_store)]);
  });

  testWidgets(
      'uses the built-in words when the owner wrote none, and can be translated',
      (tester) async {
    await tester.pumpWidget(_app(
      _checker({..._requiredAnswer, 'title': null, 'message': null}),
      texts: const ForceUpdateTexts(
        requiredTitle: 'Mise a jour requise',
        updateButton: 'Mettre a jour',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mise a jour requise'), findsOneWidget);
    expect(find.text('Mettre a jour'), findsOneWidget);
    expect(find.textContaining('no longer supported'), findsOneWidget);
  });

  testWidgets('the required screen cannot be dismissed with the back button',
      (tester) async {
    await tester.pumpWidget(_app(_checker(_requiredAnswer)));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Please update'), findsOneWidget);
  });

  testWidgets('offers an available update and lets the user say later',
      (tester) async {
    final opened = <Uri>[];
    final answer = {..._requiredAnswer, 'status': 'update_available'};
    await tester.pumpWidget(_app(_checker(answer), opened: opened));
    await tester.pumpAndSettle();

    expect(find.text('The app'), findsOneWidget);
    expect(find.text('Please update'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Please update'), findsNothing);
    expect(find.text('The app'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testWidgets('draws a custom screen when asked to', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ForceUpdateGate(
          forceUpdate: _checker(_requiredAnswer),
          openStore: (url) async {},
          requiredBuilder: (context, result, openStore) => Center(
              child: TextButton(
                  onPressed: openStore, child: const Text('Custom update'))),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Text('The app'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom update'), findsOneWidget);
  });

  testWidgets(
      'checks again when the app returns, but not more often than the interval',
      (tester) async {
    var asked = 0;
    await tester.pumpWidget(
        _app(_checker({'status': 'ok'}, onAsk: () async => asked += 1)));
    await tester.pumpAndSettle();
    expect(asked, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(asked, 1, reason: 'returned within a minute');
  });

  test('the version sent as X-SDK-Version is the version of pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version: (\S+)', multiLine: true).firstMatch(pubspec);
    expect(sdkVersion, match?.group(1));
  });
}
