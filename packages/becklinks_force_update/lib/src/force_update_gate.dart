import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'force_update.dart';
import 'update_check_result.dart';

/// The words of the built-in screens. Replace them to translate the package.
@immutable
class ForceUpdateTexts {
  /// Creates a set of texts; every one has an English default.
  const ForceUpdateTexts({
    this.requiredTitle = 'Update required',
    this.requiredMessage = 'This version of the app is no longer supported. '
        'Please update to keep using it.',
    this.availableTitle = 'Update available',
    this.availableMessage = 'A new version of the app is ready.',
    this.updateButton = 'Update',
    this.laterButton = 'Later',
  });

  /// Heading of the blocking screen when the owner wrote no title.
  final String requiredTitle;

  /// Text of the blocking screen when the owner wrote no message.
  final String requiredMessage;

  /// Heading of the offer when the owner wrote no title.
  final String availableTitle;

  /// Text of the offer when the owner wrote no message.
  final String availableMessage;

  /// The button that opens the store.
  final String updateButton;

  /// The button that closes the offer.
  final String laterButton;
}

/// Shows the update screens above [child]: a screen that cannot be left when an update is required,
/// and a dismissible offer when one is available.
///
/// Put it above the navigator so it covers every screen, for example in `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => ForceUpdateGate(
///     forceUpdate: forceUpdate,
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
/// ```
///
/// It checks when it first appears and again each time the app returns to the foreground. To draw
/// your own screens, pass [requiredBuilder] and [availableBuilder]; the check itself does not
/// depend on this widget (`forceUpdate.check()`).
class ForceUpdateGate extends StatefulWidget {
  /// Creates the gate.
  const ForceUpdateGate({
    required this.forceUpdate,
    required this.child,
    this.texts = const ForceUpdateTexts(),
    this.requiredBuilder,
    this.availableBuilder,
    this.openStore,
    this.minimumRecheckInterval = const Duration(minutes: 1),
    super.key,
  });

  /// The checker, created once by the app.
  final BeckLinksForceUpdate forceUpdate;

  /// The app.
  final Widget child;

  /// The words of the built-in screens.
  final ForceUpdateTexts texts;

  /// Replaces the blocking screen. [openStore] opens the store page of the result.
  final Widget Function(BuildContext context, UpdateCheckResult result,
      VoidCallback openStore)? requiredBuilder;

  /// Replaces the offer. [dismiss] hides it until the next launch or the next newer version.
  final Widget Function(
    BuildContext context,
    UpdateCheckResult result,
    VoidCallback openStore,
    VoidCallback dismiss,
  )? availableBuilder;

  /// Opens a store URL; defaults to the system browser or store app. For tests.
  final Future<void> Function(Uri url)? openStore;

  /// Foreground returns closer together than this do not check again.
  final Duration minimumRecheckInterval;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate>
    with WidgetsBindingObserver {
  UpdateCheckResult _result = const UpdateCheckResult.ok();
  String? _dismissedFor;
  DateTime? _checkedAt;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _checkedAt;
    if (last != null &&
        DateTime.now().difference(last) < widget.minimumRecheckInterval) {
      return;
    }
    _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final result = await widget.forceUpdate.check();
      _checkedAt = DateTime.now();
      if (mounted) setState(() => _result = result);
    } finally {
      _checking = false;
    }
  }

  void _open() {
    final url = _result.storeUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    final opener = widget.openStore ??
        (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    opener(uri);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    Widget? overlay;
    if (result.isRequired) {
      overlay = widget.requiredBuilder?.call(context, result, _open) ??
          _RequiredScreen(result: result, texts: widget.texts, onUpdate: _open);
    } else if (result.isAvailable && _dismissedFor != result.latestVersion) {
      void dismiss() => setState(() => _dismissedFor = result.latestVersion);
      overlay =
          widget.availableBuilder?.call(context, result, _open, dismiss) ??
              _AvailableOffer(
                  result: result,
                  texts: widget.texts,
                  onUpdate: _open,
                  onLater: dismiss);
    }
    return Stack(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        Positioned.fill(child: widget.child),
        if (result.isRequired)
          // The app underneath stays alive but cannot be reached.
          const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Colors.black54)),
        if (overlay != null) Positioned.fill(child: overlay),
      ],
    );
  }
}

class _RequiredScreen extends StatelessWidget {
  const _RequiredScreen(
      {required this.result, required this.texts, required this.onUpdate});

  final UpdateCheckResult result;
  final ForceUpdateTexts texts;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        result.title ?? texts.requiredTitle,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result.message ?? texts.requiredMessage,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: onUpdate, child: Text(texts.updateButton)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailableOffer extends StatelessWidget {
  const _AvailableOffer({
    required this.result,
    required this.texts,
    required this.onUpdate,
    required this.onLater,
  });

  final UpdateCheckResult result;
  final ForceUpdateTexts texts;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(result.title ?? texts.availableTitle,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(result.message ?? texts.availableMessage,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                          onPressed: onLater, child: Text(texts.laterButton)),
                      const SizedBox(width: 8),
                      FilledButton(
                          onPressed: onUpdate, child: Text(texts.updateButton)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
