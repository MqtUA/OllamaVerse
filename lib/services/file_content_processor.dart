import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/processed_file.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';
import 'file_content_cache.dart';

/// Data class for tracking file processing progress
class FileProcessingProgress {
  final String filePath;
  final String fileName;
  final double progress; // 0.0 to 1.0
  final String status; // e.g., "processing", "completed", "error"

  FileProcessingProgress({
    required this.filePath,
    required this.fileName,
    required this.progress,
    required this.status,
  });
}

/// Service for processing different file types and extracting content for AI analysis
class FileContentProcessor {
  // File size limits (in bytes)
  static const int maxImageSizeBytes = 100 * 1024 * 1024; // 100MB for images
  static const int maxTextSizeBytes = 50 * 1024 * 1024; // 50MB for text files
  static const int maxPdfSizeBytes = 100 * 1024 * 1024; // 100MB for PDFs

  // Use shared extension lists from FileUtils (avoiding duplication)

  /// Check if a file can be processed by this service
  static Future<bool> canProcessFile(String filePath) async {
    final extension = _getFileExtension(filePath);
    if (FileUtils.imageExtensions.contains(extension) ||
        FileUtils.textExtensions.contains(extension) ||
        FileUtils.sourceCodeExtensions.contains(extension) ||
        FileUtils.jsonExtensions.contains(extension) ||
        extension == 'pdf') {
      return true;
    }
    // Fallback: if extension is not recognized, try to determine if it's a text file heuristically
    return await FileUtils.isLikelyTextFile(filePath);
  }

  /// Get the file type based on extension
  static Future<FileType> getFileType(String filePath) async {
    final extension = _getFileExtension(filePath);

    if (FileUtils.imageExtensions.contains(extension)) {
      return FileType.image;
    } else if (extension == 'pdf') {
      return FileType.pdf;
    } else if (FileUtils.jsonExtensions.contains(extension)) {
      return FileType.json;
    } else if (FileUtils.sourceCodeExtensions.contains(extension)) {
      return FileType.sourceCode;
    } else if (FileUtils.textExtensions.contains(extension)) {
      return FileType.text;
    } else if (await FileUtils.isLikelyTextFile(filePath)) {
      // If extension is unknown but it's likely a text file, treat as text
      return FileType.text;
    } else {
      return FileType.unknown;
    }
  }

  /// Process a file and extract its content for AI analysis
  static Future<ProcessedFile> processFile(
    String filePath, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      if (isCancelled?.call() ?? false) {
        return ProcessedFile.cancelled(filePath);
      }
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File does not exist', filePath);
      }

      final fileName = FileUtils.getFileName(filePath);
      final fileSize = await file.length();
      final fileType = await getFileType(filePath);

      // Check cache first
      final cache = FileContentCache.instance;
      final cachedFile = await cache.getCachedFile(filePath);
      if (cachedFile != null) {
        AppLogger.info('Using cached content for: $fileName');
        return cachedFile;
      }

      AppLogger.info(
          'Processing file: $fileName (${fileType.name}, ${FileUtils.formatFileSize(fileSize)})');

      onProgress?.call(FileProcessingProgress(
        filePath: filePath,
        fileName: fileName,
        progress: 0.1, // Started processing
        status: 'Processing...',
      ));

      if (isCancelled?.call() ?? false) {
        return ProcessedFile.cancelled(filePath);
      }

      ProcessedFile processedFile;
      // Await the fileType here before the switch statement
      final resolvedFileType = fileType;
      switch (resolvedFileType) {
        case FileType.image:
          processedFile = await _processImageFile(filePath, fileName, fileSize);
          break;
        case FileType.pdf:
          processedFile = await _processPdfFile(
              filePath, fileName, fileSize, onProgress, isCancelled);
          break;
        case FileType.text:
        case FileType.sourceCode:
        case FileType.json:
          processedFile =
              await _processTextFile(filePath, fileName, fileSize, resolvedFileType);
          break;
        default:
          throw UnsupportedError('File type ${resolvedFileType.name} is not supported');
      }

      // Cache the processed file for future use
      await cache.cacheFile(filePath, processedFile);

      return processedFile;
    } catch (e) {
      AppLogger.error('Error processing file $filePath', e);
      rethrow;
    }
  }

  /// Process multiple files in batch with caching and progress reporting
  static Future<List<ProcessedFile>> processFiles(
    List<String> filePaths, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final List<ProcessedFile> processedFiles = [];
    final List<String> errors = [];
    int cacheHits = 0;

    for (final filePath in filePaths) {
      try {
        if (isCancelled?.call() ?? false) {
          AppLogger.info('File processing cancelled by user.');
          break;
        }
        final fileName = FileUtils.getFileName(filePath);

        // Check cache first
        final cache = FileContentCache.instance;
        final cachedFile = await cache.getCachedFile(filePath);
        if (cachedFile != null) {
          processedFiles.add(cachedFile);
          cacheHits++;
          onProgress?.call(FileProcessingProgress(
            filePath: filePath,
            fileName: fileName,
            progress: 1.0,
            status: 'Loaded from cache',
          ));
          AppLogger.debug('Cache hit for: $fileName');
          continue;
        }

        // Process file if not cached
        final processedFile = await processFile(
          filePath,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (processedFile.isCancelled) {
          AppLogger.info('Processing of $fileName was cancelled.');
          break;
        }
        processedFiles.add(processedFile);

        onProgress?.call(FileProcessingProgress(
          filePath: filePath,
          fileName: fileName,
          progress: 1.0,
          status: 'Processing complete',
        ));
        AppLogger.info('Successfully processed: ${processedFile.fileName}');
      } catch (e) {
        final fileName = FileUtils.getFileName(filePath);
        final error = 'Failed to process $fileName: $e';
        errors.add(error);
        onProgress?.call(FileProcessingProgress(
          filePath: filePath,
          fileName: fileName,
          progress: 1.0,
          status: 'Error: $e',
        ));
        AppLogger.error('File processing error', e);
      }
    }

    if (errors.isNotEmpty) {
      AppLogger.warning('Some files failed to process: ${errors.join(', ')}');
    }

    if (cacheHits > 0) {
      AppLogger.info(
          'Batch processing completed: $cacheHits cache hits out of ${filePaths.length} files');
    }

    return processedFiles;
  }

  /// Process an image file by converting to base64
  static Future<ProcessedFile> _processImageFile(
      String filePath, String fileName, int fileSize) async {
    if (fileSize > maxImageSizeBytes) {
      throw FileSystemException(
        'Image file too large (${FileUtils.formatFileSize(fileSize)}). Maximum size is ${FileUtils.formatFileSize(maxImageSizeBytes)}',
        filePath,
      );
    }

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Content = base64Encode(bytes);

      // Get image metadata
      final extension = _getFileExtension(filePath);
      final mimeType = _getMimeType(extension);

      final metadata = {
        'originalSize': fileSize,
        'base64Size': base64Content.length,
        'compression': 'none',
      };

      AppLogger.info(
          'Image processed: $fileName, base64 size: ${base64Content.length} chars');

      return ProcessedFile.image(
        originalPath: filePath,
        fileName: fileName,
        base64Content: base64Content,
        fileSizeBytes: fileSize,
        mimeType: mimeType,
        metadata: metadata,
      );
    } catch (e) {
      throw FileSystemException('Failed to process image file: $e', filePath);
    }
  }

  /// Process a PDF file by extracting text content with progress reporting
  static Future<ProcessedFile> _processPdfFile(
    String filePath,
    String fileName,
    int fileSize,
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  ) async {
    if (fileSize > maxPdfSizeBytes) {
      throw FileSystemException(
        'PDF file too large (${FileUtils.formatFileSize(fileSize)}). Maximum size is ${FileUtils.formatFileSize(maxPdfSizeBytes)}',
        filePath,
      );
    }

    try {
      AppLogger.info('Starting PDF text extraction for: $fileName');
      onProgress?.call(FileProcessingProgress(
        filePath: filePath,
        fileName: fileName,
        progress: 0.2,
        status: 'Extracting text...',
      ));

      // Extract text from PDF using Syncfusion with chunking
      final textContent = await _extractTextFromPdfInChunks(
        filePath,
        fileName,
        onProgress: (progress) {
          onProgress?.call(FileProcessingProgress(
            filePath: filePath,
            fileName: fileName,
            progress: 0.2 + (progress * 0.7), // Scale progress from 0.2 to 0.9
            status: 'Page ${progress * 100}% processed',
          ));
        },
        isCancelled: isCancelled,
      );

      final metadata = {
        'originalSize': fileSize,
        'textLength': textContent.length,
        'extractionMethod': 'syncfusion_pdf_chunked',
        'processingStatus':
            textContent.contains('Error extracting text from PDF')
                ? 'failed'
                : 'success',
      };

      onProgress?.call(FileProcessingProgress(
        filePath: filePath,
        fileName: fileName,
        progress: 0.95,
        status: 'Finalizing...',
      ));

      AppLogger.info(
          'PDF processed: $fileName, extracted ${textContent.length} characters');

      // Even if extraction failed, still return the ProcessedFile with error message
      return ProcessedFile.text(
        originalPath: filePath,
        fileName: fileName,
        textContent: textContent,
        fileSizeBytes: fileSize,
        type: FileType.pdf,
        mimeType: 'application/pdf',
        metadata: metadata,
      );
    } catch (e) {
      AppLogger.error('PDF processing failed for $fileName', e);

      // Return a ProcessedFile with error information instead of throwing
      final errorMessage =
          'Failed to process PDF file: $e\n\nFile: $fileName (${FileUtils.formatFileSize(fileSize)})';

      return ProcessedFile.text(
        originalPath: filePath,
        fileName: fileName,
        textContent: errorMessage,
        fileSizeBytes: fileSize,
        type: FileType.pdf,
        mimeType: 'application/pdf',
        metadata: {
          'originalSize': fileSize,
          'textLength': errorMessage.length,
          'extractionMethod': 'syncfusion_pdf_chunked',
          'processingStatus': 'error',
          'error': e.toString(),
        },
      );
    }
  }

  /// Process a text file by reading its content
  static Future<ProcessedFile> _processTextFile(
    String filePath,
    String fileName,
    int fileSize,
    FileType fileType,
  ) async {
    if (fileSize > maxTextSizeBytes) {
      throw FileSystemException(
        'Text file too large (${FileUtils.formatFileSize(fileSize)}). Maximum size is ${FileUtils.formatFileSize(maxTextSizeBytes)}',
        filePath,
      );
    }

    try {
      final file = File(filePath);
      String textContent;

      // Try to read as UTF-8 first, fall back to latin1 if needed
      try {
        textContent = await file.readAsString(encoding: utf8);
      } catch (e) {
        AppLogger.warning('UTF-8 decoding failed for $fileName, trying latin1');
        textContent = await file.readAsString(encoding: latin1);
      }

      final extension = _getFileExtension(filePath);
      final mimeType = _getMimeType(extension);

      final metadata = {
        'originalSize': fileSize,
        'textLength': textContent.length,
        'encoding': 'utf8',
        'extension': extension,
      };

      AppLogger.info(
          'Text file processed: $fileName, ${textContent.length} characters');

      return ProcessedFile.text(
        originalPath: filePath,
        fileName: fileName,
        textContent: textContent,
        fileSizeBytes: fileSize,
        type: fileType,
        mimeType: mimeType,
        metadata: metadata,
      );
    } catch (e) {
      throw FileSystemException('Failed to process text file: $e', filePath);
    }
  }

  /// Get file extension in lowercase (delegates to FileUtils)
  static String _getFileExtension(String filePath) {
    return FileUtils.getFileExtension(filePath);
  }

  /// Get MIME type for file extension
  static String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'json':
        return 'application/json';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'html':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'ts':
        return 'application/typescript';
      case 'dart':
        return 'application/dart';
      case 'py':
        return 'text/x-python';
      case 'java':
        return 'text/x-java';
      case 'cpp':
      case 'c':
        return 'text/x-c++src';
      case 'xml':
        return 'application/xml';
      case 'yaml':
      case 'yml':
        return 'application/yaml';
      default:
        return 'application/octet-stream';
    }
  }

  /// Extract text from PDF using Syncfusion with chunking and progress reporting
  static Future<String> _extractTextFromPdfInChunks(
    String filePath,
    String fileName, {
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    PdfDocument? document;
    try {
      if (isCancelled?.call() ?? false) return '';
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      final buffer = StringBuffer();
      const chunkSize = 10; // Process 10 pages at a time

      AppLogger.info(
          'PDF has $pageCount pages, extracting text in chunks of $chunkSize...');

      for (int i = 0; i < pageCount; i += chunkSize) {
        if (isCancelled?.call() ?? false) {
          AppLogger.info('PDF text extraction cancelled.');
          return '';
        }
        final startPage = i;
        final endPage = (i + chunkSize > pageCount) ? pageCount - 1 : i + chunkSize - 1;

        try {
          // Use compute to run this intensive operation in a separate isolate
          final pageText = await compute(
            _extractPageRange,
            {
              'bytes': bytes,
              'startPageIndex': startPage,
              'endPageIndex': endPage,
            },
          );

          if (pageText.trim().isNotEmpty) {
            buffer.write(pageText);
          }

          // Report progress
          final progress = (endPage + 1) / pageCount;
          onProgress?.call(progress);

          // Yield to the event loop to prevent UI freezing
          await Future.delayed(Duration.zero);
        } catch (e) {
          AppLogger.warning('Error extracting text from pages ${startPage + 1}-${endPage + 1}: $e');
        }
      }

      final extractedText = buffer.toString().trim();
      AppLogger.info(
          'PDF text extraction completed: ${extractedText.length} characters extracted');

      if (extractedText.isEmpty) {
        return 'This appears to be a scanned or image-based PDF. Text extraction is limited.';
      }

      return extractedText;
    } catch (e) {
      AppLogger.error('Error extracting text from PDF', e);
      return 'Error extracting text from PDF. The file may be corrupted or password-protected.';
    } finally {
      document?.dispose();
    }
  }

  /// Helper function to extract text from a range of pages in an isolate
  static String _extractPageRange(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int startPageIndex = params['startPageIndex'];
    final int endPageIndex = params['endPageIndex'];
    final buffer = StringBuffer();

    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      for (int i = startPageIndex; i <= endPageIndex; i++) {
        final pageText = extractor.extractText(startPageIndex: startPageIndex, endPageIndex: endPageIndex);
        if (pageText.trim().isNotEmpty) {
          buffer.write('Page ${i + 1}:\n$pageText\n\n');
        }
      }
    } catch (e) {
      // Log or handle error if needed
    } finally {
      document?.dispose();
    }

    return buffer.toString();
  }

  /// Get supported file extensions as a formatted string
  static String getSupportedExtensions() {
    final allExtensions = [
      ...FileUtils.imageExtensions,
      ...FileUtils.textExtensions,
      ...FileUtils.sourceCodeExtensions,
      ...FileUtils.jsonExtensions,
      'pdf',
    ];
    allExtensions.sort();
    return allExtensions.join(', ');
  }

  /// Check if file size is within limits
  static Future<bool> isFileSizeValid(String filePath, int fileSize) async {
    final fileType = await getFileType(filePath);
    switch (fileType) {
      case FileType.image:
        return fileSize <= maxImageSizeBytes;
      case FileType.pdf:
        return fileSize <= maxPdfSizeBytes;
      case FileType.text:
      case FileType.sourceCode:
      case FileType.json:
        return fileSize <= maxTextSizeBytes;
      default:
        return false;
    }
  }
}
