import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'logger.dart';
import 'package:flutter/material.dart';

class FileUtils {
  // Constants for file handling
  static const int maxFileSizeMB = 10; // Maximum file size in MB
  static const List<String> allowedExtensions = [
    'txt', 'md', 'csv', 'log', 'readme', 'rtf', // Text files
    'json', 'jsonl', 'geojson', // JSON files
    'dart',
    'py',
    'js',
    'ts',
    'java',
    'cpp',
    'c',
    'h',
    'hpp',
    'cs',
    'php',
    'rb',
    'go',
    'rs',
    'swift',
    'kt',
    'm',
    'mm',
    'sh',
    'bat',
    'ps1',
    'sql',
    'html',
    'css',
    'scss',
    'sass',
    'xml',
    'yaml',
    'yml',
    'toml',
    'ini',
    'conf',
    'cfg', // Source code and config files
    'pdf', // PDF files
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'svg' // Image files
  ];

  // Pick files from device
  static Future<List<String>> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any, // Changed from FileType.custom to allow all files
        // allowedExtensions: allowedExtensions, // Removed extension restriction
      );

      if (result != null) {
        List<String> savedPaths = [];

        // Save picked files to app directory
        for (var file in result.files) {
          if (file.path != null) {
            // Check file size
            final fileSize = await File(file.path!).length();
            final sizeInMB = fileSize / (1024 * 1024);

            if (sizeInMB > maxFileSizeMB) {
              AppLogger.warning(
                'File ${file.name} exceeds size limit of ${maxFileSizeMB}MB',
              );
              continue;
            }

            // Enhanced file compatibility check
            final isCompatible = await _isFileCompatible(file.path!, file.name);
            if (!isCompatible) {
              AppLogger.warning(
                'File ${file.name} is not compatible (appears to be binary and too large)',
              );
              continue;
            }

            final savedPath = await saveFileToAppDirectory(
              File(file.path!),
              file.name,
            );
            if (savedPath != null) {
              savedPaths.add(savedPath);
            }
          }
        }

        return savedPaths;
      }

      return [];
    } catch (e) {
      AppLogger.error('Error picking files', e);
      return [];
    }
  }

  /// Enhanced compatibility check for any file type
  static Future<bool> _isFileCompatible(
      String filePath, String fileName) async {
    try {
      final extension = getFileExtension(filePath);

      // Known compatible extensions are always allowed
      if (allowedExtensions.contains(extension)) {
        return true;
      }

      // For unknown extensions or no extension, check if it's likely a text file
      final isLikelyText = await isLikelyTextFile(filePath);
      if (isLikelyText) {
        AppLogger.info(
            'Detected text content in file with unknown/no extension: $fileName');
        return true;
      }

      // Check if it's a small binary file that might be worth trying
      final file = File(filePath);
      final fileSize = await file.length();

      // Allow small files under 1MB regardless of type for user convenience
      if (fileSize < 1024 * 1024) {
        AppLogger.info(
            'Allowing small file regardless of type: $fileName (${formatFileSize(fileSize)})');
        return true;
      }

      AppLogger.info(
          'File $fileName rejected: appears to be large binary file');
      return false;
    } catch (e) {
      AppLogger.error('Error checking file compatibility for $fileName', e);
      return false; // Err on the side of caution
    }
  }

  // Save file to app directory with memory optimization
  static Future<String?> saveFileToAppDirectory(
    File file,
    String fileName,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');

      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }

      // Generate unique filename to avoid collisions
      final uniqueId = const Uuid().v4();
      final savedPath = '${attachmentsDir.path}/$uniqueId-$fileName';

      // Copy file in chunks
      final input = file.openRead();
      final output = File(savedPath).openWrite();
      await input.pipe(output);

      return savedPath;
    } catch (e) {
      AppLogger.error('Error saving file', e);
      return null;
    }
  }

  // Clean up old files with memory optimization
  static Future<void> cleanupOldFiles({
    Duration maxAge = const Duration(days: 7),
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');

      if (!await attachmentsDir.exists()) {
        return;
      }

      final now = DateTime.now();
      await for (final entity in attachmentsDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age > maxAge) {
            await entity.delete();
            AppLogger.info('Deleted old file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error cleaning up old files', e);
    }
  }

  // Get file name from path
  static String getFileName(String filePath) {
    return filePath.split('/').last.split('\\').last;
  }

  // Get file extension
  static String getFileExtension(String filePath) {
    final fileName = getFileName(filePath);
    return fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  }

  // Get file icon based on extension
  static IconData getFileIcon(String filePath) {
    final ext = getFileExtension(filePath);
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Extended file type detection (moved from FileContentProcessor for better coverage)

  // Supported file extensions (comprehensive list)
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'tiff',
    // SVG moved to text extensions since it's XML-based text
  ];

  static const List<String> textExtensions = [
    'txt',
    'md',
    'csv',
    'log',
    'readme',
    'rtf',
    'svg', // SVG is XML-based text content, not binary image
  ];

  static const List<String> sourceCodeExtensions = [
    'dart',
    'py',
    'js',
    'ts',
    'java',
    'cpp',
    'c',
    'h',
    'hpp',
    'cs',
    'php',
    'rb',
    'go',
    'rs',
    'swift',
    'kt',
    'm',
    'mm',
    'sh',
    'bat',
    'ps1',
    'sql',
    'html',
    'css',
    'scss',
    'sass',
    'xml',
    'yaml',
    'yml',
    'toml',
    'ini',
    'conf',
    'cfg'
  ];

  static const List<String> jsonExtensions = ['json', 'jsonl', 'geojson'];

  // Check if file is an image
  static bool isImageFile(String filePath) {
    final ext = getFileExtension(filePath);
    return imageExtensions.contains(ext);
  }

  // Check if file is a PDF
  static bool isPdfFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ext == 'pdf';
  }

  // Check if file is a text file (includes source code and JSON)
  static bool isTextFile(String filePath) {
    final ext = getFileExtension(filePath);
    return textExtensions.contains(ext) ||
        sourceCodeExtensions.contains(ext) ||
        jsonExtensions.contains(ext);
  }

  // Check if file is source code
  static bool isSourceCodeFile(String filePath) {
    final ext = getFileExtension(filePath);
    return sourceCodeExtensions.contains(ext);
  }

  // Check if file is JSON
  static bool isJsonFile(String filePath) {
    final ext = getFileExtension(filePath);
    return jsonExtensions.contains(ext);
  }

  /// Format file size for human-readable display (consolidated utility)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Heuristically checks if a file is likely a text file by examining its initial bytes.
  /// This is useful for files without a recognized text extension.
  static Future<bool> isLikelyTextFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Read the first 8KB (8192 bytes) of the file for better detection
      final fileSize = await file.length();
      final sampleSize = fileSize < 8192 ? fileSize : 8192;

      if (sampleSize == 0) return false;

      final randomAccessFile = await file.open();
      List<int> bytes;
      try {
        bytes = await randomAccessFile.read(sampleSize);
      } finally {
        await randomAccessFile.close();
      }

      if (bytes.isEmpty) return false;

      // Check for common text file signatures/BOMs
      if (_hasTextFileSignature(bytes)) {
        return true;
      }

      // Enhanced character analysis
      return _analyzeFileContent(bytes);
    } catch (e) {
      AppLogger.warning('Error checking if file is likely text: $e');
      return false;
    }
  }

  /// Check for text file signatures and BOMs
  static bool _hasTextFileSignature(List<int> bytes) {
    if (bytes.length < 3) return false;

    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return true;
    }

    // UTF-16 BOMs
    if (bytes.length >= 2) {
      if ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF)) {
        return true;
      }
    }

    // UTF-32 BOMs
    if (bytes.length >= 4) {
      if ((bytes[0] == 0xFF &&
              bytes[1] == 0xFE &&
              bytes[2] == 0x00 &&
              bytes[3] == 0x00) ||
          (bytes[0] == 0x00 &&
              bytes[1] == 0x00 &&
              bytes[2] == 0xFE &&
              bytes[3] == 0xFF)) {
        return true;
      }
    }

    return false;
  }

  /// Enhanced content analysis for text detection
  static bool _analyzeFileContent(List<int> bytes) {
    if (bytes.isEmpty) return false;

    int nullByteCount = 0;
    int printableAsciiCount = 0;
    int unicodeCount = 0;
    int controlCharCount = 0;
    int lineBreakCount = 0;

    for (int i = 0; i < bytes.length; i++) {
      final byte = bytes[i];

      if (byte == 0) {
        nullByteCount++;
      } else if (byte == 0x0A || byte == 0x0D) {
        // Line breaks
        lineBreakCount++;
        printableAsciiCount++;
      } else if (byte == 0x09) {
        // Tabs
        printableAsciiCount++;
      } else if (byte >= 0x20 && byte <= 0x7E) {
        // Printable ASCII
        printableAsciiCount++;
      } else if (byte >= 0x80) {
        // Potential Unicode (UTF-8 continuation bytes)
        unicodeCount++;
      } else if (byte < 0x20) {
        // Control characters (excluding already handled ones)
        controlCharCount++;
      }
    }

    final totalBytes = bytes.length;

    // Binary file indicators
    if (nullByteCount > (totalBytes * 0.01)) {
      // More than 1% null bytes - likely binary
      return false;
    }

    if (controlCharCount > (totalBytes * 0.05)) {
      // More than 5% control characters - likely binary
      return false;
    }

    // Text file indicators
    final textCharacters = printableAsciiCount + unicodeCount;
    final textPercentage = textCharacters / totalBytes;

    // If more than 80% of characters are text-like, consider it text
    if (textPercentage > 0.80) {
      return true;
    }

    // Additional heuristics for specific file types
    if (_hasTextFilePatterns(bytes)) {
      return true;
    }

    // If we have line breaks and reasonable text content, it's likely text
    if (lineBreakCount > 0 && textPercentage > 0.60) {
      return true;
    }

    return false;
  }

  /// Check for common text file patterns
  static bool _hasTextFilePatterns(List<int> bytes) {
    final content = String.fromCharCodes(bytes.where((b) => b != 0));
    final lowerContent = content.toLowerCase();

    // Common text file patterns
    final textPatterns = [
      // Programming language indicators
      RegExp(
          r'\b(function|class|import|export|var|let|const|def|if|else|for|while)\b'),
      // Markup language indicators
      RegExp(r'<[a-zA-Z][^>]*>|&[a-zA-Z]+;'),
      // Configuration file indicators
      RegExp(r'^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*[=:]\s*', multiLine: true),
      // Documentation indicators
      RegExp(r'^\s*#+\s+|^\s*\*\s+|^\s*-\s+', multiLine: true),
      // JSON-like patterns
      RegExp(r'[{}\[\]":]'),
      // Log file patterns
      RegExp(r'\d{4}-\d{2}-\d{2}|\d{2}:\d{2}:\d{2}'),
      // Common file extensions in content
      RegExp(r'\.[a-zA-Z]{2,4}\b'),
    ];

    for (final pattern in textPatterns) {
      if (pattern.hasMatch(lowerContent)) {
        return true;
      }
    }

    // Check for common programming language keywords
    final keywords = [
      'function',
      'class',
      'import',
      'export',
      'var',
      'let',
      'const',
      'def',
      'if',
      'else',
      'for',
      'while',
      'return',
      'public',
      'private',
      'static',
      'void',
      'string',
      'int',
      'bool',
      'true',
      'false',
      'null',
      'undefined',
      'console',
      'print',
      'echo',
      'include',
      'require'
    ];

    int keywordCount = 0;
    for (final keyword in keywords) {
      if (lowerContent.contains(keyword)) {
        keywordCount++;
      }
    }

    // If we find multiple programming keywords, it's likely source code
    if (keywordCount >= 2) {
      return true;
    }

    return false;
  }
}
