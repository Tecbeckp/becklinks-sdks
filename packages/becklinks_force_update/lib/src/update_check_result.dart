import 'package:meta/meta.dart';

/// What the version check says about the running app.
enum UpdateStatus {
  /// Nothing to do.
  ok('ok'),

  /// A newer version exists; offering it is up to the app.
  updateAvailable('update_available'),

  /// The running version is below the minimum and must update.
  updateRequired('update_required');

  const UpdateStatus(this.wireValue);

  /// The value of `status` in the API's answer.
  final String wireValue;

  /// The status of an API value; anything unknown is [ok], so a newer server never blocks an
  /// older package.
  static UpdateStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return ok;
  }
}

/// The answer of a version check.
@immutable
class UpdateCheckResult {
  /// Creates a result.
  const UpdateCheckResult({
    required this.status,
    this.minimumVersion,
    this.latestVersion,
    this.storeUrl,
    this.title,
    this.message,
    this.fromCache = false,
  });

  /// A result that asks for nothing.
  const UpdateCheckResult.ok() : this(status: UpdateStatus.ok);

  /// Reads the API's answer; missing or malformed fields read as not set.
  factory UpdateCheckResult.fromJson(Map<String, Object?> json,
      {bool fromCache = false}) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final status = UpdateStatus.fromWire(json['status']);
    final storeUrl = text('store_url');
    // An update with no place to go cannot be acted on: treat it as nothing to do.
    if (status != UpdateStatus.ok && !_isHttps(storeUrl)) {
      return UpdateCheckResult(
        status: UpdateStatus.ok,
        minimumVersion: text('minimum_version'),
        latestVersion: text('latest_version'),
        fromCache: fromCache,
      );
    }
    return UpdateCheckResult(
      status: status,
      minimumVersion: text('minimum_version'),
      latestVersion: text('latest_version'),
      storeUrl: storeUrl,
      title: text('title'),
      message: text('message'),
      fromCache: fromCache,
    );
  }

  static bool _isHttps(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// The verdict.
  final UpdateStatus status;

  /// The oldest version still allowed on this platform, when set.
  final String? minimumVersion;

  /// The newest version, when set.
  final String? latestVersion;

  /// The store page to send people to (https); null when [status] is [UpdateStatus.ok].
  final String? storeUrl;

  /// A title written by the project owner, when there is one.
  final String? title;

  /// A message written by the project owner, when there is one.
  final String? message;

  /// True when this is the stored answer of an earlier launch, because the network failed.
  final bool fromCache;

  /// The app must update before it is used.
  bool get isRequired => status == UpdateStatus.updateRequired;

  /// A newer version may be offered.
  bool get isAvailable => status == UpdateStatus.updateAvailable;

  /// The form kept between launches.
  Map<String, Object?> toJson() => <String, Object?>{
        'status': status.wireValue,
        'minimum_version': minimumVersion,
        'latest_version': latestVersion,
        'store_url': storeUrl,
        'title': title,
        'message': message,
      };

  @override
  bool operator ==(Object other) =>
      other is UpdateCheckResult &&
      other.status == status &&
      other.minimumVersion == minimumVersion &&
      other.latestVersion == latestVersion &&
      other.storeUrl == storeUrl &&
      other.title == title &&
      other.message == message &&
      other.fromCache == fromCache;

  @override
  int get hashCode => Object.hash(status, minimumVersion, latestVersion,
      storeUrl, title, message, fromCache);

  @override
  String toString() => 'UpdateCheckResult(${status.wireValue}'
      '${fromCache ? ', from cache' : ''})';
}
