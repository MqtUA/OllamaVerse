import '../utils/file_utils.dart';

/// Represents different types of files that can be processed
enum FileType {
  image,
  pdf,
  text,
  sourceCode,
  json,
  unknown,
}

/// Content extracted from a file for AI processing
class ProcessedFile {
  final String originalPath;
  final String fileName;
  final FileType type;
  final String? textContent; // For PDFs, text files, source code
  final String? base64Content; // For images
  final int fileSizeBytes;
  final DateTime processedAt;
  final String? mimeType;
  final Map<String, dynamic>? metadata; // Additional file metadata
  final bool isCancelled;

  const ProcessedFile({
    required this.originalPath,
    required this.fileName,
    required this.type,
    this.textContent,
    this.base64Content,
    required this.fileSizeBytes,
    required this.processedAt,
    this.mimeType,
    this.metadata,
    this.isCancelled = false,
  });

  /// Create a ProcessedFile for text content
  factory ProcessedFile.text({
    required String originalPath,
    required String fileName,
    required String textContent,
    required int fileSizeBytes,
    FileType type = FileType.text,
    String? mimeType,
    Map<String, dynamic>? metadata,
  }) {
    return ProcessedFile(
      originalPath: originalPath,
      fileName: fileName,
      type: type,
      textContent: textContent,
      fileSizeBytes: fileSizeBytes,
      processedAt: DateTime.now(),
      mimeType: mimeType,
      metadata: metadata,
    );
  }

  /// Create a ProcessedFile for image content
  factory ProcessedFile.image({
    required String originalPath,
    required String fileName,
    required String base64Content,
    required int fileSizeBytes,
    String? mimeType,
    Map<String, dynamic>? metadata,
  }) {
    return ProcessedFile(
      originalPath: originalPath,
      fileName: fileName,
      type: FileType.image,
      base64Content: base64Content,
      fileSizeBytes: fileSizeBytes,
      processedAt: DateTime.now(),
      mimeType: mimeType,
      metadata: metadata,
    );
  }

  /// Create a ProcessedFile for a cancelled operation
  factory ProcessedFile.cancelled(String originalPath) {
    return ProcessedFile(
      originalPath: originalPath,
      fileName: FileUtils.getFileName(originalPath),
      type: FileType.unknown,
      fileSizeBytes: 0,
      processedAt: DateTime.now(),
      isCancelled: true,
    );
  }

  /// Check if this file contains text content
  bool get hasTextContent =>
      !isCancelled && textContent != null && textContent!.isNotEmpty;

  /// Check if this file contains image content
  bool get hasImageContent =>
      base64Content != null && base64Content!.isNotEmpty;

  /// Get human-readable file size (delegates to FileUtils for consistency)
  String get fileSizeFormatted => FileUtils.formatFileSize(fileSizeBytes);

  /// Create a copy with updated fields
  ProcessedFile copyWith({
    String? originalPath,
    String? fileName,
    FileType? type,
    String? textContent,
    String? base64Content,
    int? fileSizeBytes,
    DateTime? processedAt,
    String? mimeType,
    Map<String, dynamic>? metadata,
    bool? isCancelled,
  }) {
    return ProcessedFile(
      originalPath: originalPath ?? this.originalPath,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      base64Content: base64Content ?? this.base64Content,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      processedAt: processedAt ?? this.processedAt,
      mimeType: mimeType ?? this.mimeType,
      metadata: metadata ?? this.metadata,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'originalPath': originalPath,
      'fileName': fileName,
      'type': type.name,
      'textContent': textContent,
      'base64Content': base64Content,
      'fileSizeBytes': fileSizeBytes,
      'processedAt': processedAt.toIso8601String(),
      'mimeType': mimeType,
      'metadata': metadata,
      'isCancelled': isCancelled,
    };
  }

  /// Create from JSON
  factory ProcessedFile.fromJson(Map<String, dynamic> json) {
    return ProcessedFile(
      originalPath: json['originalPath'] as String,
      fileName: json['fileName'] as String,
      type: FileType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FileType.unknown,
      ),
      textContent: json['textContent'] as String?,
      base64Content: json['base64Content'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int,
      processedAt: DateTime.parse(json['processedAt'] as String),
      mimeType: json['mimeType'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isCancelled: json['isCancelled'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ProcessedFile(fileName: $fileName, type: $type, size: $fileSizeFormatted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcessedFile &&
        other.originalPath == originalPath &&
        other.fileName == fileName &&
        other.processedAt == processedAt;
  }

  @override
  int get hashCode {
    return originalPath.hashCode ^ fileName.hashCode ^ processedAt.hashCode;
  }
}
