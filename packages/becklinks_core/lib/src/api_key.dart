import 'exception.dart';

final RegExp _publishableKey = RegExp(r'^pk_(test|live)_[A-Za-z0-9]{8,}$');

/// Checks a publishable key (`pk_test_...` or `pk_live_...`) and returns it.
///
/// A secret key (`sk_...`) is refused with a message that says what to do: a key shipped inside an
/// app is exposed, so it must be revoked.
String validatePublishableKey(String key) {
  if (key.isEmpty) {
    throw const BeckLinksException(
      BeckLinksErrorCode.invalidConfiguration,
      'The API key is empty. Copy the publishable key (pk_test_... or pk_live_...) from the '
      'Beck Links dashboard under API keys.',
    );
  }
  if (key.startsWith('sk_')) {
    throw const BeckLinksException(
      BeckLinksErrorCode.invalidConfiguration,
      'This is a secret key (sk_...). Secret keys must never be in an app: revoke it in the '
      'dashboard and use the publishable key (pk_...).',
    );
  }
  if (!_publishableKey.hasMatch(key)) {
    throw const BeckLinksException(
      BeckLinksErrorCode.invalidConfiguration,
      'The API key must look like pk_test_... or pk_live_....',
    );
  }
  return key;
}

/// Whether [key] is a test key (`pk_test_...`).
bool isTestKey(String key) => key.startsWith('pk_test_');
