/// State container for streaming operations
///
/// Separates raw response from display response to handle thinking content
/// filtering while maintaining the complete response for processing
class StreamingState {
  final String currentResponse;
  final String displayResponse;
  final bool isStreaming;

  const StreamingState({
    required this.currentResponse,
    required this.displayResponse,
    required this.isStreaming,
  });

  /// Create initial streaming state
  factory StreamingState.initial() {
    return const StreamingState(
      currentResponse: '',
      displayResponse: '',
      isStreaming: false,
    );
  }

  /// Create streaming state for active streaming
  factory StreamingState.streaming({
    required String currentResponse,
    required String displayResponse,
  }) {
    return StreamingState(
      currentResponse: currentResponse,
      displayResponse: displayResponse,
      isStreaming: true,
    );
  }

  /// Create streaming state for completed streaming
  factory StreamingState.completed(String finalResponse) {
    return StreamingState(
      currentResponse: finalResponse,
      displayResponse: finalResponse,
      isStreaming: false,
    );
  }

  /// Create a copy with updated fields
  StreamingState copyWith({
    String? currentResponse,
    String? displayResponse,
    bool? isStreaming,
  }) {
    return StreamingState(
      currentResponse: currentResponse ?? this.currentResponse,
      displayResponse: displayResponse ?? this.displayResponse,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// Reset to initial state
  StreamingState reset() {
    return StreamingState.initial();
  }

  /// Check if there's any content
  bool get hasContent =>
      currentResponse.isNotEmpty || displayResponse.isNotEmpty;

  /// Check if display content is different from current response
  bool get hasFilteredContent => currentResponse != displayResponse;

  /// Validation prevents inconsistent streaming states that could confuse the UI
  bool get isValid => _validateState();

  bool _validateState() {
    // When not streaming, both responses should match (no filtering needed)
    if (!isStreaming && currentResponse != displayResponse) {
      return false;
    }

    // Display response is filtered from current, so it can't be longer
    if (displayResponse.length > currentResponse.length) {
      return false;
    }

    return true;
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'currentResponse': currentResponse,
      'displayResponse': displayResponse,
      'isStreaming': isStreaming,
    };
  }

  /// Create from JSON
  factory StreamingState.fromJson(Map<String, dynamic> json) {
    return StreamingState(
      currentResponse: json['currentResponse'] as String? ?? '',
      displayResponse: json['displayResponse'] as String? ?? '',
      isStreaming: json['isStreaming'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'StreamingState('
        'currentResponse: ${currentResponse.length} chars, '
        'displayResponse: ${displayResponse.length} chars, '
        'isStreaming: $isStreaming'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamingState &&
        other.currentResponse == currentResponse &&
        other.displayResponse == displayResponse &&
        other.isStreaming == isStreaming;
  }

  @override
  int get hashCode {
    return Object.hash(currentResponse, displayResponse, isStreaming);
  }
}
