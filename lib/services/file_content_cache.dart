import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/processed_file.dart';
import '../utils/logger.dart';
import '../utils/file_utils.dart';

/// Service for caching processed file content to improve performance
class FileContentCache {
  static const String _cacheDirectoryName = 'file_cache';
  static const String _cacheIndexFileName = 'cache_index.json';
  static const int _maxCacheSize = 200 * 1024 * 1024; // 200MB max cache size
  static const Duration _maxCacheAge =
      Duration(days: 30); // Cache expires after 30 days

  static FileContentCache? _instance;
  late Directory _cacheDirectory;
  late File _cacheIndexFile;
  Map<String, CacheEntry> _cacheIndex = {};
  bool _isInitialized = false;

  FileContentCache._();

  /// Singleton instance
  static FileContentCache get instance {
    _instance ??= FileContentCache._();
    return _instance!;
  }

  /// Initialize the cache system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory('${appDir.path}/$_cacheDirectoryName');
      _cacheIndexFile = File('${_cacheDirectory.path}/$_cacheIndexFileName');

      // Create cache directory if it doesn't exist
      if (!await _cacheDirectory.exists()) {
        await _cacheDirectory.create(recursive: true);
        AppLogger.info('Created file cache directory: ${_cacheDirectory.path}');
      }

      // Load existing cache index
      await _loadCacheIndex();

      // Perform initial cleanup of old cache entries
      await _cleanupExpiredEntries();

      _isInitialized = true;
      AppLogger.info(
          'File content cache initialized with ${_cacheIndex.length} entries');
    } catch (e) {
      AppLogger.error('Failed to initialize file content cache', e);
      _isInitialized = false;
    }
  }

  /// Generate cache key from file path and modification time
  Future<String> _generateCacheKey(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      final fileSize = stat.size;
      final modifiedTime = stat.modified.millisecondsSinceEpoch;

      // Use file path, size, and modification time to create unique key
      final keyData = '$filePath|$fileSize|$modifiedTime';
      final bytes = utf8.encode(keyData);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      // Fallback to simple hash if file stat fails
      final bytes = utf8.encode(filePath);
      final digest = sha256.convert(bytes);
      return digest.toString();
    }
  }

  /// Check if a processed file is cached and still valid
  Future<ProcessedFile?> getCachedFile(String filePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final cacheKey = await _generateCacheKey(filePath);
      final entry = _cacheIndex[cacheKey];

      if (entry == null) {
        AppLogger.debug(
            'Cache miss for file: ${FileUtils.getFileName(filePath)}');
        return null;
      }

      // Check if cache entry is still valid
      if (_isCacheEntryExpired(entry)) {
        AppLogger.debug(
            'Cache entry expired for file: ${FileUtils.getFileName(filePath)}');
        await _removeCacheEntry(cacheKey);
        return null;
      }

      // Check if cached file still exists
      final cachedFile = File('${_cacheDirectory.path}/${entry.fileName}');
      if (!await cachedFile.exists()) {
        AppLogger.debug(
            'Cached file missing for: ${FileUtils.getFileName(filePath)}');
        await _removeCacheEntry(cacheKey);
        return null;
      }

      // Load and return cached ProcessedFile
      final cachedContent = await cachedFile.readAsString();
      final processedFile = ProcessedFile.fromJson(jsonDecode(cachedContent));

      // Update access time
      entry.lastAccessedAt = DateTime.now();
      await _saveCacheIndex();

      AppLogger.debug('Cache hit for file: ${FileUtils.getFileName(filePath)}');
      return processedFile;
    } catch (e) {
      AppLogger.error(
          'Error retrieving cached file: ${FileUtils.getFileName(filePath)}',
          e);
      return null;
    }
  }

  /// Cache a processed file
  Future<void> cacheFile(String filePath, ProcessedFile processedFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final cacheKey = await _generateCacheKey(filePath);
      final fileName = '$cacheKey.json';
      final cachedFile = File('${_cacheDirectory.path}/$fileName');

      // Save processed file content
      final jsonContent = jsonEncode(processedFile.toJson());
      await cachedFile.writeAsString(jsonContent);

      // Update cache index
      final entry = CacheEntry(
        cacheKey: cacheKey,
        fileName: fileName,
        originalPath: filePath,
        originalFileName: processedFile.fileName,
        fileSize: jsonContent.length,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
        fileType: processedFile.type,
      );

      _cacheIndex[cacheKey] = entry;
      await _saveCacheIndex();

      AppLogger.debug(
          'Cached file: ${processedFile.fileName} (key: ${cacheKey.substring(0, 8)}...)');

      // Check if cache cleanup is needed
      await _checkCacheSizeLimit();
    } catch (e) {
      AppLogger.error('Error caching file: ${processedFile.fileName}', e);
    }
  }

  /// Check if cache entry is expired
  bool _isCacheEntryExpired(CacheEntry entry) {
    final now = DateTime.now();
    return now.difference(entry.createdAt) > _maxCacheAge;
  }

  /// Remove a cache entry
  Future<void> _removeCacheEntry(String cacheKey) async {
    try {
      final entry = _cacheIndex[cacheKey];
      if (entry != null) {
        final cachedFile = File('${_cacheDirectory.path}/${entry.fileName}');
        if (await cachedFile.exists()) {
          await cachedFile.delete();
        }
        _cacheIndex.remove(cacheKey);
        await _saveCacheIndex();
      }
    } catch (e) {
      AppLogger.error('Error removing cache entry: $cacheKey', e);
    }
  }

  /// Clean up expired cache entries
  Future<void> _cleanupExpiredEntries() async {
    try {
      final expiredKeys = <String>[];
      final now = DateTime.now();

      for (final entry in _cacheIndex.entries) {
        if (now.difference(entry.value.lastAccessedAt) > _maxCacheAge) {
          expiredKeys.add(entry.key);
        }
      }

      for (final key in expiredKeys) {
        await _removeCacheEntry(key);
      }

      if (expiredKeys.isNotEmpty) {
        AppLogger.info(
            'Cleaned up ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      AppLogger.error('Error cleaning up expired cache entries', e);
    }
  }

  /// Check cache size and remove oldest entries if needed
  Future<void> _checkCacheSizeLimit() async {
    try {
      int totalSize = 0;
      for (final entry in _cacheIndex.values) {
        totalSize += entry.fileSize;
      }

      if (totalSize > _maxCacheSize) {
        // Sort entries by last accessed time (oldest first)
        final sortedEntries = _cacheIndex.entries.toList()
          ..sort((a, b) =>
              a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt));

        int removedSize = 0;
        int removedCount = 0;

        // Remove oldest entries until we're under the limit
        for (final entry in sortedEntries) {
          if (totalSize - removedSize <= _maxCacheSize * 0.8) {
            break; // Leave 20% buffer
          }

          await _removeCacheEntry(entry.key);
          removedSize += entry.value.fileSize;
          removedCount++;
        }

        if (removedCount > 0) {
          AppLogger.info(
              'Cache size limit reached. Removed $removedCount entries (${FileUtils.formatFileSize(removedSize)})');
        }
      }
    } catch (e) {
      AppLogger.error('Error checking cache size limit', e);
    }
  }

  /// Load cache index from disk
  Future<void> _loadCacheIndex() async {
    try {
      if (await _cacheIndexFile.exists()) {
        final indexContent = await _cacheIndexFile.readAsString();
        final indexData = jsonDecode(indexContent) as Map<String, dynamic>;

        _cacheIndex = {};
        for (final entry in indexData.entries) {
          _cacheIndex[entry.key] = CacheEntry.fromJson(entry.value);
        }

        AppLogger.debug(
            'Loaded cache index with ${_cacheIndex.length} entries');
      } else {
        _cacheIndex = {};
        AppLogger.debug('No existing cache index found, starting fresh');
      }
    } catch (e) {
      AppLogger.error('Error loading cache index, starting fresh', e);
      _cacheIndex = {};
    }
  }

  /// Save cache index to disk
  Future<void> _saveCacheIndex() async {
    try {
      final indexData = <String, dynamic>{};
      for (final entry in _cacheIndex.entries) {
        indexData[entry.key] = entry.value.toJson();
      }

      final indexContent = jsonEncode(indexData);
      await _cacheIndexFile.writeAsString(indexContent);
    } catch (e) {
      AppLogger.error('Error saving cache index', e);
    }
  }

  /// Get cache statistics
  Future<CacheStats> getCacheStats() async {
    if (!_isInitialized) {
      await initialize();
    }

    int totalSize = 0;
    int totalEntries = _cacheIndex.length;
    DateTime? oldestEntry;
    DateTime? newestEntry;

    for (final entry in _cacheIndex.values) {
      totalSize += entry.fileSize;

      if (oldestEntry == null || entry.createdAt.isBefore(oldestEntry)) {
        oldestEntry = entry.createdAt;
      }
      if (newestEntry == null || entry.createdAt.isAfter(newestEntry)) {
        newestEntry = entry.createdAt;
      }
    }

    return CacheStats(
      totalEntries: totalEntries,
      totalSize: totalSize,
      oldestEntry: oldestEntry,
      newestEntry: newestEntry,
    );
  }

  /// Clear all cache entries
  Future<void> clearCache() async {
    try {
      // Delete all cached files
      await for (final entity in _cacheDirectory.list()) {
        if (entity is File && entity.path != _cacheIndexFile.path) {
          await entity.delete();
        }
      }

      // Clear index
      _cacheIndex.clear();
      await _saveCacheIndex();

      AppLogger.info('File cache cleared');
    } catch (e) {
      AppLogger.error('Error clearing cache', e);
    }
  }

  /// Get cache directory path for cleanup service integration
  String get cacheDirectoryPath => _cacheDirectory.path;
}

/// Represents a cached file entry
class CacheEntry {
  final String cacheKey;
  final String fileName;
  final String originalPath;
  final String originalFileName;
  final int fileSize;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  final FileType fileType;

  CacheEntry({
    required this.cacheKey,
    required this.fileName,
    required this.originalPath,
    required this.originalFileName,
    required this.fileSize,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.fileType,
  });

  Map<String, dynamic> toJson() {
    return {
      'cacheKey': cacheKey,
      'fileName': fileName,
      'originalPath': originalPath,
      'originalFileName': originalFileName,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'fileType': fileType.name,
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      cacheKey: json['cacheKey'] as String,
      fileName: json['fileName'] as String,
      originalPath: json['originalPath'] as String,
      originalFileName: json['originalFileName'] as String,
      fileSize: json['fileSize'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
      fileType: FileType.values.firstWhere(
        (e) => e.name == json['fileType'],
        orElse: () => FileType.unknown,
      ),
    );
  }
}

/// Cache statistics for monitoring
class CacheStats {
  final int totalEntries;
  final int totalSize;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const CacheStats({
    required this.totalEntries,
    required this.totalSize,
    this.oldestEntry,
    this.newestEntry,
  });

  String get formattedSize => FileUtils.formatFileSize(totalSize);
}
