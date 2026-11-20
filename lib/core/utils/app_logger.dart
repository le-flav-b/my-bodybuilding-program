import 'dart:developer' as developer;

/// Minimal logger (no `print` in the app).
abstract final class AppLogger {
  static void info(String message, {String name = 'app'}) =>
      developer.log(message, name: name);

  static void warning(String message, {String name = 'app', Object? error}) =>
      developer.log(message, name: name, level: 900, error: error);

  static void error(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) => developer.log(
    message,
    name: name,
    level: 1000,
    error: error,
    stackTrace: stackTrace,
  );
}
