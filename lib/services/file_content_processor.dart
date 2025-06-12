import 'dart:convert';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/processed_file.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

/// Service for processing different file types and extracting content for AI analysis
class FileContentProcessor {
  // File size limits (in bytes)
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB for images
  static const int maxTextSizeBytes = 5 * 1024 * 1024; // 5MB for text files
  static const int maxPdfSizeBytes = 20 * 1024 * 1024; // 20MB for PDFs

  // Use shared extension lists from FileUtils (avoiding duplication)

  /// Check if a file can be processed by this service
  static bool canProcessFile(String filePath) {
    final extension = _getFileExtension(filePath);
    return FileUtils.imageExtensions.contains(extension) ||
        FileUtils.textExtensions.contains(extension) ||
        FileUtils.sourceCodeExtensions.contains(extension) ||
        FileUtils.jsonExtensions.contains(extension) ||
        extension == 'pdf';
  }

  /// Get the file type based on extension
  static FileType getFileType(String filePath) {
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
      return FileType.unknown;
    }
  }

  /// Process a file and extract its content for AI analysis
  static Future<ProcessedFile> processFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File does not exist', filePath);
      }

      final fileName = FileUtils.getFileName(filePath);
      final fileSize = await file.length();
      final fileType = getFileType(filePath);

      AppLogger.info(
          'Processing file: $fileName (${fileType.name}, ${FileUtils.formatFileSize(fileSize)})');

      switch (fileType) {
        case FileType.image:
          return await _processImageFile(filePath, fileName, fileSize);
        case FileType.pdf:
          return await _processPdfFile(filePath, fileName, fileSize);
        case FileType.text:
        case FileType.sourceCode:
        case FileType.json:
          return await _processTextFile(filePath, fileName, fileSize, fileType);
        default:
          throw UnsupportedError('File type ${fileType.name} is not supported');
      }
    } catch (e) {
      AppLogger.error('Error processing file $filePath', e);
      rethrow;
    }
  }

  /// Process multiple files in batch
  static Future<List<ProcessedFile>> processFiles(
      List<String> filePaths) async {
    final List<ProcessedFile> processedFiles = [];
    final List<String> errors = [];

    for (final filePath in filePaths) {
      try {
        final processedFile = await processFile(filePath);
        processedFiles.add(processedFile);
        AppLogger.info('Successfully processed: ${processedFile.fileName}');
      } catch (e) {
        final fileName = FileUtils.getFileName(filePath);
        final error = 'Failed to process $fileName: $e';
        errors.add(error);
        AppLogger.error('File processing error', e);
      }
    }

    if (errors.isNotEmpty) {
      AppLogger.warning('Some files failed to process: ${errors.join(', ')}');
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

  /// Process a PDF file by extracting text content
  static Future<ProcessedFile> _processPdfFile(
      String filePath, String fileName, int fileSize) async {
    if (fileSize > maxPdfSizeBytes) {
      throw FileSystemException(
        'PDF file too large (${FileUtils.formatFileSize(fileSize)}). Maximum size is ${FileUtils.formatFileSize(maxPdfSizeBytes)}',
        filePath,
      );
    }

    try {
      AppLogger.info('Starting PDF text extraction for: $fileName');

      // Extract text from PDF using Syncfusion
      final textContent = await _extractTextFromPdf(filePath, fileName);

      final metadata = {
        'originalSize': fileSize,
        'textLength': textContent.length,
        'extractionMethod': 'syncfusion_pdf',
        'processingStatus':
            textContent.contains('Error extracting text from PDF')
                ? 'failed'
                : 'success',
      };

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
          'extractionMethod': 'syncfusion_pdf',
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

  /// Extract text from PDF using Syncfusion
  static Future<String> _extractTextFromPdf(
      String filePath, String fileName) async {
    try {
      final file = File(filePath);

      // Read PDF as binary data
      final bytes = await file.readAsBytes();

      // Load the PDF document with binary data
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Extract text from all pages
      String extractedText = '';
      final extractor = PdfTextExtractor(document);
      final pageCount = document.pages.count;

      AppLogger.info('PDF has $pageCount pages, extracting text...');

      for (int i = 0; i < pageCount; i++) {
        try {
          final pageText = extractor.extractText(startPageIndex: i);
          if (pageText.trim().isNotEmpty) {
            extractedText += 'Page ${i + 1}:\n$pageText\n\n';
          }

          // Force garbage collection after each page
          if (i % 5 == 0) {
            await Future.delayed(Duration.zero);
          }
        } catch (e) {
          AppLogger.warning('Error extracting text from page ${i + 1}: $e');
        }
      }

      // Close the document
      document.dispose();

      // Clean up extracted text
      extractedText = extractedText.trim();

      AppLogger.info(
          'PDF text extraction completed: ${extractedText.length} characters extracted');

      if (extractedText.isEmpty) {
        return 'This appears to be a scanned or image-based PDF. Text extraction is limited.';
      }

      return extractedText;
    } catch (e) {
      AppLogger.error('Error extracting text from PDF', e);
      return 'Error extracting text from PDF. The file may be corrupted or password-protected.';
    }
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
  static bool isFileSizeValid(String filePath, int fileSize) {
    final fileType = getFileType(filePath);
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
