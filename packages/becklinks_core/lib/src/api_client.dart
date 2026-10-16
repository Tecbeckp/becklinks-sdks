import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_key.dart';
import 'exception.dart';
import 'logger.dart';

/// The production API.
final Uri productionApiUrl = Uri.parse('https://api.becklinks.com');

const Duration _maxRetryWait = Duration(seconds: 5);
const Duration _baseBackoff = Duration(milliseconds: 400);

/// Sends JSON to the Beck Links SDK API with the publishable key and the SDK headers
/// (`X-SDK-Name`, `X-SDK-Version`), retries what is safe to retry and turns every failure into a
/// [BeckLinksException].
class BeckLinksApiClient {
  /// Creates a client. Throws [BeckLinksException] for a bad key or API URL.
  BeckLinksApiClient({
    required String apiKey,
    required this.sdkName,
    required this.sdkVersion,
    Uri? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 2,
    this.logger = const BeckLinksLogger(tag: 'BeckLinks'),
    Future<void> Function(Duration)? sleep,
    Random? random,
  })  : _apiKey = validatePublishableKey(apiKey),
        _baseUrl = _checkedBaseUrl(baseUrl ?? productionApiUrl),
        _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _sleep = sleep ?? Future<void>.delayed,
        _random = random ?? Random();

  /// The package name sent as `X-SDK-Name` (lower case letters, digits and underscores).
  final String sdkName;

  /// The package version sent as `X-SDK-Version` (SemVer).
  final String sdkVersion;

  /// How long one attempt may take.
  final Duration timeout;

  /// How often a retryable failure is retried (so at most `maxRetries + 1` attempts).
  final int maxRetries;

  /// Where the client writes what it does.
  final BeckLinksLogger logger;

  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final Future<void> Function(Duration) _sleep;
  final Random _random;

  static Uri _checkedBaseUrl(Uri url) {
    final local = url.host == 'localhost' ||
        url.host == '127.0.0.1' ||
        url.host.endsWith('.localhost');
    if (url.scheme != 'https' && !(url.scheme == 'http' && local)) {
      throw const BeckLinksException(
        BeckLinksErrorCode.invalidConfiguration,
        'The API URL must be https (http is accepted for localhost only).',
      );
    }
    return url;
  }

  /// Posts [body] to [path] (for example `/v1/sdk/app-version`) and returns the JSON object of the
  /// answer. [idempotencyKey] is sent when given and stays the same on every retry.
  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
  }) async {
    for (var attempt = 0;; attempt += 1) {
      try {
        return await _attempt(path, body, idempotencyKey);
      } on BeckLinksException catch (error) {
        final wait = _waitBeforeRetry(error, attempt);
        if (!error.isRetryable || attempt >= maxRetries || wait == null) {
          rethrow;
        }
        logger.debug(
            'Retrying $path in ${wait.inMilliseconds} ms after: ${error.message}');
        await _sleep(wait);
      }
    }
  }

  Duration? _waitBeforeRetry(BeckLinksException error, int attempt) {
    final asked = error.retryAfter;
    // A server that asks for a long wait is better obeyed by the app than by a pending future.
    if (asked != null && asked > _maxRetryWait) return null;
    final backoff = _baseBackoff * pow(2, attempt).toInt();
    final jittered = backoff * (0.5 + _random.nextDouble() / 2);
    final wait = asked != null && asked > jittered ? asked : jittered;
    return wait > _maxRetryWait ? _maxRetryWait : wait;
  }

  Future<Map<String, Object?>> _attempt(
    String path,
    Map<String, Object?> body,
    String? idempotencyKey,
  ) async {
    final url = _baseUrl.replace(
        path: '${_baseUrl.path.replaceAll(RegExp(r'/+$'), '')}$path');
    final http.Response response;
    try {
      response = await _client
          .post(
            url,
            headers: <String, String>{
              'authorization': 'Bearer $_apiKey',
              'content-type': 'application/json',
              'x-sdk-name': sdkName,
              'x-sdk-version': sdkVersion,
              if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw BeckLinksException(
        BeckLinksErrorCode.network,
        'No answer from Beck Links within ${timeout.inSeconds} seconds.',
      );
    } on http.ClientException catch (error) {
      throw BeckLinksException(
        BeckLinksErrorCode.network,
        'The request did not reach Beck Links: ${error.message}',
      );
    } on Object catch (error) {
      // SocketException, HandshakeException and friends, without importing dart:io (web-safe).
      throw BeckLinksException(
        BeckLinksErrorCode.network,
        'The request did not reach Beck Links: $error',
      );
    }
    logger.debug('POST $path -> ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _readObject(response);
    }
    throw _errorFor(response);
  }

  Map<String, Object?> _readObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Falls through to the exception below.
    }
    throw BeckLinksException(
      BeckLinksErrorCode.unexpectedResponse,
      'Beck Links answered with a body that is not a JSON object.',
      statusCode: response.statusCode,
      requestId: response.headers['x-request-id'],
    );
  }

  BeckLinksException _errorFor(http.Response response) {
    String? apiCode;
    String? detail;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) {
        final code = decoded['code'];
        final text = decoded['detail'] ?? decoded['title'];
        apiCode = code is String ? code : null;
        detail = text is String ? text : null;
      }
    } on FormatException {
      // A proxy page, not a problem body: the status says enough.
    }
    final status = response.statusCode;
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    final code = switch (status) {
      401 || 403 => BeckLinksErrorCode.invalidKey,
      429 => BeckLinksErrorCode.rateLimited,
      >= 500 => BeckLinksErrorCode.server,
      >= 400 => BeckLinksErrorCode.invalidRequest,
      _ => BeckLinksErrorCode.unexpectedResponse,
    };
    return BeckLinksException(
      code,
      detail ?? 'Beck Links answered $status.',
      statusCode: status,
      apiCode: apiCode,
      requestId: response.headers['x-request-id'],
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  /// Closes the HTTP client when this object created it.
  void close() {
    if (_ownsClient) _client.close();
  }
}
