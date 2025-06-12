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
    'txt',
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'gif',
  ];

  // Pick files from device
  static Future<List<String>> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
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

            // Check file extension
            final ext = getFileExtension(file.path!);
            if (!allowedExtensions.contains(ext)) {
              AppLogger.warning(
                'File ${file.name} has unsupported extension: $ext',
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
    'svg'
  ];

  static const List<String> textExtensions = [
    'txt',
    'md',
    'csv',
    'log',
    'readme',
    'rtf'
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
}
