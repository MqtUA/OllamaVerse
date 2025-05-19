import 'package:uuid/uuid.dart';
import 'chat_message.dart';

class Chat {
  final String id;
  final String title;
  final String modelName;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  Chat({
    String? id,
    required this.title,
    required this.modelName,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    messages = messages ?? [],
    createdAt = createdAt ?? DateTime.now(),
    lastUpdatedAt = lastUpdatedAt ?? DateTime.now();

  Chat copyWith({
    String? title,
    String? modelName,
    List<ChatMessage>? messages,
    DateTime? lastUpdatedAt,
  }) {
    return Chat(
      id: id,
      title: title ?? this.title,
      modelName: modelName ?? this.modelName,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
    );
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      title: json['title'],
      modelName: json['modelName'],
      messages: (json['messages'] as List)
          .map((msg) => ChatMessage.fromJson(msg))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'modelName': modelName,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }
}
