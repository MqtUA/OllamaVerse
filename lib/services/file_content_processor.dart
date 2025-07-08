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
          processedFile = await _processTextFile(
              filePath, fileName, fileSize, resolvedFileType);
          break;
        default:
          throw UnsupportedError(
              'File type ${resolvedFileType.name} is not supported');
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

      // Basic image validation by checking file headers/magic bytes
      final extension = _getFileExtension(filePath);
      final isValidImage = _validateImageContent(bytes, extension);

      if (!isValidImage) {
        throw FileSystemException(
          'File appears to be corrupted or not a valid $extension image',
          filePath,
        );
      }

      final base64Content = base64Encode(bytes);

      // Get image metadata
      final mimeType = _getMimeType(extension);

      final metadata = {
        'originalSize': fileSize,
        'base64Size': base64Content.length,
        'compression': 'none',
        'validated': true,
        'imageFormat': extension,
      };

      AppLogger.info(
          'Image processed: $fileName, base64 size: $base64Content.length chars');

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

  /// Validate image content by checking file headers/magic bytes
  static bool _validateImageContent(List<int> bytes, String extension) {
    if (bytes.isEmpty) return false;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        // JPEG files start with FF D8 and end with FF D9
        return bytes.length >= 4 &&
            bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[bytes.length - 2] == 0xFF &&
            bytes[bytes.length - 1] == 0xD9;

      case 'png':
        // PNG files start with 89 50 4E 47 0D 0A 1A 0A
        return bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0D &&
            bytes[5] == 0x0A &&
            bytes[6] == 0x1A &&
            bytes[7] == 0x0A;

      case 'gif':
        // GIF files start with "GIF87a" or "GIF89a"
        return bytes.length >= 6 &&
            bytes[0] == 0x47 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x38 &&
            (bytes[4] == 0x37 || bytes[4] == 0x39) &&
            bytes[5] == 0x61;

      case 'bmp':
        // BMP files start with "BM"
        return bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D;

      case 'webp':
        // WebP files start with "RIFF" and contain "WEBP"
        return bytes.length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50;

      case 'tiff':
        // TIFF files start with "II*" (little endian) or "MM*" (big endian)
        return bytes.length >= 4 &&
            ((bytes[0] == 0x49 &&
                    bytes[1] == 0x49 &&
                    bytes[2] == 0x2A &&
                    bytes[3] == 0x00) ||
                (bytes[0] == 0x4D &&
                    bytes[1] == 0x4D &&
                    bytes[2] == 0x00 &&
                    bytes[3] == 0x2A));

      default:
        // For unknown formats, just check if file is not empty
        return bytes.isNotEmpty;
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
      String actualEncoding = 'unknown';

      // Enhanced encoding detection with BOM support
      final bytes = await file.readAsBytes();

      // Check for UTF-16 BOM
      if (bytes.length >= 2) {
        if ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
            (bytes[0] == 0xFE && bytes[1] == 0xFF)) {
          try {
            // Handle UTF-16 with BOM
            final bomLength = 2;
            final contentBytes = bytes.sublist(bomLength);
            if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
              // UTF-16 LE
              textContent = String.fromCharCodes(contentBytes);
              actualEncoding = 'utf-16le';
            } else {
              // UTF-16 BE - convert byte order
              final utf16Chars = <int>[];
              for (int i = 0; i < contentBytes.length; i += 2) {
                if (i + 1 < contentBytes.length) {
                  utf16Chars.add((contentBytes[i] << 8) | contentBytes[i + 1]);
                }
              }
              textContent = String.fromCharCodes(utf16Chars);
              actualEncoding = 'utf-16be';
            }
          } catch (e) {
            AppLogger.warning(
                'UTF-16 decoding failed for $fileName, trying UTF-8');
            textContent = await file.readAsString(encoding: utf8);
            actualEncoding = 'utf-8';
          }
        } else if (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) {
          // UTF-8 with BOM
          try {
            textContent = await file.readAsString(encoding: utf8);
            actualEncoding = 'utf-8-bom';
          } catch (e) {
            AppLogger.warning(
                'UTF-8 BOM decoding failed for $fileName, trying latin1');
            textContent = await file.readAsString(encoding: latin1);
            actualEncoding = 'latin1';
          }
        } else {
          // No BOM detected, try UTF-8 first, fall back to latin1
          try {
            textContent = await file.readAsString(encoding: utf8);
            actualEncoding = 'utf-8';
          } catch (e) {
            AppLogger.warning(
                'UTF-8 decoding failed for $fileName, trying latin1');
            try {
              textContent = await file.readAsString(encoding: latin1);
              actualEncoding = 'latin1';
            } catch (e2) {
              AppLogger.error('All encoding attempts failed for $fileName');
              throw FileSystemException(
                  'Failed to decode text file with any supported encoding: $e2',
                  filePath);
            }
          }
        }
      } else {
        // File too small to have BOM, try UTF-8 then latin1
        try {
          textContent = await file.readAsString(encoding: utf8);
          actualEncoding = 'utf-8';
        } catch (e) {
          AppLogger.warning(
              'UTF-8 decoding failed for $fileName, trying latin1');
          textContent = await file.readAsString(encoding: latin1);
          actualEncoding = 'latin1';
        }
      }

      // Validate content for specific file types
      if (fileType == FileType.json) {
        try {
          // Validate JSON content
          jsonDecode(textContent);
        } catch (e) {
          AppLogger.warning('Invalid JSON content in $fileName: $e');
          // Don't throw error, just log warning - let AI handle invalid JSON
        }
      }

      final extension = _getFileExtension(filePath);
      final mimeType = _getMimeType(extension);

      final metadata = {
        'originalSize': fileSize,
        'textLength': textContent.length,
        'encoding': actualEncoding, // Fix: Now shows actual encoding used
        'extension': extension,
        'hasValidContent': textContent.isNotEmpty,
        'contentValidation':
            fileType == FileType.json ? 'json-validated' : 'text-content',
      };

      AppLogger.info(
          'Text file processed: $fileName, $textContent.length characters, encoding: $actualEncoding');

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
      case 'svg':
        return 'text/svg+xml';
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
        final endPage =
            (i + chunkSize > pageCount) ? pageCount - 1 : i + chunkSize - 1;

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

          // Validate extracted text before adding to buffer
          if (pageText.trim().isNotEmpty &&
              !pageText.contains('Error extracting text from pages')) {
            buffer.write(pageText);
          } else if (pageText.contains('Error extracting text from pages')) {
            AppLogger.warning(
                'Extraction error in chunk ${startPage + 1}-${endPage + 1}: $pageText');
          }

          // Report progress
          final progress = (endPage + 1) / pageCount;
          onProgress?.call(progress);

          // Yield to the event loop to prevent UI freezing
          await Future.delayed(Duration.zero);
        } catch (e) {
          AppLogger.warning(
              'Error extracting text from pages ${startPage + 1}-${endPage + 1}: $e');
          // Continue processing other chunks even if one fails
        }
      }

      final extractedText = buffer.toString().trim();

      // Better validation of extracted content
      if (extractedText.isEmpty) {
        AppLogger.warning('No text extracted from PDF: $fileName');
        return 'This appears to be a scanned or image-based PDF. Text extraction is limited.';
      }

      // Check for suspicious patterns that might indicate extraction issues
      final lines = extractedText.split('\n');
      final nonEmptyLines =
          lines.where((line) => line.trim().isNotEmpty).toList();

      if (nonEmptyLines.length < 3) {
        AppLogger.warning(
            'Very little text extracted from PDF: $fileName ($nonEmptyLines.length lines)');
        return 'This PDF appears to contain minimal text content. Text extraction may be incomplete.';
      }

      AppLogger.info(
          'PDF text extraction completed: $extractedText.length characters extracted from $pageCount pages');

      return extractedText;
    } catch (e) {
      AppLogger.error('Error extracting text from PDF', e);
      return 'Error extracting text from PDF. The file may be corrupted, password-protected, or contain non-standard formatting.';
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
        // Fix: Extract text from individual page, not the entire range
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          buffer.write('Page ${i + 1}:\n$pageText\n\n');
        }
      }
    } catch (e) {
      // Log or handle error if needed - add error info to buffer for debugging
      buffer.write(
          'Error extracting text from pages ${startPageIndex + 1}-${endPageIndex + 1}: $e\n');
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
