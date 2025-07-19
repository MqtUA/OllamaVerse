/// State container for thinking content processing
///
/// This state manages the complex interaction between thinking content extraction,
/// bubble display, and user interaction to provide insight into AI reasoning
class ThinkingState {
  final String currentThinkingContent;
  final bool hasActiveThinkingBubble;
  final bool isInsideThinkingBlock;
  final bool isThinkingPhase;
  final Map<String, bool> expandedBubbles;

  const ThinkingState({
    required this.currentThinkingContent,
    required this.hasActiveThinkingBubble,
    required this.isInsideThinkingBlock,
    required this.isThinkingPhase,
    required this.expandedBubbles,
  });

  /// Create initial thinking state
  factory ThinkingState.initial() {
    return const ThinkingState(
      currentThinkingContent: '',
      hasActiveThinkingBubble: false,
      isInsideThinkingBlock: false,
      isThinkingPhase: false,
      expandedBubbles: {},
    );
  }

  /// Create thinking state for active thinking
  factory ThinkingState.thinking({
    required String thinkingContent,
    required bool isInsideBlock,
  }) {
    return ThinkingState(
      currentThinkingContent: thinkingContent,
      hasActiveThinkingBubble: thinkingContent.isNotEmpty,
      isInsideThinkingBlock: isInsideBlock,
      isThinkingPhase: true,
      expandedBubbles: const {},
    );
  }

  /// Create a copy with updated fields
  ThinkingState copyWith({
    String? currentThinkingContent,
    bool? hasActiveThinkingBubble,
    bool? isInsideThinkingBlock,
    bool? isThinkingPhase,
    Map<String, bool>? expandedBubbles,
  }) {
    return ThinkingState(
      currentThinkingContent:
          currentThinkingContent ?? this.currentThinkingContent,
      hasActiveThinkingBubble:
          hasActiveThinkingBubble ?? this.hasActiveThinkingBubble,
      isInsideThinkingBlock:
          isInsideThinkingBlock ?? this.isInsideThinkingBlock,
      isThinkingPhase: isThinkingPhase ?? this.isThinkingPhase,
      expandedBubbles: expandedBubbles ?? Map.from(this.expandedBubbles),
    );
  }

  /// Toggle thinking bubble expansion for a message
  ThinkingState toggleBubbleExpansion(String messageId) {
    final newExpandedBubbles = Map<String, bool>.from(expandedBubbles);
    newExpandedBubbles[messageId] = !(expandedBubbles[messageId] ?? false);

    return copyWith(expandedBubbles: newExpandedBubbles);
  }

  /// Check if a thinking bubble is expanded
  bool isBubbleExpanded(String messageId) {
    return expandedBubbles[messageId] ?? false;
  }

  /// Reset to initial state
  ThinkingState reset() {
    return ThinkingState.initial();
  }

  /// Clear current thinking content but keep bubble states
  ThinkingState clearCurrentThinking() {
    return copyWith(
      currentThinkingContent: '',
      hasActiveThinkingBubble: false,
      isInsideThinkingBlock: false,
      isThinkingPhase: false,
    );
  }

  /// Check if there's any thinking content
  bool get hasThinkingContent => currentThinkingContent.isNotEmpty;

  /// Check if any bubbles are expanded
  bool get hasExpandedBubbles =>
      expandedBubbles.values.any((expanded) => expanded);

  /// Get count of expanded bubbles
  int get expandedBubbleCount =>
      expandedBubbles.values.where((expanded) => expanded).length;

  /// Validation ensures thinking state consistency across the processing pipeline
  bool get isValid => _validateState();

  bool _validateState() {
    // Active bubble requires content to display
    if (hasActiveThinkingBubble && currentThinkingContent.isEmpty) {
      return false;
    }

    // Bubbles should only be active during thinking phase
    if (!isThinkingPhase && hasActiveThinkingBubble) {
      return false;
    }

    // Being inside a thinking block implies we're in thinking phase
    if (isInsideThinkingBlock && !isThinkingPhase) {
      return false;
    }

    return true;
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'currentThinkingContent': currentThinkingContent,
      'hasActiveThinkingBubble': hasActiveThinkingBubble,
      'isInsideThinkingBlock': isInsideThinkingBlock,
      'isThinkingPhase': isThinkingPhase,
      'expandedBubbles': expandedBubbles,
    };
  }

  /// Create from JSON
  factory ThinkingState.fromJson(Map<String, dynamic> json) {
    return ThinkingState(
      currentThinkingContent: json['currentThinkingContent'] as String? ?? '',
      hasActiveThinkingBubble:
          json['hasActiveThinkingBubble'] as bool? ?? false,
      isInsideThinkingBlock: json['isInsideThinkingBlock'] as bool? ?? false,
      isThinkingPhase: json['isThinkingPhase'] as bool? ?? false,
      expandedBubbles: Map<String, bool>.from(
          json['expandedBubbles'] as Map<String, dynamic>? ?? {}),
    );
  }

  @override
  String toString() {
    return 'ThinkingState('
        'hasActiveThinkingBubble: $hasActiveThinkingBubble, '
        'isThinkingPhase: $isThinkingPhase, '
        'isInsideThinkingBlock: $isInsideThinkingBlock, '
        'expandedBubbles: ${expandedBubbles.length}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThinkingState &&
        other.currentThinkingContent == currentThinkingContent &&
        other.hasActiveThinkingBubble == hasActiveThinkingBubble &&
        other.isInsideThinkingBlock == isInsideThinkingBlock &&
        other.isThinkingPhase == isThinkingPhase &&
        _mapEquals(other.expandedBubbles, expandedBubbles);
  }

  @override
  int get hashCode {
    return Object.hash(
      currentThinkingContent,
      hasActiveThinkingBubble,
      isInsideThinkingBlock,
      isThinkingPhase,
      expandedBubbles.length,
    );
  }

  /// Helper method to compare maps
  bool _mapEquals(Map<String, bool> map1, Map<String, bool> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }
}
