String _extractMessageContent(dynamic content) {
  if (content is String) {
    return content;
  }
  if (content is List) {
    final buffer = StringBuffer();
    var wroteText = false;
    for (final part in content) {
      if (part is Map<String, dynamic>) {
        final type = part['type'];
        final textPart = part['text'];
        if (type == 'text' && textPart is String && textPart.isNotEmpty) {
          if (wroteText) {
            buffer.write('\n');
          }
          buffer.write(textPart);
          wroteText = true;
        }
      }
    }
    return buffer.toString();
  }
  return '';
}

/// Response from Ollama API including both text and context for conversation memory
class OllamaResponse {
  final String response;
  final List<int>? context;

  const OllamaResponse({
    required this.response,
    this.context,
  });

  factory OllamaResponse.fromJson(Map<String, dynamic> json) {
    return OllamaResponse(
      response: json['response'] as String? ??
          _extractMessageContent(
              (json['message'] as Map<String, dynamic>?)?['content']),
      context: json['context'] != null ? List<int>.from(json['context']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'context': context,
    };
  }
}

/// Streaming response chunk from Ollama API
class OllamaStreamResponse {
  final String response;
  final List<int>? context;
  final bool done;

  const OllamaStreamResponse({
    required this.response,
    this.context,
    required this.done,
  });

  factory OllamaStreamResponse.fromJson(Map<String, dynamic> json) {
    return OllamaStreamResponse(
      response: json['response'] as String? ??
          _extractMessageContent(
              (json['message'] as Map<String, dynamic>?)?['content']),
      context: json['context'] != null ? List<int>.from(json['context']) : null,
      done: json['done'] as bool? ?? false,
    );
  }
}
