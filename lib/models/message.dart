import 'processed_file.dart';
import '../services/thinking_model_detection_service.dart';

enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isSystem;
  final List<ProcessedFile> processedFiles; // Files attached to this message
  final ThinkingContent?
      thinkingContent; // Extracted thinking content if available

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    List<ProcessedFile>? processedFiles,
    this.thinkingContent,
  })  : isSystem = role == MessageRole.system,
        processedFiles = processedFiles ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'processedFiles': processedFiles.map((file) => file.toJson()).toList(),
      'thinkingContent': thinkingContent != null
          ? {
              'originalResponse': thinkingContent!.originalResponse,
              'thinkingText': thinkingContent!.thinkingText,
              'finalAnswer': thinkingContent!.finalAnswer,
              'hasThinking': thinkingContent!.hasThinking,
              'thinkingStartIndex': thinkingContent!.thinkingStartIndex,
              'thinkingEndIndex': thinkingContent!.thinkingEndIndex,
            }
          : null,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    ThinkingContent? thinkingContent;
    if (json['thinkingContent'] != null) {
      final thinkingData = json['thinkingContent'] as Map<String, dynamic>;
      thinkingContent = ThinkingContent(
        originalResponse: thinkingData['originalResponse'] as String,
        thinkingText: thinkingData['thinkingText'] as String?,
        finalAnswer: thinkingData['finalAnswer'] as String,
        hasThinking: thinkingData['hasThinking'] as bool,
        thinkingStartIndex: thinkingData['thinkingStartIndex'] as int?,
        thinkingEndIndex: thinkingData['thinkingEndIndex'] as int?,
      );
    }

    return Message(
      id: json['id'] as String,
      content: json['content'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => MessageRole.user,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      processedFiles: json['processedFiles'] != null
          ? (json['processedFiles'] as List)
              .map((fileJson) =>
                  ProcessedFile.fromJson(fileJson as Map<String, dynamic>))
              .toList()
          : [],
      thinkingContent: thinkingContent,
    );
  }

  /// Check if this message has any attached files
  bool get hasFiles => processedFiles.isNotEmpty;

  /// Check if this message has image files
  bool get hasImages =>
      processedFiles.any((file) => file.type == FileType.image);

  /// Check if this message has text content
  bool get hasTextContent => processedFiles.any((file) => file.hasTextContent);

  /// Check if this message has text files (PDFs, documents, etc.)
  bool get hasTextFiles => processedFiles.any((file) => file.hasTextContent);

  /// Get all image files from this message
  List<ProcessedFile> get imageFiles =>
      processedFiles.where((file) => file.type == FileType.image).toList();

  /// Get all text files from this message
  List<ProcessedFile> get textFiles =>
      processedFiles.where((file) => file.hasTextContent).toList();

  /// Check if this message has thinking content
  bool get hasThinking => thinkingContent?.hasDisplayableThinking ?? false;

  /// Get the thinking text for display
  String? get thinkingText => thinkingContent?.thinkingText;

  /// Get the final answer (separate from thinking)
  String get finalAnswer {
    // If we have thinking content, return the stored final answer or the message content
    if (hasThinking) {
      // If thinkingContent has a non-empty finalAnswer, use it
      if (thinkingContent!.finalAnswer.isNotEmpty) {
        return thinkingContent!.finalAnswer;
      }
      // Otherwise, the message content should already be filtered
      return content;
    }

    // No thinking content, return original content
    return content;
  }

  /// Get a summary of the thinking for display
  String get thinkingSummary => thinkingContent?.thinkingSummary ?? '';

  /// Get content appropriate for display based on thinking availability
  String get displayContent => hasThinking ? finalAnswer : content;

  // UI Helper properties - for direct use in widgets instead of ChatMessage conversion

  /// UI helper: Check if this is a user message (for bubble alignment)
  bool get isUser => role == MessageRole.user;

  /// UI helper: Get file paths for display (compatibility with old UI code)
  List<String> get attachedFiles =>
      processedFiles.map((file) => file.originalPath).toList();

  /// UI helper: Get display-friendly attached file names
  List<String> get attachedFileNames =>
      processedFiles.map((file) => file.fileName).toList();

  /// Create a copy of this message with updated fields
  Message copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    List<ProcessedFile>? processedFiles,
    ThinkingContent? thinkingContent,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      processedFiles: processedFiles ?? this.processedFiles,
      thinkingContent: thinkingContent ?? this.thinkingContent,
    );
  }

  /// Create a copy of this message with thinking content extracted
  Message withThinkingContent() {
    if (role != MessageRole.assistant || content.isEmpty) {
      return this;
    }

    final extractedThinking =
        ThinkingModelDetectionService.extractThinkingContent(content);

    return copyWith(thinkingContent: extractedThinking);
  }

  @override
  String toString() {
    return 'Message(id: $id, role: $role, hasFiles: $hasFiles, content: ${content.length} chars)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.content == content &&
        other.role == role &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^ content.hashCode ^ role.hashCode ^ timestamp.hashCode;
  }
}
