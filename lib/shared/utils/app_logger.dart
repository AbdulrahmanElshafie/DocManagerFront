import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static void log(String message, {
    LogLevel level = LogLevel.info,
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      level: _getLevelValue(level),
      name: name ?? 'App',
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  static int _getLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return 500;
      case LogLevel.info: return 800;
      case LogLevel.warning: return 900;
      case LogLevel.error: return 1000;
    }
  }
  
  static void debug(String message, {String? name}) =>
      log(message, level: LogLevel.debug, name: name);
  
  static void info(String message, {String? name}) =>
      log(message, level: LogLevel.info, name: name);
  
  static void warning(String message, {String? name}) =>
      log(message, level: LogLevel.warning, name: name);
  
  static void error(String message, {String? name, Object? error, StackTrace? stackTrace}) =>
      log(message, level: LogLevel.error, name: name, error: error, stackTrace: stackTrace);
} 