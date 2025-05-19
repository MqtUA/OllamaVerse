import 'package:logging/logging.dart';

/// A utility class for logging
class AppLogger {
  static final Logger _logger = Logger('OllamaVerse');
  static bool _initialized = false;

  /// Initialize the logger
  static void init() {
    if (_initialized) return;
    
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
    
    _initialized = true;
  }

  /// Log an info message
  static void info(String message) {
    _logger.info(message);
  }

  /// Log a warning message
  static void warning(String message) {
    _logger.warning(message);
  }

  /// Log an error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  /// Log a debug message
  static void debug(String message) {
    _logger.fine(message);
  }
}
