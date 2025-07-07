import '../utils/logger.dart';

/// Service for detecting thinking-capable models and identifying thinking patterns
class ThinkingModelDetectionService {
  static final Map<String, bool> _responseCache = <String, bool>{};

  // Common thinking indicators/markers in responses
  static const List<String> _thinkingMarkers = [
    '<thinking>',
    '<think>',
    '<reasoning>',
    '<analysis>',
    '<reflection>',
    '**Thinking:**',
    '**Analysis:**',
    '**Reasoning:**',
    'Let me think about this',
    'Let me analyze',
    'Let me consider',
    'First, I need to',
    'Step 1:',
    'My reasoning:',
    'To solve this:',
  ];

  

  // Paired thinking markers for explicit extraction
  static const Map<String, String> _pairedThinkingMarkers = {
    '<thinking>': '</thinking>',
    '<think>': '</think>',
    '<reasoning>': '</reasoning>',
    '<analysis>': '</analysis>',
    '<reflection>': '</reflection>',
  };

  /// Detect if a model is thinking-capable based on its response content
  /// This approach works with any model that produces thinking content
  static bool isThinkingModel(String modelName, [String? sampleResponse]) {
    // If we have a sample response, use it to detect thinking capability
    if (sampleResponse != null && sampleResponse.isNotEmpty) {
      return hasThinkingContent(sampleResponse);
    }

    // For backward compatibility, we can assume any model might be thinking-capable
    // The actual detection happens when we analyze the response content
    AppLogger.info(
        'Checking thinking capability for $modelName based on future response content');
    return true; // Assume all models might have thinking capability
  }

  /// Check if a response contains thinking content
  static bool hasThinkingContent(String response) {
    if (response.isEmpty) return false;

    // Use cache for performance on repeated checks
    if (_responseCache.containsKey(response)) {
      return _responseCache[response]!;
    }

    final lowerResponse = response.toLowerCase();
    bool hasThinking = false;

    // Check for explicit thinking markers
    for (final marker in _thinkingMarkers) {
      if (lowerResponse.contains(marker.toLowerCase())) {
        hasThinking = true;
        break;
      }
    }

    // If no explicit markers found, check for reasoning patterns
    if (!hasThinking) {
      final reasoningPatterns = [
        RegExp(r'\b(step \d+[:.]|first[,:]|second[,:]|third[,:])',
            caseSensitive: false),
        RegExp(r'\b(let me|i need to|i should|i will)\s+\w+',
            caseSensitive: false),
        RegExp(r'\b(because|since|therefore|thus|hence)\b',
            caseSensitive: false),
        RegExp(r'\*\*?(thinking|analysis|reasoning|reflection)[:.]?\*\*?',
            caseSensitive: false),
      ];

      for (final pattern in reasoningPatterns) {
        if (pattern.hasMatch(response)) {
          hasThinking = true;
          break;
        }
      }
    }

    // Cache the result for performance
    _responseCache[response] = hasThinking;

    // Limit cache size to prevent memory issues
    if (_responseCache.length > 100) {
      final keys = _responseCache.keys.toList();
      _responseCache.remove(keys.first);
    }

    AppLogger.info('Detected thinking content in response: $hasThinking');
    return hasThinking;
  }

  /// Extract thinking content from a response
  static ThinkingContent extractThinkingContent(String response) {
    if (!hasThinkingContent(response)) {
      return ThinkingContent(
        originalResponse: response,
        thinkingText: null,
        finalAnswer: response,
        hasThinking: false,
      );
    }

    // Try to extract explicit thinking sections first
    final explicitThinking = _extractExplicitThinking(response);
    if (explicitThinking != null) {
      return explicitThinking;
    }

    // Fall back to pattern-based extraction
    return _extractPatternBasedThinking(response);
  }

  /// Extract thinking content from explicit markers like `<thinking>...</thinking>`
  static ThinkingContent? _extractExplicitThinking(String response) {
    // Look for various thinking markers
    for (final entry in _pairedThinkingMarkers.entries) {
      final startMarker = entry.key;
      final endMarker = entry.value;

      final startIndex =
          response.toLowerCase().indexOf(startMarker.toLowerCase());

      if (startIndex == -1) continue;

      final endIndex = response
          .toLowerCase()
          .indexOf(endMarker.toLowerCase(), startIndex + startMarker.length);

      if (endIndex == -1) {
        // Opening marker found but no closing marker yet
        // This case is handled by the live streaming logic in ChatProvider
        continue;
      }

      final thinkingStart = startIndex + startMarker.length;
      final thinkingText =
          response.substring(thinkingStart, endIndex).trim();

      // Extract final answer (everything after thinking section)
      final finalAnswerStart = endIndex + endMarker.length;
      final finalAnswer = finalAnswerStart < response.length
          ? response.substring(finalAnswerStart).trim()
          : '';

      return ThinkingContent(
        originalResponse: response,
        thinkingText: thinkingText,
        finalAnswer: finalAnswer.isEmpty ? '' : finalAnswer,
        hasThinking: true,
        thinkingStartIndex: startIndex,
        thinkingEndIndex: endIndex + endMarker.length,
      );
    }

    return null;
  }

  /// Extract thinking content based on patterns when no explicit markers exist
  static ThinkingContent _extractPatternBasedThinking(String response) {
    // Look for step-by-step reasoning patterns
    final lines = response.split('\n');
    final thinkingLines = <String>[];
    final finalLines = <String>[];
    bool inThinkingSection = false;

    for (final line in lines) {
      final lowerLine = line.toLowerCase().trim();

      // Check if this line indicates start of thinking
      if (_isThinkingLine(lowerLine)) {
        inThinkingSection = true;
        thinkingLines.add(line);
        continue;
      }

      // Check if this line indicates end of thinking (final answer)
      if (_isFinalAnswerLine(lowerLine)) {
        inThinkingSection = false;
        finalLines.add(line);
        continue;
      }

      // Add line to appropriate section
      if (inThinkingSection) {
        thinkingLines.add(line);
      } else {
        finalLines.add(line);
      }
    }

    // If we identified some thinking content, separate it
    if (thinkingLines.isNotEmpty) {
      final thinkingText = thinkingLines.join('\n').trim();
      final finalAnswer =
          finalLines.isEmpty ? response : finalLines.join('\n').trim();

      return ThinkingContent(
        originalResponse: response,
        thinkingText: thinkingText,
        finalAnswer: finalAnswer.isEmpty ? '' : finalAnswer,
        hasThinking: true,
      );
    }

    // No clear thinking pattern found, treat entire response as final answer
    return ThinkingContent(
      originalResponse: response,
      thinkingText: null,
      finalAnswer: response,
      hasThinking: false,
    );
  }

  /// Check if a line indicates thinking/reasoning content
  static bool _isThinkingLine(String lowerLine) {
    final thinkingPatterns = [
      'let me think',
      'let me analyze',
      'first, i',
      'step 1',
      'step 2',
      'step 3',
      'my reasoning',
      'to solve this',
      'i need to consider',
      'thinking about',
    ];

    for (final pattern in thinkingPatterns) {
      if (lowerLine.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a line indicates final answer content
  static bool _isFinalAnswerLine(String lowerLine) {
    final finalPatterns = [
      'final answer',
      'in conclusion',
      'therefore,',
      'so the answer',
      'the result is',
      'my answer is',
    ];

    for (final pattern in finalPatterns) {
      if (lowerLine.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Clear the thinking model cache
  static void clearCache() {
    _responseCache.clear();
    AppLogger.info('Cleared thinking model detection cache');
  }

  /// Filter thinking content from response, returning only the final answer
  static String filterThinkingFromResponse(String response) {
    if (!hasThinkingContent(response)) {
      return response;
    }

    final thinkingContent = extractThinkingContent(response);
    return thinkingContent.finalAnswer;
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheStats() {
    final thinkingCount = _responseCache.values.where((v) => v).length;
    final nonThinkingCount = _responseCache.values.where((v) => !v).length;

    return {
      'totalCached': _responseCache.length,
      'thinkingModels': thinkingCount,
      'nonThinkingModels': nonThinkingCount,
    };
  }

  /// Preload thinking detection for a list of models (now mostly informational)
  /// Since we detect thinking capability from response content, this is mainly for logging
  static void preloadThinkingDetection(List<String> modelNames) {
    AppLogger.info(
        'Models available for potential thinking detection: ${modelNames.length} models');
    AppLogger.info(
        'Thinking capability will be detected from actual response content');
  }
}

/// Represents extracted thinking content from a model response
class ThinkingContent {
  final String originalResponse;
  final String? thinkingText;
  final String finalAnswer;
  final bool hasThinking;
  final int? thinkingStartIndex;
  final int? thinkingEndIndex;

  const ThinkingContent({
    required this.originalResponse,
    required this.thinkingText,
    required this.finalAnswer,
    required this.hasThinking,
    this.thinkingStartIndex,
    this.thinkingEndIndex,
  });

  /// Check if there is actual thinking content to display
  bool get hasDisplayableThinking =>
      hasThinking && thinkingText != null && thinkingText!.trim().isNotEmpty;

  /// Get a short summary of the thinking for display
  String get thinkingSummary {
    if (!hasDisplayableThinking) return '';

    final text = thinkingText!.trim();
    if (text.length <= 100) return text;

    // Get first sentence or first 100 characters
    final sentences = text.split('.');
    final firstSentence = sentences.isNotEmpty ? sentences.first.trim() : text;

    if (firstSentence.length <= 100) {
      return '$firstSentence...';
    }

    return '${text.substring(0, 97)}...';
  }

  @override
  String toString() {
    return 'ThinkingContent(hasThinking: $hasThinking, '
        'thinkingLength: ${thinkingText?.length ?? 0}, '
        'finalLength: ${finalAnswer.length})';
  }
}
