import 'dart:async';
import '../models/processed_file.dart';
import '../services/file_content_processor.dart';
import '../utils/cancellation_token.dart';
import '../utils/logger.dart';

/// Interface for file processing manager to allow for testing
abstract class IFileProcessingManager {
  /// Process multiple files with progress tracking
  Future<List<ProcessedFile>> processFiles(
    List<String> filePaths, {
    CancellationToken? cancellationToken,
  });

  /// Process a single file with progress tracking
  Future<ProcessedFile> processFile(
    String filePath, {
    CancellationToken? cancellationToken,
  });

  /// Get current file processing progress
  Map<String, FileProcessingProgress> get fileProcessingProgress;

  /// Check if file processing is in progress
  bool get isProcessingFiles;

  /// Clear processing state and progress data
  void clearProcessingState();
}

/// Service responsible for managing file attachment processing with progress tracking and cancellation support
///
/// This service provides a clean interface for file processing while handling
/// progress updates and cancellation to improve user experience during long operations
class FileProcessingManager implements IFileProcessingManager {
  // Dependencies
  final FileContentProcessor _fileContentProcessor;

  // State tracking prevents concurrent processing and provides progress visibility
  bool _isProcessingFiles = false;
  final Map<String, FileProcessingProgress> _fileProcessingProgress = {};
  bool _disposed = false;

  // Broadcast stream allows multiple listeners to track progress updates
  final _progressController =
      StreamController<Map<String, FileProcessingProgress>>.broadcast();

  /// Constructor with dependency injection
  FileProcessingManager({
    required FileContentProcessor fileContentProcessor,
  }) : _fileContentProcessor = fileContentProcessor;

  /// Stream of file processing progress updates
  Stream<Map<String, FileProcessingProgress>> get progressStream =>
      _progressController.stream;

  /// Get current file processing progress
  @override
  Map<String, FileProcessingProgress> get fileProcessingProgress =>
      Map.unmodifiable(_fileProcessingProgress);

  /// Check if file processing is in progress
  @override
  bool get isProcessingFiles => _isProcessingFiles;

  /// Process multiple files with progress tracking and cancellation support
  @override
  Future<List<ProcessedFile>> processFiles(
    List<String> filePaths, {
    CancellationToken? cancellationToken,
  }) async {
    if (filePaths.isEmpty) {
      return [];
    }

    if (_isProcessingFiles) {
      throw StateError('File processing is already in progress');
    }

    try {
      _isProcessingFiles = true;
      _fileProcessingProgress.clear();
      _notifyProgressListeners();

      AppLogger.info('Processing ${filePaths.length} attached files');

      final effectiveCancellationToken =
          cancellationToken ?? CancellationToken();

      final processedFiles = await _fileContentProcessor.processFiles(
        filePaths,
        onProgress: (progress) {
          _fileProcessingProgress[progress.filePath] = progress;
          _notifyProgressListeners();
        },
        isCancelled: () => effectiveCancellationToken.isCancelled,
      );

      AppLogger.info('Successfully processed ${processedFiles.length} files');
      return processedFiles;
    } catch (e) {
      AppLogger.error('Error processing files', e);
      throw FileProcessingException('Failed to process attached files: $e');
    } finally {
      _isProcessingFiles = false;
      _fileProcessingProgress.clear();
      _notifyProgressListeners();
    }
  }

  /// Process a single file with progress tracking and cancellation support
  @override
  Future<ProcessedFile> processFile(
    String filePath, {
    CancellationToken? cancellationToken,
  }) async {
    try {
      _isProcessingFiles = true;
      _fileProcessingProgress.clear();
      _notifyProgressListeners();

      AppLogger.info('Processing file: $filePath');

      final effectiveCancellationToken =
          cancellationToken ?? CancellationToken();

      final processedFile = await _fileContentProcessor.processFile(
        filePath,
        onProgress: (progress) {
          _fileProcessingProgress[progress.filePath] = progress;
          _notifyProgressListeners();
        },
        isCancelled: () => effectiveCancellationToken.isCancelled,
      );

      AppLogger.info('Successfully processed file: ${processedFile.fileName}');
      return processedFile;
    } catch (e) {
      AppLogger.error('Error processing file: $filePath', e);
      throw FileProcessingException('Failed to process file: $e');
    } finally {
      _isProcessingFiles = false;
      _fileProcessingProgress.clear();
      _notifyProgressListeners();
    }
  }

  /// Clear processing state and progress data
  @override
  void clearProcessingState() {
    _isProcessingFiles = false;
    _fileProcessingProgress.clear();
    _notifyProgressListeners();
  }

  /// Notify progress listeners of updates
  void _notifyProgressListeners() {
    if (!_disposed && !_progressController.isClosed) {
      _progressController.add(Map.from(_fileProcessingProgress));
    }
  }

  /// Dispose resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Clear processing state
    clearProcessingState();

    // Close stream controller
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}

/// Exception thrown when file processing fails
class FileProcessingException implements Exception {
  final String message;

  FileProcessingException(this.message);

  @override
  String toString() => 'FileProcessingException: $message';
}
