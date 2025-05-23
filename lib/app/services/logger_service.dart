import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// A centralized logging service for the application.
///
/// This service provides methods for different log levels and ensures
/// that logs are only shown in debug mode when appropriate.
class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  /// Log a verbose message (development only)
  static void verbose(String message) {
    if (kDebugMode) {
      _logger.t(message);
    }
  }

  /// Log a debug message (development only)
  static void debug(String message) {
    if (kDebugMode) {
      _logger.d(message);
    }
  }

  /// Log an info message
  static void info(String message) {
    _logger.i(message);
  }

  /// Log a warning message
  static void warning(String message) {
    _logger.w(message);
  }

  /// Log an error message with optional error object and stack trace
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a critical error (development only)
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.f(message, error: error, stackTrace: stackTrace);
    }
  }
}
