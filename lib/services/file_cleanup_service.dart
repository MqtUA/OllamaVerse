import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import '../utils/file_utils.dart';
import 'file_content_cache.dart';

/// Helper class to store file information for sorting
class _FileInfo {
  final File file;
  final DateTime modified;
  final int size;

  _FileInfo(this.file, this.modified, this.size);
}

/// Parameters for monitoring computation in isolate
class MonitoringParams {
  final List<(String, String, int)> directories;
  final Map<String, DirectoryStats> previousStats;
  final DateTime? lastUpdate;
  final FileCleanupConfig config;

  MonitoringParams({
    required this.directories,
    required this.previousStats,
    required this.lastUpdate,
    required this.config,
  });
}

/// Result from monitoring computation
class MonitoringResult {
  final Map<String, DirectoryStats> directoryStats;
  final bool needsCleanup;
  final List<String> recommendations;

  MonitoringResult({
    required this.directoryStats,
    required this.needsCleanup,
    required this.recommendations,
  });
}

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

      final directories = [
        ('attachments', '${appDir.path}/attachments', _config.maxDirectorySize),
        ('logs', '${appDir.path}/logs', _config.maxLogSize),
        ('cache', '${appDir.path}/cache', _config.maxCacheSize),
        (
          'file_cache',
          FileContentCache.instance.cacheDirectoryPath,
          _config.maxCacheSize
        ),
      ];

      // Run directory stats computation in background to avoid blocking UI
      final monitoringParams = MonitoringParams(
        directories: directories,
        previousStats: Map.from(_directoryStats),
        lastUpdate: _lastMonitoringUpdate,
        config: _config,
      );

      final result = await compute(_computeDirectoryStats, monitoringParams);

      // Update state with results
      _directoryStats.addAll(result.directoryStats);
      _lastMonitoringUpdate = DateTime.now();

      final finalMonitoringData = FileSizeMonitoringData(
        timestamp: DateTime.now(),
        directories: result.directoryStats,
        needsCleanup: result.needsCleanup,
        recommendations: result.recommendations,
      );

      _monitoringController?.add(finalMonitoringData);

      // Trigger automatic cleanup if needed
      if (result.needsCleanup && !_isCleanupRunning) {
        AppLogger.info('File size monitoring triggered automatic cleanup');
        await _performSmartCleanup();
      }
    } catch (e) {
      AppLogger.error('Error during file size monitoring', e);
    }
  }

  /// Compute directory statistics in background thread to avoid blocking UI
  static Future<MonitoringResult> _computeDirectoryStats(
      MonitoringParams params) async {
    final directoryStats = <String, DirectoryStats>{};
    bool needsCleanup = false;
    final recommendations = <String>[];

    for (final (name, path, maxSize) in params.directories) {
      final dir = Directory(path);
      if (await dir.exists()) {
        final stats = await _getDirectoryStatsStatic(dir, params.config);
        directoryStats[name] = stats;

        // Check if cleanup is needed
        if (stats.totalSize > maxSize) {
          needsCleanup = true;
          recommendations.add(
            '$name directory (${_formatFileSize(stats.totalSize)}) exceeds limit (${_formatFileSize(maxSize)})',
          );
        }

        // Check growth rate
        final previousStats = params.previousStats[name];
        if (previousStats != null && params.lastUpdate != null) {
          final timeDiff = DateTime.now().difference(params.lastUpdate!);
          final sizeDiff = stats.totalSize - previousStats.totalSize;

          if (timeDiff.inMinutes > 0 && sizeDiff > 0) {
            final growthRate =
                sizeDiff / timeDiff.inMinutes; // bytes per minute
            final projectedSize =
                stats.totalSize + (growthRate * 60 * 24); // 24 hours projection

            if (projectedSize > maxSize * 0.8) {
              // 80% of max size
              recommendations.add(
                '$name directory growing rapidly (${_formatFileSize(sizeDiff)} in ${timeDiff.inMinutes}min)',
              );
            }
          }
        }
      }
    }

    return MonitoringResult(
      directoryStats: directoryStats,
      needsCleanup: needsCleanup,
      recommendations: recommendations,
    );
  }

  /// Static version of formatFileSize for isolate usage
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Static version of directory stats computation for isolate usage
  static Future<DirectoryStats> _getDirectoryStatsStatic(
      Directory directory, FileCleanupConfig config) async {
    int totalFiles = 0;
    int totalSize = 0;
    int oldFiles = 0;
    int largeFiles = 0;
    DateTime? oldestFile;
    DateTime? newestFile;
    final now = DateTime.now();

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          totalFiles++;
          totalSize += stat.size;

          if (oldestFile == null || stat.modified.isBefore(oldestFile)) {
            oldestFile = stat.modified;
          }
          if (newestFile == null || stat.modified.isAfter(newestFile)) {
            newestFile = stat.modified;
          }

          final maxAge = _getMaxAgeForDirectoryStatic(directory.path, config);
          if (now.difference(stat.modified) > maxAge) {
            oldFiles++;
          }

          if (stat.size > 10 * 1024 * 1024) {
            largeFiles++;
          }
        } catch (e) {
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

  /// Static version of max age getter for isolate usage
  static Duration _getMaxAgeForDirectoryStatic(
      String directoryPath, FileCleanupConfig config) {
    if (directoryPath.contains('logs')) return config.maxLogAge;
    if (directoryPath.contains('cache')) return config.maxCacheAge;
    return config.maxFileAge;
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
          '${FileUtils.formatFileSize(result.freedSize)} freed');
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
      [
        receivePort.sendPort,
        _config,
        FileContentCache.instance.cacheDirectoryPath
      ],
    );

    final result = await receivePort.first as CleanupResult;
    return result;
  }

  /// Entry point for cleanup isolate
  static void _cleanupIsolateEntryPoint(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final config = args[1] as FileCleanupConfig;
    final fileCachePath = args[2] as String;

    try {
      final result = await _performActualCleanup(config, fileCachePath);
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
      FileCleanupConfig config, String fileCachePath) async {
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

    // Clean file content cache directory
    // Note: We can't directly access the cache instance in isolate, so use hardcoded path
    final fileCacheDir = Directory(fileCachePath);
    if (await fileCacheDir.exists()) {
      final fileCacheResult = await _cleanDirectory(
        fileCacheDir,
        config.maxCacheAge,
        config.maxCacheSize,
      );
      totalFiles += fileCacheResult.totalFiles;
      deletedFiles += fileCacheResult.deletedFiles;
      totalSize += fileCacheResult.totalSize;
      freedSize += fileCacheResult.freedSize;
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
    final List<_FileInfo> filesInfo = [];

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          filesInfo.add(_FileInfo(entity, stat.modified, stat.size));
          totalFiles++;
          totalSize += stat.size;
        } catch (e) {
          // Skip files that can't be accessed
          continue;
        }
      }
    }

    // Sort files by modification date (oldest first) for size-based cleanup
    filesInfo.sort((a, b) => a.modified.compareTo(b.modified));

    int currentSize = totalSize;

    for (final fileInfo in filesInfo) {
      final entity = fileInfo.file;
      final statModified = fileInfo.modified;
      final statSize = fileInfo.size;

      bool shouldDelete = false;
      final age = now.difference(statModified);

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
          freedSize += statSize;
          currentSize -= statSize;
        } catch (e) {
          // Continue with other files if one fails
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
      '${appDir.path}/file_cache',
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
