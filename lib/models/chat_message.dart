import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> attachedFiles;
  final List<dynamic>? context;

  ChatMessage({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    List<String>? attachedFiles,
    this.context,
  }) : 
    id = id ?? const Uuid().v4(),
    timestamp = timestamp ?? DateTime.now(),
    attachedFiles = attachedFiles ?? [];

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      attachedFiles: List<String>.from(json['attachedFiles'] ?? []),
      context: json['context'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'attachedFiles': attachedFiles,
      'context': context,
    };
  }
}
