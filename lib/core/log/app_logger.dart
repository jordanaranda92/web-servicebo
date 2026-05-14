import 'dart:developer' as developer;

import 'log_level.dart';

class AppLogger {
  AppLogger({required bool enabled, LogLevel minLevel = LogLevel.debug})
    : _enabled = enabled,
      _minLevel = minLevel;

  final bool _enabled;
  final LogLevel _minLevel;

  void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.debug, message, error, stackTrace);

  void info(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.info, message, error, stackTrace);

  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.warning, message, error, stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (!_enabled || level.index < _minLevel.index) return;

    final prefix = '[${level.name.toUpperCase()}]';
    final fullMessage = error != null
        ? '$prefix $message — $error'
        : '$prefix $message';

    developer.log(
      fullMessage,
      name: 'App',
      level: level.index * 300,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
