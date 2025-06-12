import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'logger.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

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

  // Check if file is an image
  static bool isImageFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  // Check if file is a PDF
  static bool isPdfFile(String filePath) {
    final ext = getFileExtension(filePath);
    return ext == 'pdf';
  }

  // Check if file is a text file
  static bool isTextFile(String filePath) {
    final ext = getFileExtension(filePath);
    return [
      'txt',
      'md',
      'json',
      'csv',
      'html',
      'xml',
      'js',
      'py',
      'java',
      'c',
      'cpp',
      'h',
      'cs',
      'php',
      'rb',
    ].contains(ext);
  }

  // Read file content based on file type with chunked reading for large files
  static Future<String> readFileContent(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return '[File not found: ${getFileName(filePath)}]';
      }

      final fileSize = await file.length();
      final sizeInMB = fileSize / (1024 * 1024);

      if (sizeInMB > maxFileSizeMB) {
        return '[File too large: ${getFileName(filePath)}, Size: ${sizeInMB.toStringAsFixed(2)}MB]';
      }

      if (isPdfFile(filePath)) {
        return await extractTextFromPdf(filePath);
      } else if (isImageFile(filePath)) {
        return '[Image file: ${getFileName(filePath)}, Size: ${sizeInMB.toStringAsFixed(2)}MB]';
      } else {
        // Use chunked reading for text files
        final content = await _readFileInChunks(file);
        return 'File: ${getFileName(filePath)}\n\n$content';
      }
    } catch (e) {
      AppLogger.error('Error reading file content', e);
      return '[Error reading file: ${getFileName(filePath)}]';
    }
  }

  // Read file in chunks to prevent memory issues
  static Future<String> _readFileInChunks(File file) async {
    const chunkSize = 1024 * 1024; // 1MB chunks
    final fileSize = await file.length();
    final buffer = StringBuffer();
    var position = 0;

    while (position < fileSize) {
      final chunk = await file.openRead(position, position + chunkSize).first;
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      position += chunkSize;
    }

    return buffer.toString();
  }

  // Extract text from PDF with memory optimization
  static Future<String> extractTextFromPdf(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      final sizeInMB = fileSize / (1024 * 1024);

      if (sizeInMB > maxFileSizeMB) {
        return 'PDF file is too large (${sizeInMB.toStringAsFixed(2)}MB). Maximum size is ${maxFileSizeMB}MB.';
      }

      // Read PDF in chunks
      final bytes = await _readFileInChunks(file);
      final fileName = path.basename(filePath);

      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: utf8.encode(bytes));

      // Extract text from all pages with memory management
      String extractedText = '';
      PdfTextExtractor extractor = PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        String pageText = extractor.extractText(startPageIndex: i);
        extractedText += 'Page ${i + 1}:\n$pageText\n\n';

        // Force garbage collection after each page
        if (i % 5 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      // Close the document
      document.dispose();

      if (extractedText.trim().isEmpty) {
        return '[PDF File: $fileName, Size: ${sizeInMB.toStringAsFixed(2)}MB]\n\nThis appears to be a scanned or image-based PDF. Text extraction is limited.';
      }

      return 'Content extracted from PDF: $fileName\n\n$extractedText';
    } catch (e) {
      AppLogger.error('Error extracting text from PDF', e);
      return 'Error extracting text from PDF. The file may be corrupted or password-protected.';
    }
  }
}
