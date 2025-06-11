import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'logger.dart';

class FileUtils {
  // Constants for file handling
  static const int maxFileSizeMB = 50; // Maximum file size in MB
  static const List<String> allowedExtensions = [
    'pdf',
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
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
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

  // Save file to app directory
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
      final savedFile = await file.copy(
        '${attachmentsDir.path}/$uniqueId-$fileName',
      );

      return savedFile.path;
    } catch (e) {
      AppLogger.error('Error saving file', e);
      return null;
    }
  }

  // Clean up old files
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
      final files = await attachmentsDir.list().toList();

      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age > maxAge) {
            await file.delete();
            AppLogger.info('Deleted old file: ${file.path}');
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
  static String getFileIconName(String filePath) {
    final ext = getFileExtension(filePath);

    // Map common extensions to appropriate icons
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'word';
      case 'xls':
      case 'xlsx':
        return 'excel';
      case 'ppt':
      case 'pptx':
        return 'powerpoint';
      case 'txt':
        return 'text';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      case 'mp3':
      case 'wav':
      case 'ogg':
        return 'audio';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      case 'js':
      case 'py':
      case 'java':
      case 'cpp':
      case 'cs':
      case 'html':
      case 'css':
      case 'php':
        return 'code';
      default:
        return 'generic';
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

  // Extract text from PDF file using Syncfusion PDF library
  static Future<String> extractTextFromPdf(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      final sizeInMB = fileSize / (1024 * 1024);

      if (sizeInMB > maxFileSizeMB) {
        return 'PDF file is too large (${sizeInMB.toStringAsFixed(2)}MB). Maximum size is ${maxFileSizeMB}MB.';
      }

      final Uint8List bytes = await file.readAsBytes();
      final fileName = path.basename(filePath);

      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Extract text from all pages
      String extractedText = '';
      PdfTextExtractor extractor = PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        String pageText = extractor.extractText(startPageIndex: i);
        extractedText += 'Page ${i + 1}:\n$pageText\n\n';
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
