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
          json['message']?['content'] as String? ??
          '',
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
          json['message']?['content'] as String? ??
          '',
      context: json['context'] != null ? List<int>.from(json['context']) : null,
      done: json['done'] as bool? ?? false,
    );
  }
}
