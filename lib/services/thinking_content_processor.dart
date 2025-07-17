import '../models/thinking_state.dart';
import '../utils/logger.dart';

/// Service responsible for processing thinking content from AI responses
/// Handles stream filtering, content extraction, and thinking bubble state management
class ThinkingContentProcessor {
  /// List of supported thinking markers with their open/close tags
  static const List<Map<String, String>> _thinkingMarkers = [
    {'open': '<think>', 'close': '</think>'},
    {'open': '<thinking>', 'close': '</thinking>'},
    {'open': '<reasoning>', 'close': '</reasoning>'},
    {'open': '<analysis>', 'close': '</analysis>'},
    {'open': '<reflection>', 'close': '</reflection>'},
  ];

  /// Process streaming response and extract thinking content
  /// Returns a map with filtered response and updated thinking state
  static Map<String, dynamic> processStreamingResponse({
    required String fullResponse,
    required ThinkingState currentState,
  }) {
    if (fullResponse.isEmpty) {
      return {
        'filteredResponse': fullResponse,
        'thinkingState': currentState,
      };
    }

    try {
      // Start with the full response
      String filteredResponse = fullResponse;
      String extractedThinkingContent = '';
      bool hasActiveThinkingBubble = false;
      bool isInsideThinkingBlock = false;

      // Process each type of thinking marker
      for (final markerPair in _thinkingMarkers) {
        final openMarker = markerPair['open']!;
        final closeMarker = markerPair['close']!;

        // Keep processing until no more markers of this type
        while (true) {
          final openIndex = filteredResponse
              .toLowerCase()
              .indexOf(openMarker.toLowerCase());
          
          if (openIndex == -1) break;

          final closeIndex = filteredResponse.toLowerCase().indexOf(
            closeMarker.toLowerCase(),
            openIndex + openMarker.length,
          );

          if (closeIndex == -1) {
            // Opening marker found but no closing marker yet
            // Extract thinking content and hide from main display
            final thinkingStart = openIndex + openMarker.length;
            extractedThinkingContent = fullResponse.substring(thinkingStart).trim();
            hasActiveThinkingBubble = true;
            isInsideThinkingBlock = true;

            // Hide everything from the opening marker onwards
            filteredResponse = filteredResponse.substring(0, openIndex).trim();
            break;
          } else {
            // Complete thinking block found
            final thinkingStart = openIndex + openMarker.length;
            extractedThinkingContent = fullResponse
                .substring(thinkingStart, closeIndex)
                .trim();
            hasActiveThinkingBubble = extractedThinkingContent.isNotEmpty;
            isInsideThinkingBlock = false;

            // Remove the complete thinking block from display
            final beforeThinking = filteredResponse.substring(0, openIndex);
            final afterThinking = filteredResponse
                .substring(closeIndex + closeMarker.length);
            filteredResponse = (beforeThinking + afterThinking).trim();
          }
        }
      }

      // Clean up any excessive whitespace
      filteredResponse = _cleanupWhitespace(filteredResponse);

      // Create updated thinking state
      final updatedThinkingState = currentState.copyWith(
        currentThinkingContent: extractedThinkingContent,
        hasActiveThinkingBubble: hasActiveThinkingBubble,
        isInsideThinkingBlock: isInsideThinkingBlock,
      );

      AppLogger.info(
        'Processed thinking content: hasActive=$hasActiveThinkingBubble, '
        'isInside=$isInsideThinkingBlock, contentLength=${extractedThinkingContent.length}',
      );

      return {
        'filteredResponse': filteredResponse,
        'thinkingState': updatedThinkingState,
      };
    } catch (e) {
      AppLogger.error('Error processing thinking content', e);
      
      // Return original response and state on error
      return {
        'filteredResponse': fullResponse,
        'thinkingState': currentState,
      };
    }
  }

  /// Update thinking phase based on response content
  /// Determines if the model has moved from thinking to answering
  static ThinkingState updateThinkingPhase({
    required ThinkingState currentState,
    required String displayResponse,
  }) {
    try {
      // If we're in thinking phase and have visible content but not inside a thinking block,
      // the model has likely moved on to the actual answer
      if (currentState.isThinkingPhase &&
          displayResponse.isNotEmpty &&
          !currentState.isInsideThinkingBlock) {
        AppLogger.info('Transitioning from thinking phase to answer phase');
        
        return currentState.copyWith(isThinkingPhase: false);
      }

      return currentState;
    } catch (e) {
      AppLogger.error('Error updating thinking phase', e);
      return currentState;
    }
  }

  /// Initialize thinking state for new message generation
  static ThinkingState initializeThinkingState() {
    return ThinkingState.initial().copyWith(isThinkingPhase: true);
  }

  /// Reset thinking state after message completion
  static ThinkingState resetThinkingState(ThinkingState currentState) {
    return currentState.copyWith(
      currentThinkingContent: '',
      hasActiveThinkingBubble: false,
      isInsideThinkingBlock: false,
      isThinkingPhase: false,
    );
  }

  /// Toggle thinking bubble expansion for a specific message
  static ThinkingState toggleBubbleExpansion({
    required ThinkingState currentState,
    required String messageId,
  }) {
    try {
      final updatedState = currentState.toggleBubbleExpansion(messageId);
      
      AppLogger.info(
        'Toggled thinking bubble for message $messageId: '
        '${updatedState.isBubbleExpanded(messageId)}',
      );
      
      return updatedState;
    } catch (e) {
      AppLogger.error('Error toggling thinking bubble expansion', e);
      return currentState;
    }
  }

  /// Check if a thinking bubble is expanded for a specific message
  static bool isBubbleExpanded({
    required ThinkingState currentState,
    required String messageId,
  }) {
    return currentState.isBubbleExpanded(messageId);
  }

  /// Validate thinking state consistency
  static bool validateThinkingState(ThinkingState state) {
    return state.isValid;
  }

  /// Get thinking content statistics for debugging
  static Map<String, dynamic> getThinkingStats(ThinkingState state) {
    return {
      'hasThinkingContent': state.hasThinkingContent,
      'hasActiveThinkingBubble': state.hasActiveThinkingBubble,
      'isThinkingPhase': state.isThinkingPhase,
      'isInsideThinkingBlock': state.isInsideThinkingBlock,
      'expandedBubbleCount': state.expandedBubbleCount,
      'hasExpandedBubbles': state.hasExpandedBubbles,
      'contentLength': state.currentThinkingContent.length,
      'isValid': state.isValid,
    };
  }

  /// Clean up excessive whitespace from filtered response
  static String _cleanupWhitespace(String text) {
    if (text.isEmpty) return text;
    
    // Remove excessive newlines (more than 2 consecutive)
    return text.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
  }

  /// Extract all thinking markers from text for analysis
  static List<Map<String, dynamic>> extractThinkingMarkers(String text) {
    final List<Map<String, dynamic>> foundMarkers = [];
    
    for (final markerPair in _thinkingMarkers) {
      final openMarker = markerPair['open']!;
      final closeMarker = markerPair['close']!;
      
      int searchStart = 0;
      while (true) {
        final openIndex = text
            .toLowerCase()
            .indexOf(openMarker.toLowerCase(), searchStart);
        
        if (openIndex == -1) break;
        
        final closeIndex = text.toLowerCase().indexOf(
          closeMarker.toLowerCase(),
          openIndex + openMarker.length,
        );
        
        foundMarkers.add({
          'type': openMarker.replaceAll('<', '').replaceAll('>', ''),
          'openIndex': openIndex,
          'closeIndex': closeIndex,
          'isComplete': closeIndex != -1,
          'content': closeIndex != -1
              ? text.substring(openIndex + openMarker.length, closeIndex)
              : text.substring(openIndex + openMarker.length),
        });
        
        searchStart = closeIndex != -1 
            ? closeIndex + closeMarker.length 
            : text.length;
      }
    }
    
    // Sort by position in text
    foundMarkers.sort((a, b) => a['openIndex'].compareTo(b['openIndex']));
    
    return foundMarkers;
  }

  /// Check if text contains any thinking markers
  static bool containsThinkingMarkers(String text) {
    if (text.isEmpty) return false;
    
    final lowerText = text.toLowerCase();
    
    for (final markerPair in _thinkingMarkers) {
      final openMarker = markerPair['open']!.toLowerCase();
      if (lowerText.contains(openMarker)) {
        return true;
      }
    }
    
    return false;
  }

  /// Get supported thinking marker types
  static List<String> getSupportedMarkerTypes() {
    return _thinkingMarkers
        .map((marker) => marker['open']!.replaceAll('<', '').replaceAll('>', ''))
        .toList();
  }
}