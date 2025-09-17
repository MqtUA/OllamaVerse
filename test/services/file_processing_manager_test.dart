import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/processed_file.dart';
import 'package:ollamaverse/services/file_content_processor.dart';
import 'package:ollamaverse/services/file_processing_manager.dart';
import 'package:ollamaverse/utils/cancellation_token.dart';

// Mock FileContentProcessor for testing
class MockFileContentProcessor extends FileContentProcessor {
  static List<ProcessedFile> mockProcessedFiles = [];
  static Exception? exceptionToThrow;
  static bool shouldCancel = false;
  static int processFilesCallCount = 0;
  static int processFileCallCount = 0;
  static List<String> lastProcessedPaths = [];
  static FileProcessingProgress? lastReportedProgress;

  static void reset() {
    mockProcessedFiles = [];
    exceptionToThrow = null;
    shouldCancel = false;
    processFilesCallCount = 0;
    processFileCallCount = 0;
    lastProcessedPaths = [];
    lastReportedProgress = null;
  }

  @override
  Future<List<ProcessedFile>> processFiles(
    List<String> filePaths, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    MockFileContentProcessor.processFilesCallCount++;
    MockFileContentProcessor.lastProcessedPaths = List.from(filePaths);

    if (MockFileContentProcessor.exceptionToThrow != null) {
      throw MockFileContentProcessor.exceptionToThrow!;
    }

    // Simulate progress reporting
    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      final progress = FileProcessingProgress(
        filePath: path,
        fileName: 'test_file_$i.txt',
        progress: 0.5,
        status: 'Processing...',
      );

      MockFileContentProcessor.lastReportedProgress = progress;
      onProgress?.call(progress);

      // Check for cancellation
      if (isCancelled != null && isCancelled() ||
          MockFileContentProcessor.shouldCancel) {
        return [ProcessedFile.cancelled(path)];
      }

      // Report completion
      final completedProgress = FileProcessingProgress(
        filePath: path,
        fileName: 'test_file_$i.txt',
        progress: 1.0,
        status: 'Completed',
      );

      MockFileContentProcessor.lastReportedProgress = completedProgress;
      onProgress?.call(completedProgress);
    }

    return MockFileContentProcessor.mockProcessedFiles;
  }

  @override
  Future<ProcessedFile> processFile(
    String filePath, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    MockFileContentProcessor.processFileCallCount++;
    MockFileContentProcessor.lastProcessedPaths = [filePath];

    if (MockFileContentProcessor.exceptionToThrow != null) {
      throw MockFileContentProcessor.exceptionToThrow!;
    }

    // Simulate progress reporting
    final progress = FileProcessingProgress(
      filePath: filePath,
      fileName: 'test_file.txt',
      progress: 0.5,
      status: 'Processing...',
    );

    MockFileContentProcessor.lastReportedProgress = progress;
    onProgress?.call(progress);

    // Check for cancellation
    if (isCancelled != null && isCancelled() ||
        MockFileContentProcessor.shouldCancel) {
      return ProcessedFile.cancelled(filePath);
    }

    // Report completion
    final completedProgress = FileProcessingProgress(
      filePath: filePath,
      fileName: 'test_file.txt',
      progress: 1.0,
      status: 'Completed',
    );

    MockFileContentProcessor.lastReportedProgress = completedProgress;
    onProgress?.call(completedProgress);

    return MockFileContentProcessor.mockProcessedFiles.isNotEmpty
        ? MockFileContentProcessor.mockProcessedFiles.first
        : ProcessedFile.text(
            originalPath: filePath,
            fileName: 'test_file.txt',
            textContent: 'Test content',
            fileSizeBytes: 100,
          );
  }
}

// Mock that simulates a never-completing processor for testing concurrent operations
class NeverCompletingFileContentProcessor extends FileContentProcessor {
  final Completer<List<ProcessedFile>> _multiFileCompleter =
      Completer<List<ProcessedFile>>();
  final Completer<ProcessedFile> _singleFileCompleter =
      Completer<ProcessedFile>();

  @override
  Future<List<ProcessedFile>> processFiles(
    List<String> filePaths, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) {
    return _multiFileCompleter.future;
  }

  @override
  Future<ProcessedFile> processFile(
    String filePath, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) {
    return _singleFileCompleter.future;
  }

  void complete(List<ProcessedFile> result) {
    if (!_multiFileCompleter.isCompleted) {
      _multiFileCompleter.complete(result);
    }
  }

  void completeSingle(ProcessedFile result) {
    if (!_singleFileCompleter.isCompleted) {
      _singleFileCompleter.complete(result);
    }
  }
}

void main() {
  late FileProcessingManager fileProcessingManager;
  late MockFileContentProcessor mockFileContentProcessor;

  setUp(() {
    mockFileContentProcessor = MockFileContentProcessor();
    fileProcessingManager = FileProcessingManager(
      fileContentProcessor: mockFileContentProcessor,
    );
    MockFileContentProcessor.reset();
  });

  group('FileProcessingManager', () {
    test('should process multiple files successfully', () async {
      // Arrange
      final mockFiles = [
        ProcessedFile.text(
          originalPath: 'path/to/file1.txt',
          fileName: 'file1.txt',
          textContent: 'Test content 1',
          fileSizeBytes: 100,
        ),
        ProcessedFile.text(
          originalPath: 'path/to/file2.txt',
          fileName: 'file2.txt',
          textContent: 'Test content 2',
          fileSizeBytes: 200,
        ),
      ];

      MockFileContentProcessor.mockProcessedFiles = mockFiles;

      // Act
      final result = await fileProcessingManager.processFiles(
        ['path/to/file1.txt', 'path/to/file2.txt'],
      );

      // Assert
      expect(result, equals(mockFiles));
      expect(MockFileContentProcessor.processFilesCallCount, equals(1));
      expect(MockFileContentProcessor.lastProcessedPaths,
          equals(['path/to/file1.txt', 'path/to/file2.txt']));
      expect(fileProcessingManager.isProcessingFiles, isFalse);
    });

    test('should process a single file successfully', () async {
      // Arrange
      final mockFile = ProcessedFile.text(
        originalPath: 'path/to/file.txt',
        fileName: 'file.txt',
        textContent: 'Test content',
        fileSizeBytes: 100,
      );

      MockFileContentProcessor.mockProcessedFiles = [mockFile];

      // Act
      final result =
          await fileProcessingManager.processFile('path/to/file.txt');

      // Assert
      expect(result, equals(mockFile));
      expect(MockFileContentProcessor.processFileCallCount, equals(1));
      expect(MockFileContentProcessor.lastProcessedPaths,
          equals(['path/to/file.txt']));
      expect(fileProcessingManager.isProcessingFiles, isFalse);
    });

    test('should handle exceptions during file processing', () async {
      // Arrange
      MockFileContentProcessor.exceptionToThrow = Exception('Test error');

      // Act & Assert
      await expectLater(
        fileProcessingManager.processFiles(['path/to/file.txt']),
        throwsA(isA<Exception>()),
      );

      expect(fileProcessingManager.isProcessingFiles, isFalse);
      expect(fileProcessingManager.fileProcessingProgress, isEmpty);
    });

    test('should handle cancellation during file processing', () async {
      // Arrange
      final cancellationToken = CancellationToken();
      MockFileContentProcessor.shouldCancel = true;

      // Act
      final result = await fileProcessingManager.processFiles(
        ['path/to/file.txt'],
        cancellationToken: cancellationToken,
      );

      // Assert
      expect(result.length, equals(1));
      expect(result.first.isCancelled, isTrue);
      expect(fileProcessingManager.isProcessingFiles, isFalse);
    });

    test('should track progress during file processing', () async {
      // Arrange
      final mockFile = ProcessedFile.text(
        originalPath: 'path/to/file.txt',
        fileName: 'file.txt',
        textContent: 'Test content',
        fileSizeBytes: 100,
      );

      MockFileContentProcessor.mockProcessedFiles = [mockFile];

      // Track progress updates
      List<Map<String, FileProcessingProgress>> progressUpdates = [];
      fileProcessingManager.progressStream.listen((progress) {
        progressUpdates.add(Map.from(progress));
      });

      // Act
      await fileProcessingManager.processFile('path/to/file.txt');

      // Assert
      expect(progressUpdates.length, greaterThan(0));
      expect(progressUpdates.last, isEmpty); // Should be cleared at the end
    });

    test('should clear processing state', () async {
      // Arrange - simulate active processing state
      fileProcessingManager.clearProcessingState();

      // Assert
      expect(fileProcessingManager.isProcessingFiles, isFalse);
      expect(fileProcessingManager.fileProcessingProgress, isEmpty);
    });

    test('should throw error when processing is already in progress', () async {
      // Arrange - create a manager with never-completing processor
      final neverCompletingProcessor = NeverCompletingFileContentProcessor();
      final concurrentTestManager = FileProcessingManager(
        fileContentProcessor: neverCompletingProcessor,
      );

      // Start processing that won't complete
      final processingFuture =
          concurrentTestManager.processFiles(['path/to/file.txt']);

      // Wait a bit to ensure processing has started
      await Future.delayed(const Duration(milliseconds: 10));

      // Act & Assert - attempt to start another processing while first is active
      expect(
        () => concurrentTestManager.processFiles(['path/to/another.txt']),
        throwsA(isA<StateError>()),
      );

      // Cleanup - complete the first operation
      neverCompletingProcessor.complete([]);
      await processingFuture;
    });
    test(
        'should throw error when single file processing is already in progress',
        () async {
      final neverCompletingProcessor = NeverCompletingFileContentProcessor();
      final concurrentTestManager = FileProcessingManager(
        fileContentProcessor: neverCompletingProcessor,
      );

      final processingFuture =
          concurrentTestManager.processFile('path/to/file.txt');

      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        () => concurrentTestManager.processFile('path/to/another.txt'),
        throwsA(isA<StateError>()),
      );

      neverCompletingProcessor.completeSingle(
        ProcessedFile.text(
          originalPath: 'path/to/file.txt',
          fileName: 'file.txt',
          textContent: 'content',
          fileSizeBytes: 10,
        ),
      );
      await processingFuture;
    });
  });
}
