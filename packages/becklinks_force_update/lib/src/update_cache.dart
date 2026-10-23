import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last "update required" answer between launches, so an app that starts without a
/// network does not forget that it must update. Holds one string; the package decides what it is.
abstract class UpdateCache {
  /// Base constructor, so a cache can be written as a `const` class.
  const UpdateCache();

  /// The stored string, or null.
  Future<String?> read();

  /// Replaces the stored string.
  Future<void> write(String value);

  /// Removes it.
  Future<void> clear();
}

/// The default: `shared_preferences`, under one key.
class SharedPreferencesUpdateCache implements UpdateCache {
  /// Creates the cache; [key] only changes when two checks must not share a value.
  const SharedPreferencesUpdateCache(
      {this.key = 'becklinks_force_update.last_required'});

  /// The preferences key.
  final String key;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

/// A cache that lives only as long as the process; for tests and apps without storage.
class MemoryUpdateCache implements UpdateCache {
  /// Creates an empty cache.
  MemoryUpdateCache();

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> clear() async => _value = null;
}
