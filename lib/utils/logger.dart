import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// A utility class for logging
class AppLogger {
  static final Logger _logger = Logger('OllamaVerse');
  static bool _initialized = false;
  static File? _logFile;
  static const int _maxLogFiles = 5;
  static const int _maxLogSize = 5 * 1024 * 1024; // 5MB

  /// Initialize the logger
  static Future<void> init() async {
    if (_initialized) return;

    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen(_handleLogRecord);

    await _setupLogFile();
    _initialized = true;
  }

  /// Handle log record
  static void _handleLogRecord(LogRecord record) {
    final message = '${record.level.name}: ${record.time}: ${record.message}';
    // ignore: avoid_print
    print(message);
    _writeToLogFile(message);
  }

  /// Setup log file
  static Future<void> _setupLogFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${appDir.path}/logs');

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      _logFile = File('${logsDir.path}/app.log');
      await _rotateLogsIfNeeded();
    } catch (e) {
      AppLogger.error('Error setting up log file', e);
    }
  }

  /// Rotate logs if needed
  static Future<void> _rotateLogsIfNeeded() async {
    if (_logFile == null) return;

    try {
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size >= _maxLogSize) {
          final appDir = await getApplicationDocumentsDirectory();
          final logsDir = Directory('${appDir.path}/logs');

          // Rename current log file to app.1.log
          await _logFile!.rename('${logsDir.path}/app.1.log');

          // Shift existing numbered logs
          for (var i = _maxLogFiles - 1; i >= 1; i--) {
            final oldFile = File('${logsDir.path}/app.$i.log');
            final newFile = File('${logsDir.path}/app.${i + 1}.log');
            if (await oldFile.exists()) {
              if (i + 1 > _maxLogFiles) {
                await oldFile.delete(); // Delete if it exceeds max files
              } else {
                await oldFile.rename(newFile.path);
              }
            }
          }

          _logFile = File('${logsDir.path}/app.log');
        }
      }
    } catch (e) {
      AppLogger.error('Error rotating logs', e);
    }
  }

  /// Write to log file
  static Future<void> _writeToLogFile(String message) async {
    if (_logFile == null) return;

    try {
      await _rotateLogsIfNeeded();
      await _logFile!.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      AppLogger.error('Error writing to log file', e);
    }
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

  /// Get total size of all log files
  static Future<int> getLogsSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${appDir.path}/logs');

      if (!await logsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final file in logsDir.list()) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      AppLogger.error('Error getting logs size', e);
      return 0;
    }
  }

  /// Clear all log files
  static Future<void> clearLogs() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${appDir.path}/logs');

      if (await logsDir.exists()) {
        await logsDir.delete(recursive: true);
        await logsDir.create();
        _logFile = File('${logsDir.path}/app.log');
      }
    } catch (e) {
      AppLogger.error('Error clearing logs', e);
    }
  }
}
