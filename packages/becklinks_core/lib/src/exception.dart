import 'package:meta/meta.dart';

/// Why a Beck Links call failed, in terms an app can branch on.
enum BeckLinksErrorCode {
  /// The key or an option was given wrongly (a secret key, a malformed key, a bad URL).
  invalidConfiguration('invalid_configuration'),

  /// The request did not reach the API (offline, DNS, TLS) or no answer came in time.
  network('network'),

  /// The API refused the key (unknown, revoked or of the wrong kind).
  invalidKey('invalid_key'),

  /// Too many requests; see [BeckLinksException.retryAfter].
  rateLimited('rate_limited'),

  /// The API refused the request itself (a field is wrong).
  invalidRequest('invalid_request'),

  /// The API failed (a 5xx answer).
  server('server'),

  /// The API answered with something this package does not understand.
  unexpectedResponse('unexpected_response');

  const BeckLinksErrorCode(this.wireValue);

  /// A stable lower-case name for logs and analytics.
  final String wireValue;
}

/// The one exception of the Beck Links packages.
@immutable
class BeckLinksException implements Exception {
  /// Creates an exception; packages build these, apps only catch them.
  const BeckLinksException(
    this.code,
    this.message, {
    this.statusCode,
    this.apiCode,
    this.requestId,
    this.retryAfter,
  });

  /// What kind of failure this is.
  final BeckLinksErrorCode code;

  /// A sentence for the developer, with the fix when there is one.
  final String message;

  /// The HTTP status of the answer, when there was one.
  final int? statusCode;

  /// The stable `code` of the API's problem body (for example `origin_not_allowed`).
  final String? apiCode;

  /// The request ID of the answer, for support.
  final String? requestId;

  /// How long the API asked to wait, when it did.
  final Duration? retryAfter;

  /// Whether trying the same call later can work.
  bool get isRetryable =>
      code == BeckLinksErrorCode.network ||
      code == BeckLinksErrorCode.rateLimited ||
      code == BeckLinksErrorCode.server;

  @override
  String toString() =>
      'BeckLinksException(${code.wireValue}${statusCode == null ? '' : ', $statusCode'}): $message';
}
