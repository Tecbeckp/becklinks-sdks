import 'dart:convert';

import 'package:becklinks_core/becklinks_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'sdk_info.dart';
import 'update_cache.dart';
import 'update_check_result.dart';

/// Asks Beck Links whether the running version of the app is current, outdated or too old.
///
/// ```dart
/// final forceUpdate = BeckLinksForceUpdate(apiKey: 'pk_live_YOUR_KEY');
/// final result = await forceUpdate.check();
/// if (result.isRequired) { /* block the app and open result.storeUrl */ }
/// ```
///
/// [check] never throws: when the answer cannot be had, the app is told `ok`, except that an
/// "update required" seen on an earlier launch of the same version is remembered. A check that
/// fails must not lock people out of an app that is fine.
class BeckLinksForceUpdate {
  /// Creates the checker. Throws [BeckLinksException] for a secret or malformed key.
  ///
  /// [apiUrl], [appVersion], [platform], [cache] and [httpClient] exist for tests and for
  /// self-hosted setups; apps leave them out.
  BeckLinksForceUpdate({
    required String apiKey,
    Uri? apiUrl,
    LogLevel logLevel = LogLevel.error,
    BeckLinksApiClient? client,
    Future<String> Function()? appVersion,
    TargetPlatform? platform,
    UpdateCache? cache,
  })  : _client = client ??
            BeckLinksApiClient(
              apiKey: apiKey,
              baseUrl: apiUrl,
              sdkName: sdkName,
              sdkVersion: sdkVersion,
              logger:
                  BeckLinksLogger(tag: 'BeckLinksForceUpdate', level: logLevel),
            ),
        _logger = BeckLinksLogger(tag: 'BeckLinksForceUpdate', level: logLevel),
        _appVersion = appVersion ?? _installedVersion,
        _platform = platform,
        _cache = cache ?? const SharedPreferencesUpdateCache();

  final BeckLinksApiClient _client;
  final BeckLinksLogger _logger;
  final Future<String> Function() _appVersion;
  final TargetPlatform? _platform;
  final UpdateCache _cache;

  static Future<String> _installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Checks the running version against the policy of the project environment.
  Future<UpdateCheckResult> check() async {
    final platform = switch (_platform ?? defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    // Only Android and iOS have a policy; anywhere else (tests on desktop) there is nothing to ask.
    if (platform == null) return const UpdateCheckResult.ok();

    final String version;
    try {
      version = await _appVersion();
    } on Object catch (error) {
      _logger.error('Could not read the version of the app: $error');
      return const UpdateCheckResult.ok();
    }

    try {
      final json =
          await _client.postJson('/v1/sdk/app-version', <String, Object?>{
        'platform': platform,
        'app_version': version,
      });
      final result = UpdateCheckResult.fromJson(json);
      await _remember(version, result);
      return result;
    } on BeckLinksException catch (error) {
      _logger.error('Version check failed: $error');
      return await _lastRequired(version) ?? const UpdateCheckResult.ok();
    }
  }

  Future<void> _remember(String version, UpdateCheckResult result) async {
    try {
      if (result.isRequired) {
        await _cache.write(jsonEncode(<String, Object?>{
          'app_version': version,
          'result': result.toJson(),
        }));
      } else {
        // The policy is lifted or the app was updated: stop remembering.
        await _cache.clear();
      }
    } on Object catch (error) {
      _logger.error('Could not store the answer: $error');
    }
  }

  Future<UpdateCheckResult?> _lastRequired(String version) async {
    try {
      final stored = await _cache.read();
      if (stored == null) return null;
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, Object?> ||
          decoded['app_version'] != version) {
        return null;
      }
      final result = decoded['result'];
      if (result is! Map<String, Object?>) return null;
      final parsed = UpdateCheckResult.fromJson(result, fromCache: true);
      return parsed.isRequired ? parsed : null;
    } on Object catch (error) {
      _logger.error('Could not read the stored answer: $error');
      return null;
    }
  }

  /// Releases the network client.
  void dispose() => _client.close();
}
