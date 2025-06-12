import 'message.dart';

class Chat {
  final String id;
  String title;
  final String modelName;
  final List<Message> messages;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  final List<int>?
      context; // Ollama context for maintaining conversation memory

  Chat({
    required this.id,
    required this.title,
    required this.modelName,
    required this.messages,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.context, // Optional context for conversation memory
  });

  Chat copyWith({
    String? id,
    String? title,
    String? modelName,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    List<int>? context,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      modelName: modelName ?? this.modelName,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      context: context ?? this.context,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'modelName': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'context': context, // Store context for conversation memory
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
      context: json['context'] != null
          ? List<int>.from(json['context'])
          : null, // Load context for conversation memory
    );
  }
}
