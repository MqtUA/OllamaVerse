import 'message.dart';
import 'chat_message.dart';

class Chat {
  final String id;
  String title;
  final String modelName;
  final List<Message> messages;
  final DateTime createdAt;
  DateTime lastUpdatedAt;

  Chat({
    required this.id,
    required this.title,
    required this.modelName,
    required this.messages,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  Chat copyWith({
    String? id,
    String? title,
    String? modelName,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      modelName: modelName ?? this.modelName,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  List<ChatMessage> toChatMessages() {
    return messages
        .map((message) => ChatMessage(
              id: message.id,
              content: message.content,
              isUser: message.role == MessageRole.user,
              timestamp: message.timestamp,
            ))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'modelName': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      title: json['title'] as String,
      modelName: json['modelName'] as String? ?? '',
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
    );
  }
}
