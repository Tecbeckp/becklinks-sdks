import 'package:becklinks_force_update/becklinks_force_update.dart';
import 'package:flutter/material.dart';

/// Replace with the publishable key (pk_test_... or pk_live_...) of your Beck Links project:
/// `flutter run --dart-define=BECKLINKS_KEY=pk_test_yourkey` or edit the default.
const String apiKey = String.fromEnvironment(
  'BECKLINKS_KEY',
  defaultValue: 'pk_test_replaceWithYourKey',
);

final BeckLinksForceUpdate forceUpdate = BeckLinksForceUpdate(apiKey: apiKey);

void main() => runApp(const ExampleApp());

/// An app with the update gate above its navigator, so the "update required" screen covers
/// everything and cannot be left.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Force update example',
      builder: (context, child) => ForceUpdateGate(
        forceUpdate: forceUpdate,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}

/// The app's own screen: below the minimum version it is not reachable, below the latest version
/// it is shown with a dismissible offer on top.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Force update example')),
      body: const Center(child: Text('Your app is up to date enough to run.')),
    );
  }
}
