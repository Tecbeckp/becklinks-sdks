import 'package:becklinks_rating/becklinks_rating.dart';
import 'package:flutter/material.dart';

/// Replace with the publishable key (pk_test_... or pk_live_...) of your Beck Links project:
/// `flutter run --dart-define=BECKLINKS_KEY=pk_test_yourkey` or edit the default.
const String apiKey = String.fromEnvironment(
  'BECKLINKS_KEY',
  defaultValue: 'pk_test_replaceWithYourKey',
);

final BeckLinksRating rating = BeckLinksRating(apiKey: apiKey);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Counts one open (a second call within 30 minutes is ignored).
  await rating.recordSession();
  runApp(const ExampleApp());
}

/// A one-screen app that asks for a review after something good happened.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Rating prompt example',
      home: OrderScreen(),
    );
  }
}

/// Pretends to place an order and then lets the package decide whether to ask for a review.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String _status = 'Place an order to see the review prompt logic.';

  Future<void> _placeOrder() async {
    // Your own success logic goes here; then, at a calm moment:
    final asked = await rating.maybeRequestReview();
    // check() says why it would not ask, without asking.
    final reason = asked ? null : await rating.check();
    if (!mounted) return;
    setState(() {
      _status = asked
          ? 'The system review dialog was requested.'
          : 'Not asking yet: ${reason?.name}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rating prompt example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _placeOrder,
              child: const Text('Place order'),
            ),
          ],
        ),
      ),
    );
  }
}
