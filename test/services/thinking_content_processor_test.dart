import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/thinking_state.dart';
import 'package:ollamaverse/services/thinking_content_processor.dart';

void main() {
  group('ThinkingContentProcessor', () {
    late ThinkingState initialState;
    late ThinkingContentProcessor processor;

    setUp(() {
      initialState = ThinkingState.initial();
      processor = ThinkingContentProcessor();
    });

    group('processStreamingResponse', () {
      test('should return original response when empty', () {
        final result = processor.processStreamingResponse(
          fullResponse: '',
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals(''));
        expect(result['thinkingState'], equals(initialState));
      });

      test('should return original response when no thinking markers', () {
        const response = 'This is a normal response without thinking markers.';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals(response));
        expect(result['thinkingState'], equals(initialState));
      });

      test('should extract complete thinking block with <thinking> tags', () {
        const response = 'Before <thinking>This is thinking content</thinking> After';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Before  After'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.currentThinkingContent, equals('This is thinking content'));
        expect(thinkingState.hasActiveThinkingBubble, isTrue);
        expect(thinkingState.isInsideThinkingBlock, isFalse);
      });

      test('should extract incomplete thinking block with <thinking> tags', () {
        const response = 'Before <thinking>This is incomplete thinking content';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Before'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.currentThinkingContent, equals('This is incomplete thinking content'));
        expect(thinkingState.hasActiveThinkingBubble, isTrue);
        expect(thinkingState.isInsideThinkingBlock, isTrue);
      });

      test('should handle multiple thinking markers', () {
        const response = 'Start <think>First thought</think> Middle <reasoning>Second thought</reasoning> End';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Start  Middle  End'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        // Should contain the last processed thinking content
        expect(thinkingState.hasActiveThinkingBubble, isTrue);
        expect(thinkingState.isInsideThinkingBlock, isFalse);
      });

      test('should handle case-insensitive thinking markers', () {
        const response = 'Before <THINKING>Upper case thinking</THINKING> After';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Before  After'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.currentThinkingContent, equals('Upper case thinking'));
        expect(thinkingState.hasActiveThinkingBubble, isTrue);
      });

      test('should handle all supported thinking marker types', () {
        final markerTypes = [
          {'open': '<think>', 'close': '</think>'},
          {'open': '<thinking>', 'close': '</thinking>'},
          {'open': '<reasoning>', 'close': '</reasoning>'},
          {'open': '<analysis>', 'close': '</analysis>'},
          {'open': '<reflection>', 'close': '</reflection>'},
        ];

        for (final marker in markerTypes) {
          final response = 'Before ${marker['open']}Content${marker['close']} After';
          
          final result = processor.processStreamingResponse(
            fullResponse: response,
            currentState: initialState,
          );

          expect(result['filteredResponse'], equals('Before  After'));
          
          final thinkingState = result['thinkingState'] as ThinkingState;
          expect(thinkingState.currentThinkingContent, equals('Content'));
          expect(thinkingState.hasActiveThinkingBubble, isTrue);
        }
      });

      test('should clean up excessive whitespace', () {
        const response = 'Before\n\n\n<thinking>Content</thinking>\n\n\nAfter';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Before\n\nAfter'));
      });

      test('should handle empty thinking content', () {
        const response = 'Before <thinking></thinking> After';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Before  After'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.currentThinkingContent, equals(''));
        expect(thinkingState.hasActiveThinkingBubble, isFalse);
        expect(thinkingState.isInsideThinkingBlock, isFalse);
      });

      test('should preserve existing expanded bubbles state', () {
        final stateWithExpandedBubbles = initialState.copyWith(
          expandedBubbles: {'message1': true, 'message2': false},
        );
        
        const response = 'Before <thinking>New content</thinking> After';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: stateWithExpandedBubbles,
        );

        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.expandedBubbles['message1'], isTrue);
        expect(thinkingState.expandedBubbles['message2'], isFalse);
      });
    });

    group('updateThinkingPhase', () {
      test('should transition from thinking to answer phase when conditions met', () {
        final thinkingState = initialState.copyWith(
          isThinkingPhase: true,
          isInsideThinkingBlock: false,
        );
        
        final result = processor.updateThinkingPhase(
          currentState: thinkingState,
          displayResponse: 'Some visible content',
        );

        expect(result.isThinkingPhase, isFalse);
      });

      test('should stay in thinking phase when inside thinking block', () {
        final thinkingState = initialState.copyWith(
          isThinkingPhase: true,
          isInsideThinkingBlock: true,
        );
        
        final result = processor.updateThinkingPhase(
          currentState: thinkingState,
          displayResponse: 'Some visible content',
        );

        expect(result.isThinkingPhase, isTrue);
      });

      test('should stay in thinking phase when no display response', () {
        final thinkingState = initialState.copyWith(
          isThinkingPhase: true,
          isInsideThinkingBlock: false,
        );
        
        final result = processor.updateThinkingPhase(
          currentState: thinkingState,
          displayResponse: '',
        );

        expect(result.isThinkingPhase, isTrue);
      });

      test('should not change state when not in thinking phase', () {
        final nonThinkingState = initialState.copyWith(isThinkingPhase: false);
        
        final result = processor.updateThinkingPhase(
          currentState: nonThinkingState,
          displayResponse: 'Some content',
        );

        expect(result.isThinkingPhase, isFalse);
      });
    });

    group('initializeThinkingState', () {
      test('should create initial thinking state with thinking phase enabled', () {
        final result = processor.initializeThinkingState();

        expect(result.isThinkingPhase, isTrue);
        expect(result.currentThinkingContent, equals(''));
        expect(result.hasActiveThinkingBubble, isFalse);
        expect(result.isInsideThinkingBlock, isFalse);
        expect(result.expandedBubbles, isEmpty);
      });
    });

    group('resetThinkingState', () {
      test('should reset all thinking-related fields while preserving expanded bubbles', () {
        final activeState = initialState.copyWith(
          currentThinkingContent: 'Some thinking',
          hasActiveThinkingBubble: true,
          isInsideThinkingBlock: true,
          isThinkingPhase: true,
          expandedBubbles: {'message1': true},
        );

        final result = processor.resetThinkingState(activeState);

        expect(result.currentThinkingContent, equals(''));
        expect(result.hasActiveThinkingBubble, isFalse);
        expect(result.isInsideThinkingBlock, isFalse);
        expect(result.isThinkingPhase, isFalse);
        expect(result.expandedBubbles['message1'], isTrue); // Preserved
      });
    });

    group('toggleBubbleExpansion', () {
      test('should toggle bubble expansion from false to true', () {
        final result = processor.toggleBubbleExpansion(
          currentState: initialState,
          messageId: 'message1',
        );

        expect(result.isBubbleExpanded('message1'), isTrue);
      });

      test('should toggle bubble expansion from true to false', () {
        final stateWithExpanded = initialState.copyWith(
          expandedBubbles: {'message1': true},
        );

        final result = processor.toggleBubbleExpansion(
          currentState: stateWithExpanded,
          messageId: 'message1',
        );

        expect(result.isBubbleExpanded('message1'), isFalse);
      });

      test('should handle multiple bubble expansions', () {
        var state = initialState;
        
        state = processor.toggleBubbleExpansion(
          currentState: state,
          messageId: 'message1',
        );
        
        state = processor.toggleBubbleExpansion(
          currentState: state,
          messageId: 'message2',
        );

        expect(state.isBubbleExpanded('message1'), isTrue);
        expect(state.isBubbleExpanded('message2'), isTrue);
      });
    });

    group('isBubbleExpanded', () {
      test('should return false for non-existent message', () {
        final result = processor.isBubbleExpanded(
          currentState: initialState,
          messageId: 'nonexistent',
        );

        expect(result, isFalse);
      });

      test('should return correct expansion state', () {
        final stateWithExpanded = initialState.copyWith(
          expandedBubbles: {'message1': true, 'message2': false},
        );

        expect(
          processor.isBubbleExpanded(
            currentState: stateWithExpanded,
            messageId: 'message1',
          ),
          isTrue,
        );

        expect(
          processor.isBubbleExpanded(
            currentState: stateWithExpanded,
            messageId: 'message2',
          ),
          isFalse,
        );
      });
    });

    group('validateThinkingState', () {
      test('should validate correct thinking state', () {
        final validState = initialState.copyWith(
          currentThinkingContent: 'Some content',
          hasActiveThinkingBubble: true,
          isThinkingPhase: true,
        );

        expect(processor.validateThinkingState(validState), isTrue);
      });

      test('should validate initial state', () {
        expect(processor.validateThinkingState(initialState), isTrue);
      });
    });

    group('getThinkingStats', () {
      test('should return correct statistics for initial state', () {
        final stats = processor.getThinkingStats(initialState);

        expect(stats['hasThinkingContent'], isFalse);
        expect(stats['hasActiveThinkingBubble'], isFalse);
        expect(stats['isThinkingPhase'], isFalse);
        expect(stats['isInsideThinkingBlock'], isFalse);
        expect(stats['expandedBubbleCount'], equals(0));
        expect(stats['hasExpandedBubbles'], isFalse);
        expect(stats['contentLength'], equals(0));
        expect(stats['isValid'], isTrue);
      });

      test('should return correct statistics for active thinking state', () {
        final activeState = initialState.copyWith(
          currentThinkingContent: 'Thinking content',
          hasActiveThinkingBubble: true,
          isThinkingPhase: true,
          expandedBubbles: {'msg1': true, 'msg2': false, 'msg3': true},
        );

        final stats = processor.getThinkingStats(activeState);

        expect(stats['hasThinkingContent'], isTrue);
        expect(stats['hasActiveThinkingBubble'], isTrue);
        expect(stats['isThinkingPhase'], isTrue);
        expect(stats['expandedBubbleCount'], equals(2));
        expect(stats['hasExpandedBubbles'], isTrue);
        expect(stats['contentLength'], equals(16));
        expect(stats['isValid'], isTrue);
      });
    });

    group('extractThinkingMarkers', () {
      test('should extract single complete thinking marker', () {
        const text = 'Before <thinking>Content here</thinking> After';
        
        final markers = processor.extractThinkingMarkers(text);

        expect(markers, hasLength(1));
        expect(markers[0]['type'], equals('thinking'));
        expect(markers[0]['isComplete'], isTrue);
        expect(markers[0]['content'], equals('Content here'));
      });

      test('should extract multiple thinking markers', () {
        const text = 'Start <think>First</think> Middle <reasoning>Second</reasoning> End';
        
        final markers = processor.extractThinkingMarkers(text);

        expect(markers, hasLength(2));
        expect(markers[0]['type'], equals('think'));
        expect(markers[0]['content'], equals('First'));
        expect(markers[1]['type'], equals('reasoning'));
        expect(markers[1]['content'], equals('Second'));
      });

      test('should extract incomplete thinking marker', () {
        const text = 'Before <thinking>Incomplete content';
        
        final markers = processor.extractThinkingMarkers(text);

        expect(markers, hasLength(1));
        expect(markers[0]['type'], equals('thinking'));
        expect(markers[0]['isComplete'], isFalse);
        expect(markers[0]['content'], equals('Incomplete content'));
      });

      test('should return empty list for text without markers', () {
        const text = 'Regular text without any thinking markers';
        
        final markers = processor.extractThinkingMarkers(text);

        expect(markers, isEmpty);
      });

      test('should sort markers by position', () {
        const text = 'Start <reasoning>Second</reasoning> Middle <think>First</think> End';
        
        final markers = processor.extractThinkingMarkers(text);

        expect(markers, hasLength(2));
        expect(markers[0]['type'], equals('reasoning')); // Appears first in text
        expect(markers[1]['type'], equals('think')); // Appears second in text
      });
    });

    group('containsThinkingMarkers', () {
      test('should return true for text with thinking markers', () {
        const texts = [
          'Text with <thinking>content</thinking>',
          'Text with <think>content</think>',
          'Text with <reasoning>content</reasoning>',
          'Text with <analysis>content</analysis>',
          'Text with <reflection>content</reflection>',
        ];

        for (final text in texts) {
          expect(processor.containsThinkingMarkers(text), isTrue);
        }
      });

      test('should return false for text without thinking markers', () {
        const text = 'Regular text without any special markers';
        
        expect(processor.containsThinkingMarkers(text), isFalse);
      });

      test('should return false for empty text', () {
        expect(processor.containsThinkingMarkers(''), isFalse);
      });

      test('should handle case-insensitive detection', () {
        const text = 'Text with <THINKING>content</THINKING>';
        
        expect(processor.containsThinkingMarkers(text), isTrue);
      });
    });

    group('getSupportedMarkerTypes', () {
      test('should return all supported marker types', () {
        final types = processor.getSupportedMarkerTypes();

        expect(types, contains('think'));
        expect(types, contains('thinking'));
        expect(types, contains('reasoning'));
        expect(types, contains('analysis'));
        expect(types, contains('reflection'));
        expect(types, hasLength(5));
      });
    });

    group('error handling', () {
      test('should handle malformed thinking markers gracefully', () {
        const response = 'Before <thinking>Unclosed thinking block';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        // Should still process the incomplete block
        expect(result['filteredResponse'], equals('Before'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.currentThinkingContent, equals('Unclosed thinking block'));
        expect(thinkingState.isInsideThinkingBlock, isTrue);
      });

      test('should handle nested thinking markers', () {
        const response = 'Before <thinking>Outer <think>Inner</think> content</thinking> After';
        
        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        // Should process the outermost markers first
        expect(result['filteredResponse'], equals('Before  After'));
        
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.hasActiveThinkingBubble, isTrue);
      });
    });
  });
}
