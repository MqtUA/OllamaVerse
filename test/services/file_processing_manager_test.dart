import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/processed_file.dart';
import 'package:ollamaverse/services/file_content_processor.dart';
import 'package:ollamaverse/services/file_processing_manager.dart';
import 'package:ollamaverse/utils/cancellation_token.dart';

// Mock FileContentProcessor for testing
class MockFileContentProcessor {
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
}

// Override the FileContentProcessor.processFiles method for testing
Future<List<ProcessedFile>> mockProcessFiles(
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
    if (isCancelled != null && isCancelled() || MockFileContentProcessor.shouldCancel) {
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

// Override the FileContentProcessor.processFile method for testing
Future<ProcessedFile> mockProcessFile(
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
  if (isCancelled != null && isCancelled() || MockFileContentProcessor.shouldCancel) {
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

void main() {
  late FileProcessingManager fileProcessingManager;
  
  setUp(() {
    final fileContentProcessor = FileContentProcessor();
    fileProcessingManager = FileProcessingManager(
      fileContentProcessor: fileContentProcessor,
    );
    MockFileContentProcessor.reset();
    
    // TODO: Replace the actual implementation with our mock
    // Note: Cannot assign to static methods - this test needs architectural refactoring
    // FileContentProcessor.processFiles = mockProcessFiles;
    // FileContentProcessor.processFile = mockProcessFile;
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
      final result = await fileProcessingManager.processFile('path/to/file.txt');
      
      // Assert
      expect(result, equals(mockFile));
      expect(MockFileContentProcessor.processFileCallCount, equals(1));
      expect(MockFileContentProcessor.lastProcessedPaths, equals(['path/to/file.txt']));
      expect(fileProcessingManager.isProcessingFiles, isFalse);
    });
    
    test('should handle exceptions during file processing', () async {
      // Arrange
      MockFileContentProcessor.exceptionToThrow = Exception('Test error');
      
      // Act & Assert
      expect(
        () => fileProcessingManager.processFiles(['path/to/file.txt']),
        throwsA(isA<FileProcessingException>()),
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
      // Arrange - create a non-completing future to keep processing state active
      final completer = Completer<List<ProcessedFile>>();
      
      // TODO: Mock the processing to never complete
      // Note: Cannot assign to static methods - this test needs architectural refactoring
      // FileContentProcessor.processFiles = (_, {onProgress, isCancelled}) {
      //   return completer.future;
      // };
      
      // Start processing
      final processingFuture = fileProcessingManager.processFiles(['path/to/file.txt']);
      
      // Act & Assert - attempt to start another processing while first is active
      expect(
        () => fileProcessingManager.processFiles(['path/to/another.txt']),
        throwsA(isA<StateError>()),
      );
      
      // Cleanup
      completer.complete([]);
      await processingFuture;
    });
  });
}