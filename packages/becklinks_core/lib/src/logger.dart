import 'package:flutter/foundation.dart';

/// How much a Beck Links package writes to the console.
enum LogLevel {
  /// Nothing.
  none,

  /// Failures only.
  error,

  /// Failures and notable events.
  info,

  /// Everything, including each request.
  debug,
}

/// Writes lines prefixed with the package name. Never logs keys, bodies or user data.
class BeckLinksLogger {
  /// Creates a logger for [tag] (the package name, shown in brackets).
  const BeckLinksLogger(
      {required this.tag, this.level = LogLevel.error, this.sink});

  /// The prefix of every line, for example `BeckLinks`.
  final String tag;

  /// Lines above this level are dropped.
  final LogLevel level;

  /// Where lines go; `debugPrint` when null. Tests pass their own.
  final void Function(String line)? sink;

  /// Logs a failure.
  void error(String message) => _write(LogLevel.error, 'ERROR', message);

  /// Logs a notable event.
  void info(String message) => _write(LogLevel.info, 'INFO', message);

  /// Logs detail for debugging.
  void debug(String message) => _write(LogLevel.debug, 'DEBUG', message);

  void _write(LogLevel at, String label, String message) {
    if (level.index < at.index) return;
    final line = '[$tag] $label: $message';
    (sink ?? debugPrint)(line);
  }
}
