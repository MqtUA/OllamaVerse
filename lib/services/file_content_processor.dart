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

    // Check known extensions first
    if (FileUtils.imageExtensions.contains(extension) ||
        FileUtils.textExtensions.contains(extension) ||
        FileUtils.sourceCodeExtensions.contains(extension) ||
        FileUtils.jsonExtensions.contains(extension) ||
        extension == 'pdf') {
      return true;
    }

    // For unknown extensions or files without extensions, check if it's text
    if (extension.isEmpty || !_isKnownExtension(extension)) {
      final isLikelyText = await FileUtils.isLikelyTextFile(filePath);
      if (isLikelyText) {
        AppLogger.info(
            'File with unknown/no extension detected as text: ${FileUtils.getFileName(filePath)}');
        return true;
      }
    }

    return false;
  }

  /// Check if an extension is in our known lists
  static bool _isKnownExtension(String extension) {
    return FileUtils.imageExtensions.contains(extension) ||
        FileUtils.textExtensions.contains(extension) ||
        FileUtils.sourceCodeExtensions.contains(extension) ||
        FileUtils.jsonExtensions.contains(extension) ||
        extension == 'pdf';
  }

  /// Get the file type based on extension and content analysis
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
    } else {
      // For unknown extensions or no extension, analyze content
      final isLikelyText = await FileUtils.isLikelyTextFile(filePath);
      if (isLikelyText) {
        // Try to determine if it's source code vs plain text
        final fileName = FileUtils.getFileName(filePath);
        if (await _isLikelySourceCode(filePath, fileName)) {
          AppLogger.info(
              'Unknown extension file detected as source code: $fileName');
          return FileType.sourceCode;
        } else if (await _isLikelyJson(filePath)) {
          AppLogger.info('Unknown extension file detected as JSON: $fileName');
          return FileType.json;
        } else {
          AppLogger.info('Unknown extension file detected as text: $fileName');
          return FileType.text;
        }
      } else {
        return FileType.unknown;
      }
    }
  }

  /// Analyze if a file without extension is likely source code
  static Future<bool> _isLikelySourceCode(
      String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // Don't analyze very large files for performance
      if (fileSize > 1024 * 1024) return false; // 1MB limit

      final content = await file.readAsString();

      // Check for common source code patterns
      final codePatterns = [
        RegExp(r'\b(function|class|import|export|module|package)\s*[({]'),
        RegExp(r'\b(if|else|for|while|switch|case)\s*[({]'),
        RegExp(
            r'\b(var|let|const|def|int|string|bool|void|public|private|static)\s+'),
        RegExp(r'[;{}]\s*$',
            multiLine: true), // Statements ending with semicolons/braces
        RegExp(r'^\s*//|^\s*/\*|^\s*#', multiLine: true), // Code comments
        RegExp(r'=>|->|::|\.\.\.'), // Modern language operators
      ];

      int patternMatches = 0;
      for (final pattern in codePatterns) {
        if (pattern.hasMatch(content)) {
          patternMatches++;
        }
      }

      // Also check filename patterns that suggest source code
      final fileName = FileUtils.getFileName(filePath).toLowerCase();
      final codeFilePatterns = [
        'makefile',
        'dockerfile',
        'rakefile',
        'gemfile',
        'podfile',
        'cmakelists',
        '.gitignore',
        '.editorconfig',
        '.prettierrc',
      ];

      for (final pattern in codeFilePatterns) {
        if (fileName.contains(pattern)) {
          patternMatches += 2; // Higher weight for filename patterns
        }
      }

      return patternMatches >= 2;
    } catch (e) {
      AppLogger.warning('Error analyzing if file is source code: $e');
      return false;
    }
  }

  /// Analyze if a file without extension is likely JSON
  static Future<bool> _isLikelyJson(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // Don't analyze very large files for performance
      if (fileSize > 1024 * 1024) return false; // 1MB limit

      final content = await file.readAsString();
      final trimmedContent = content.trim();

      // Basic JSON structure check
      if ((trimmedContent.startsWith('{') && trimmedContent.endsWith('}')) ||
          (trimmedContent.startsWith('[') && trimmedContent.endsWith(']'))) {
        try {
          jsonDecode(content);
          return true;
        } catch (e) {
          // Not valid JSON
          return false;
        }
      }

      return false;
    } catch (e) {
      AppLogger.warning('Error analyzing if file is JSON: $e');
      return false;
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

  /// Process a text file by reading its content with comprehensive encoding support
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

      // Enhanced encoding detection with comprehensive support
      final bytes = await file.readAsBytes();

      // Step 1: Check for Byte Order Marks (BOMs)
      final encoding = await _detectEncodingFromBOM(bytes);
      if (encoding != null) {
        try {
          switch (encoding['name']) {
            case 'utf-8-bom':
              // Remove UTF-8 BOM (EF BB BF) and decode
              final contentBytes = bytes.sublist(3);
              textContent = utf8.decode(contentBytes);
              actualEncoding = 'utf-8-bom';
              break;
            case 'utf-16le':
              // Remove UTF-16 LE BOM (FF FE) and decode
              final contentBytes = bytes.sublist(2);
              textContent = String.fromCharCodes(contentBytes);
              actualEncoding = 'utf-16le';
              break;
            case 'utf-16be':
              // Remove UTF-16 BE BOM (FE FF) and convert byte order
              final contentBytes = bytes.sublist(2);
              final utf16Chars = <int>[];
              for (int i = 0; i < contentBytes.length; i += 2) {
                if (i + 1 < contentBytes.length) {
                  utf16Chars.add((contentBytes[i] << 8) | contentBytes[i + 1]);
                }
              }
              textContent = String.fromCharCodes(utf16Chars);
              actualEncoding = 'utf-16be';
              break;
            case 'utf-32le':
              // UTF-32 LE
              final contentBytes = bytes.sublist(4);
              textContent = _decodeUtf32LE(contentBytes);
              actualEncoding = 'utf-32le';
              break;
            case 'utf-32be':
              // UTF-32 BE
              final contentBytes = bytes.sublist(4);
              textContent = _decodeUtf32BE(contentBytes);
              actualEncoding = 'utf-32be';
              break;
            default:
              throw Exception('Unknown BOM encoding: ${encoding['name']}');
          }
        } catch (e) {
          AppLogger.warning(
              'BOM-based decoding failed for $fileName: $e, trying heuristic detection');
          // Fall through to heuristic detection
          textContent = await _detectAndDecodeWithHeuristics(file, bytes);
          actualEncoding = 'heuristic-fallback';
        }
      } else {
        // Step 2: No BOM detected, use heuristic encoding detection
        textContent = await _detectAndDecodeWithHeuristics(file, bytes);
        actualEncoding = await _determineActualEncoding(file, bytes);
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
      // Use FileType-based MIME type for files without extension or unknown extensions
      final mimeType = extension.isEmpty || !_isKnownExtension(extension)
          ? _getMimeTypeFromFileType(fileType)
          : _getMimeType(extension);

      final metadata = {
        'originalSize': fileSize,
        'textLength': textContent.length,
        'encoding': actualEncoding,
        'extension': extension,
        'hasValidContent': textContent.isNotEmpty,
        'contentValidation':
            fileType == FileType.json ? 'json-validated' : 'text-content',
        'detectionMethod': extension.isEmpty || !_isKnownExtension(extension)
            ? 'content-analysis'
            : 'extension-based',
        'encodingMethod': encoding != null ? 'bom-detected' : 'heuristic',
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

  /// Detect encoding from Byte Order Mark (BOM)
  static Future<Map<String, String>?> _detectEncodingFromBOM(
      List<int> bytes) async {
    if (bytes.length < 2) return null;

    // Check for UTF-32 BOMs (must check before UTF-16)
    if (bytes.length >= 4) {
      if (bytes[0] == 0x00 &&
          bytes[1] == 0x00 &&
          bytes[2] == 0xFE &&
          bytes[3] == 0xFF) {
        return {'name': 'utf-32be', 'bomLength': '4'};
      }
      if (bytes[0] == 0xFF &&
          bytes[1] == 0xFE &&
          bytes[2] == 0x00 &&
          bytes[3] == 0x00) {
        return {'name': 'utf-32le', 'bomLength': '4'};
      }
    }

    // Check for UTF-16 BOMs
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return {'name': 'utf-16le', 'bomLength': '2'};
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return {'name': 'utf-16be', 'bomLength': '2'};
    }

    // Check for UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return {'name': 'utf-8-bom', 'bomLength': '3'};
    }

    return null;
  }

  /// Heuristic encoding detection and decoding
  static Future<String> _detectAndDecodeWithHeuristics(
      File file, List<int> bytes) async {
    // Try encodings in order of preference/likelihood
    final encodingsToTry = [
      () async => await file.readAsString(encoding: utf8),
      () async => await file.readAsString(encoding: latin1),
      () async => _decodeWindows1252(bytes),
      () async => _decodeAscii(bytes),
      () async => _decodeIso88591(bytes),
    ];

    for (int i = 0; i < encodingsToTry.length; i++) {
      try {
        final content = await encodingsToTry[i]();

        // Validate the decoded content
        if (_isValidTextContent(content)) {
          return content;
        }
      } catch (e) {
        // Continue to next encoding
        AppLogger.debug('Encoding attempt ${i + 1} failed, trying next...');
      }
    }

    // Final fallback: force latin1 (should always work)
    try {
      return await file.readAsString(encoding: latin1);
    } catch (e) {
      throw Exception('All encoding attempts failed: $e');
    }
  }

  /// Determine the actual encoding used for successful decoding
  static Future<String> _determineActualEncoding(
      File file, List<int> bytes) async {
    try {
      // Test UTF-8 validity
      await file.readAsString(encoding: utf8);
      return 'utf-8';
    } catch (e) {
      // Not valid UTF-8, check for Windows-1252 patterns
      if (_hasWindows1252Patterns(bytes)) {
        return 'windows-1252';
      }

      // Check for pure ASCII
      if (_isPureAscii(bytes)) {
        return 'ascii';
      }

      // Default to latin1
      return 'latin1';
    }
  }

  /// Decode UTF-32 Little Endian
  static String _decodeUtf32LE(List<int> bytes) {
    final codePoints = <int>[];
    for (int i = 0; i < bytes.length; i += 4) {
      if (i + 3 < bytes.length) {
        final codePoint = bytes[i] |
            (bytes[i + 1] << 8) |
            (bytes[i + 2] << 16) |
            (bytes[i + 3] << 24);
        codePoints.add(codePoint);
      }
    }
    return String.fromCharCodes(codePoints);
  }

  /// Decode UTF-32 Big Endian
  static String _decodeUtf32BE(List<int> bytes) {
    final codePoints = <int>[];
    for (int i = 0; i < bytes.length; i += 4) {
      if (i + 3 < bytes.length) {
        final codePoint = (bytes[i] << 24) |
            (bytes[i + 1] << 16) |
            (bytes[i + 2] << 8) |
            bytes[i + 3];
        codePoints.add(codePoint);
      }
    }
    return String.fromCharCodes(codePoints);
  }

  /// Decode Windows-1252 (CP1252)
  static String _decodeWindows1252(List<int> bytes) {
    // Windows-1252 character map for 0x80-0x9F range
    const windows1252Map = {
      0x80: 0x20AC, // €
      0x82: 0x201A, // ‚
      0x83: 0x0192, // ƒ
      0x84: 0x201E, // „
      0x85: 0x2026, // …
      0x86: 0x2020, // †
      0x87: 0x2021, // ‡
      0x88: 0x02C6, // ˆ
      0x89: 0x2030, // ‰
      0x8A: 0x0160, // Š
      0x8B: 0x2039, // ‹
      0x8C: 0x0152, // Œ
      0x8E: 0x017D, // Ž
      0x91: 0x2018, // '
      0x92: 0x2019, // '
      0x93: 0x201C, // "
      0x94: 0x201D, // "
      0x95: 0x2022, // •
      0x96: 0x2013, // –
      0x97: 0x2014, // —
      0x98: 0x02DC, // ˜
      0x99: 0x2122, // ™
      0x9A: 0x0161, // š
      0x9B: 0x203A, // ›
      0x9C: 0x0153, // œ
      0x9E: 0x017E, // ž
      0x9F: 0x0178, // Ÿ
    };

    final codePoints = <int>[];
    for (final byte in bytes) {
      if (byte >= 0x80 && byte <= 0x9F && windows1252Map.containsKey(byte)) {
        codePoints.add(windows1252Map[byte]!);
      } else {
        codePoints.add(byte);
      }
    }
    return String.fromCharCodes(codePoints);
  }

  /// Decode ASCII
  static String _decodeAscii(List<int> bytes) {
    // Validate all bytes are valid ASCII (0-127)
    for (final byte in bytes) {
      if (byte > 127) {
        throw Exception('Non-ASCII byte found: $byte');
      }
    }
    return String.fromCharCodes(bytes);
  }

  /// Decode ISO-8859-1 (identical to Latin-1 for single-byte)
  static String _decodeIso88591(List<int> bytes) {
    return String.fromCharCodes(bytes); // ISO-8859-1 is 1:1 with Unicode
  }

  /// Check if content is valid text (no excessive control characters or garbage)
  static bool _isValidTextContent(String content) {
    if (content.isEmpty) return false;

    // Count printable vs non-printable characters
    int printableCount = 0;
    int totalCount = 0;

    for (final char in content.runes) {
      totalCount++;
      if ((char >= 32 && char <= 126) || // ASCII printable
          char == 9 ||
          char == 10 ||
          char == 13 || // Tab, LF, CR
          char >= 160) {
        // Extended Unicode printable
        printableCount++;
      }
    }

    // Content should be at least 80% printable for text files
    return totalCount > 0 && (printableCount / totalCount) >= 0.8;
  }

  /// Check for Windows-1252 specific byte patterns
  static bool _hasWindows1252Patterns(List<int> bytes) {
    final windows1252Bytes = [
      0x80,
      0x82,
      0x83,
      0x84,
      0x85,
      0x86,
      0x87,
      0x88,
      0x89,
      0x8A,
      0x8B,
      0x8C,
      0x8E,
      0x91,
      0x92,
      0x93,
      0x94,
      0x95,
      0x96,
      0x97,
      0x98,
      0x99,
      0x9A,
      0x9B,
      0x9C,
      0x9E,
      0x9F
    ];

    return bytes.any((byte) => windows1252Bytes.contains(byte));
  }

  /// Check if content is pure ASCII
  static bool _isPureAscii(List<int> bytes) {
    return bytes.every((byte) => byte >= 0 && byte <= 127);
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
      case 'tiff':
        return 'image/tiff';
      case 'pdf':
        return 'application/pdf';
      case 'json':
      case 'jsonl':
      case 'geojson':
        return 'application/json';
      case 'txt':
      case 'log':
      case 'readme':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'html':
      case 'htm':
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
      case 'cc':
      case 'cxx':
        return 'text/x-c++src';
      case 'c':
        return 'text/x-csrc';
      case 'h':
      case 'hpp':
        return 'text/x-chdr';
      case 'cs':
        return 'text/x-csharp';
      case 'php':
        return 'text/x-php';
      case 'rb':
        return 'text/x-ruby';
      case 'go':
        return 'text/x-go';
      case 'rs':
        return 'text/x-rust';
      case 'swift':
        return 'text/x-swift';
      case 'kt':
        return 'text/x-kotlin';
      case 'xml':
      case 'svg':
        return 'application/xml';
      case 'yaml':
      case 'yml':
        return 'application/yaml';
      case 'toml':
        return 'application/toml';
      case 'ini':
      case 'conf':
      case 'cfg':
        return 'text/plain';
      case 'sh':
      case 'bash':
        return 'application/x-sh';
      case 'bat':
        return 'application/x-bat';
      case 'ps1':
        return 'application/x-powershell';
      case 'sql':
        return 'application/sql';
      case 'csv':
        return 'text/csv';
      case 'rtf':
        return 'application/rtf';
      case 'scss':
      case 'sass':
        return 'text/x-scss';
      case '':
        // For files without extensions, return generic text type
        return 'text/plain';
      default:
        // For unknown extensions, return generic binary type
        return 'application/octet-stream';
    }
  }

  /// Get MIME type based on file type (for files without recognized extensions)
  static String _getMimeTypeFromFileType(FileType fileType) {
    switch (fileType) {
      case FileType.text:
        return 'text/plain';
      case FileType.sourceCode:
        return 'text/x-source';
      case FileType.json:
        return 'application/json';
      case FileType.pdf:
        return 'application/pdf';
      case FileType.image:
        return 'image/jpeg'; // Default image type
      case FileType.unknown:
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
