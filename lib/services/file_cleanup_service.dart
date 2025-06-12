import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// A service for managing temporary file cleanup with advanced scheduling and error handling
class FileCleanupService {
  static FileCleanupService? _instance;
  static FileCleanupService get instance =>
      _instance ??= FileCleanupService._();

  FileCleanupService._();

  Timer? _periodicCleanupTimer;
  Timer? _monitoringTimer;
  StreamController<FileCleanupProgress>? _progressController;
  StreamController<FileSizeMonitoringData>? _monitoringController;
  bool _isCleanupRunning = false;
  bool _isMonitoring = false;
  late final FileCleanupConfig _config;

  // File size monitoring data
  final Map<String, DirectoryStats> _directoryStats = {};
  DateTime? _lastMonitoringUpdate;

  /// Initialize the cleanup service with enhanced monitoring
  Future<void> init({FileCleanupConfig? config}) async {
    _config = config ?? FileCleanupConfig.defaultConfig();
    _progressController = StreamController<FileCleanupProgress>.broadcast();
    _monitoringController =
        StreamController<FileSizeMonitoringData>.broadcast();

    // Start periodic cleanup and monitoring (now with conservative intervals)
    _startPeriodicCleanup();
    _startFileSizeMonitoring();

    AppLogger.info(
        'File cleanup service initialized - conservative cleanup intervals enabled');
  }

  /// Stream for cleanup progress updates
  Stream<FileCleanupProgress> get progressStream =>
      _progressController?.stream ?? const Stream.empty();

  /// Stream for file size monitoring updates
  Stream<FileSizeMonitoringData> get monitoringStream =>
      _monitoringController?.stream ?? const Stream.empty();

  /// Start periodic cleanup based on configuration
  void _startPeriodicCleanup() {
    _periodicCleanupTimer?.cancel();
    _periodicCleanupTimer = Timer.periodic(_config.cleanupInterval, (_) {
      _performSmartCleanup();
    });
  }

  /// Start file size monitoring for smart cleanup triggers
  void _startFileSizeMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(
      const Duration(hours: 2), // Monitor every 2 hours instead of 5 minutes
      (_) => _performFileSizeMonitoring(),
    );
  }

  /// Perform file size monitoring and trigger cleanup if needed
  Future<void> _performFileSizeMonitoring() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final monitoringData = FileSizeMonitoringData(
        timestamp: DateTime.now(),
        directories: {},
        needsCleanup: false,
        recommendations: [],
      );

      final directories = [
        ('attachments', '${appDir.path}/attachments', _config.maxDirectorySize),
        ('logs', '${appDir.path}/logs', _config.maxLogSize),
        ('cache', '${appDir.path}/cache', _config.maxCacheSize),
      ];

      bool needsCleanup = false;
      final recommendations = <String>[];

      for (final (name, path, maxSize) in directories) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final stats = await _getDirectoryStats(dir);
          monitoringData.directories[name] = stats;
          _directoryStats[name] = stats;

          // Check if cleanup is needed
          if (stats.totalSize > maxSize) {
            needsCleanup = true;
            recommendations.add(
              '$name directory (${_formatBytes(stats.totalSize)}) exceeds limit (${_formatBytes(maxSize)})',
            );
          }

          // Check growth rate
          final previousStats = _directoryStats[name];
          if (previousStats != null && _lastMonitoringUpdate != null) {
            final timeDiff = DateTime.now().difference(_lastMonitoringUpdate!);
            final sizeDiff = stats.totalSize - previousStats.totalSize;

            if (timeDiff.inMinutes > 0 && sizeDiff > 0) {
              final growthRate =
                  sizeDiff / timeDiff.inMinutes; // bytes per minute
              final projectedSize = stats.totalSize +
                  (growthRate * 60 * 24); // 24 hours projection

              if (projectedSize > maxSize * 0.8) {
                // 80% of max size
                recommendations.add(
                  '$name directory growing rapidly (${_formatBytes(sizeDiff)} in ${timeDiff.inMinutes}min)',
                );
              }
            }
          }
        }
      }

      final finalMonitoringData = FileSizeMonitoringData(
        timestamp: DateTime.now(),
        directories: monitoringData.directories,
        needsCleanup: needsCleanup,
        recommendations: recommendations,
      );
      _lastMonitoringUpdate = DateTime.now();

      _monitoringController?.add(finalMonitoringData);

      // Trigger automatic cleanup if needed
      if (needsCleanup && !_isCleanupRunning) {
        AppLogger.info('File size monitoring triggered automatic cleanup');
        await _performSmartCleanup();
      }
    } catch (e) {
      AppLogger.error('Error during file size monitoring', e);
    }
  }

  /// Get comprehensive directory statistics
  Future<DirectoryStats> _getDirectoryStats(Directory directory) async {
    int totalFiles = 0;
    int totalSize = 0;
    int oldFiles = 0; // Files older than configured age
    int largeFiles = 0; // Files larger than 10MB
    DateTime? oldestFile;
    DateTime? newestFile;
    final now = DateTime.now();

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          totalFiles++;
          totalSize += stat.size;

          // Track file ages
          if (oldestFile == null || stat.modified.isBefore(oldestFile)) {
            oldestFile = stat.modified;
          }
          if (newestFile == null || stat.modified.isAfter(newestFile)) {
            newestFile = stat.modified;
          }

          // Count old files based on directory type
          final maxAge = _getMaxAgeForDirectory(directory.path);
          if (now.difference(stat.modified) > maxAge) {
            oldFiles++;
          }

          // Count large files (>10MB)
          if (stat.size > 10 * 1024 * 1024) {
            largeFiles++;
          }
        } catch (e) {
          // Skip files that can't be accessed
          continue;
        }
      }
    }

    return DirectoryStats(
      totalFiles: totalFiles,
      totalSize: totalSize,
      oldFiles: oldFiles,
      largeFiles: largeFiles,
      oldestFile: oldestFile,
      newestFile: newestFile,
    );
  }

  /// Get maximum age configuration for a directory
  Duration _getMaxAgeForDirectory(String directoryPath) {
    if (directoryPath.contains('logs')) return _config.maxLogAge;
    if (directoryPath.contains('cache')) return _config.maxCacheAge;
    return _config.maxFileAge;
  }

  /// Perform smart cleanup based on usage patterns and file age
  Future<void> _performSmartCleanup() async {
    if (_isCleanupRunning) {
      AppLogger.debug('Cleanup already running, skipping');
      return;
    }

    _isCleanupRunning = true;

    try {
      final progress = FileCleanupProgress(
        phase: CleanupPhase.starting,
        totalFiles: 0,
        processedFiles: 0,
        deletedFiles: 0,
        totalSize: 0,
        freedSize: 0,
      );

      _progressController?.add(progress);

      // Run cleanup in isolate to avoid blocking UI
      final result = await _runCleanupInIsolate();

      final finalProgress = FileCleanupProgress(
        phase: CleanupPhase.completed,
        totalFiles: result.totalFiles,
        processedFiles: result.totalFiles,
        deletedFiles: result.deletedFiles,
        totalSize: result.totalSize,
        freedSize: result.freedSize,
      );

      _progressController?.add(finalProgress);

      AppLogger.info('Cleanup completed: ${result.deletedFiles} files deleted, '
          '${_formatBytes(result.freedSize)} freed');
    } catch (e) {
      AppLogger.error('Error during cleanup', e);
      _progressController?.add(FileCleanupProgress(
        phase: CleanupPhase.error,
        error: e.toString(),
      ));
    } finally {
      _isCleanupRunning = false;
    }
  }

  /// Run cleanup operation in isolate for better performance
  Future<CleanupResult> _runCleanupInIsolate() async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _cleanupIsolateEntryPoint,
      [receivePort.sendPort, _config],
    );

    final result = await receivePort.first as CleanupResult;
    return result;
  }

  /// Entry point for cleanup isolate
  static void _cleanupIsolateEntryPoint(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final config = args[1] as FileCleanupConfig;

    try {
      final result = await _performActualCleanup(config);
      sendPort.send(result);
    } catch (e) {
      sendPort.send(CleanupResult(
        totalFiles: 0,
        deletedFiles: 0,
        totalSize: 0,
        freedSize: 0,
        error: e.toString(),
      ));
    }
  }

  /// Perform the actual cleanup logic
  static Future<CleanupResult> _performActualCleanup(
      FileCleanupConfig config) async {
    final appDir = await getApplicationDocumentsDirectory();
    int totalFiles = 0;
    int deletedFiles = 0;
    int totalSize = 0;
    int freedSize = 0;

    // Clean attachments directory
    final attachmentsDir = Directory('${appDir.path}/attachments');
    if (await attachmentsDir.exists()) {
      final attachmentResult = await _cleanDirectory(
        attachmentsDir,
        config.maxFileAge,
        config.maxDirectorySize,
      );
      totalFiles += attachmentResult.totalFiles;
      deletedFiles += attachmentResult.deletedFiles;
      totalSize += attachmentResult.totalSize;
      freedSize += attachmentResult.freedSize;
    }

    // Clean logs directory
    final logsDir = Directory('${appDir.path}/logs');
    if (await logsDir.exists()) {
      final logResult = await _cleanDirectory(
        logsDir,
        config.maxLogAge,
        config.maxLogSize,
      );
      totalFiles += logResult.totalFiles;
      deletedFiles += logResult.deletedFiles;
      totalSize += logResult.totalSize;
      freedSize += logResult.freedSize;
    }

    // Clean cache directory
    final cacheDir = Directory('${appDir.path}/cache');
    if (await cacheDir.exists()) {
      final cacheResult = await _cleanDirectory(
        cacheDir,
        config.maxCacheAge,
        config.maxCacheSize,
      );
      totalFiles += cacheResult.totalFiles;
      deletedFiles += cacheResult.deletedFiles;
      totalSize += cacheResult.totalSize;
      freedSize += cacheResult.freedSize;
    }

    return CleanupResult(
      totalFiles: totalFiles,
      deletedFiles: deletedFiles,
      totalSize: totalSize,
      freedSize: freedSize,
    );
  }

  /// Clean a specific directory based on age and size constraints
  static Future<CleanupResult> _cleanDirectory(
    Directory directory,
    Duration maxAge,
    int maxSize,
  ) async {
    int totalFiles = 0;
    int deletedFiles = 0;
    int totalSize = 0;
    int freedSize = 0;

    final now = DateTime.now();
    final List<FileSystemEntity> files = [];

    // Collect all files with their info
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        totalFiles++;
        final stat = await entity.stat();
        totalSize += stat.size;
        files.add(entity);
      }
    }

    // Sort files by modification date (oldest first) for size-based cleanup
    files.sort((a, b) {
      return a.statSync().modified.compareTo(b.statSync().modified);
    });

    int currentSize = totalSize;

    for (final entity in files) {
      if (entity is File) {
        bool shouldDelete = false;
        final stat = await entity.stat();
        final age = now.difference(stat.modified);

        // Delete if too old
        if (age > maxAge) {
          shouldDelete = true;
        }
        // Delete if directory is too large (oldest files first)
        else if (currentSize > maxSize) {
          shouldDelete = true;
        }

        if (shouldDelete) {
          try {
            await entity.delete();
            deletedFiles++;
            freedSize += stat.size;
            currentSize -= stat.size;
          } catch (e) {
            // Continue with other files if one fails
          }
        }
      }
    }

    return CleanupResult(
      totalFiles: totalFiles,
      deletedFiles: deletedFiles,
      totalSize: totalSize,
      freedSize: freedSize,
    );
  }

  /// Force cleanup now (useful for manual trigger)
  Future<void> forceCleanup() async {
    await _performSmartCleanup();
  }

  /// Get cleanup statistics
  Future<CleanupStats> getCleanupStats() async {
    final appDir = await getApplicationDocumentsDirectory();
    int totalFiles = 0;
    int totalSize = 0;

    final dirs = [
      '${appDir.path}/attachments',
      '${appDir.path}/logs',
      '${appDir.path}/cache',
    ];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalFiles++;
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
    }

    return CleanupStats(
      totalFiles: totalFiles,
      totalSize: totalSize,
    );
  }

  /// Format bytes to human readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Stop the cleanup service
  void dispose() {
    _periodicCleanupTimer?.cancel();
    _monitoringTimer?.cancel();
    _progressController?.close();
    _monitoringController?.close();
    _isCleanupRunning = false;
    _isMonitoring = false;
    AppLogger.info('File cleanup service disposed');
  }
}

/// Configuration for file cleanup behavior
class FileCleanupConfig {
  final Duration cleanupInterval;
  final Duration maxFileAge;
  final Duration maxLogAge;
  final Duration maxCacheAge;
  final int maxDirectorySize; // in bytes
  final int maxLogSize; // in bytes
  final int maxCacheSize; // in bytes

  const FileCleanupConfig({
    required this.cleanupInterval,
    required this.maxFileAge,
    required this.maxLogAge,
    required this.maxCacheAge,
    required this.maxDirectorySize,
    required this.maxLogSize,
    required this.maxCacheSize,
  });

  factory FileCleanupConfig.defaultConfig() {
    return const FileCleanupConfig(
      cleanupInterval: Duration(days: 1), // Only check once per day
      maxFileAge: Duration(days: 30), // Keep files for 30 days (much longer)
      maxLogAge: Duration(days: 90), // Keep logs for 90 days
      maxCacheAge: Duration(days: 14), // Cache files expire after 2 weeks
      maxDirectorySize:
          500 * 1024 * 1024, // 500MB max for attachments (much higher)
      maxLogSize: 200 * 1024 * 1024, // 200MB max for logs
      maxCacheSize: 100 * 1024 * 1024, // 100MB max for cache
    );
  }
}

/// Progress information for cleanup operations
class FileCleanupProgress {
  final CleanupPhase phase;
  final int totalFiles;
  final int processedFiles;
  final int deletedFiles;
  final int totalSize;
  final int freedSize;
  final String? error;

  const FileCleanupProgress({
    required this.phase,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.deletedFiles = 0,
    this.totalSize = 0,
    this.freedSize = 0,
    this.error,
  });

  double get progress => totalFiles > 0 ? processedFiles / totalFiles : 0.0;
}

/// Cleanup phases
enum CleanupPhase {
  starting,
  scanning,
  cleaning,
  completed,
  error,
}

/// Result of cleanup operation
class CleanupResult {
  final int totalFiles;
  final int deletedFiles;
  final int totalSize;
  final int freedSize;
  final String? error;

  const CleanupResult({
    required this.totalFiles,
    required this.deletedFiles,
    required this.totalSize,
    required this.freedSize,
    this.error,
  });
}

/// Statistics about cleanup-able files
class CleanupStats {
  final int totalFiles;
  final int totalSize;

  const CleanupStats({
    required this.totalFiles,
    required this.totalSize,
  });
}

/// Comprehensive directory statistics for monitoring
class DirectoryStats {
  final int totalFiles;
  final int totalSize;
  final int oldFiles;
  final int largeFiles;
  final DateTime? oldestFile;
  final DateTime? newestFile;

  const DirectoryStats({
    required this.totalFiles,
    required this.totalSize,
    required this.oldFiles,
    required this.largeFiles,
    this.oldestFile,
    this.newestFile,
  });

  double get averageFileSize => totalFiles > 0 ? totalSize / totalFiles : 0.0;

  Duration get ageSpan {
    if (oldestFile == null || newestFile == null) return Duration.zero;
    return newestFile!.difference(oldestFile!);
  }
}

/// File size monitoring data for smart cleanup triggers
class FileSizeMonitoringData {
  final DateTime timestamp;
  final Map<String, DirectoryStats> directories;
  final bool needsCleanup;
  final List<String> recommendations;

  FileSizeMonitoringData({
    required this.timestamp,
    required this.directories,
    required this.needsCleanup,
    required this.recommendations,
  });

  int get totalFiles =>
      directories.values.fold(0, (sum, stats) => sum + stats.totalFiles);
  int get totalSize =>
      directories.values.fold(0, (sum, stats) => sum + stats.totalSize);
  int get totalOldFiles =>
      directories.values.fold(0, (sum, stats) => sum + stats.oldFiles);
  int get totalLargeFiles =>
      directories.values.fold(0, (sum, stats) => sum + stats.largeFiles);
}
