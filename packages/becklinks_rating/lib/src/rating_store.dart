import 'package:shared_preferences/shared_preferences.dart';

/// Keeps two strings between launches: the device's counters and the last policy. The package
/// decides what they contain.
abstract class RatingStore {
  /// The stored string for [key], or null.
  Future<String?> read(String key);

  /// Replaces the stored string for [key].
  Future<void> write(String key, String value);
}

/// The default: `shared_preferences`.
class SharedPreferencesRatingStore implements RatingStore {
  /// Creates the store.
  const SharedPreferencesRatingStore();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance())
          .getString('becklinks_rating.$key');

  @override
  Future<void> write(String key, String value) async {
    await (await SharedPreferences.getInstance())
        .setString('becklinks_rating.$key', value);
  }
}

/// A store that lives only as long as the process; for tests.
class MemoryRatingStore implements RatingStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
