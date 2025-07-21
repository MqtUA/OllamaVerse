import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/services/message_streaming_service.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/models/app_settings.dart';
import 'package:ollamaverse/models/chat.dart';
import 'package:ollamaverse/models/message.dart';
import 'package:ollamaverse/models/processed_file.dart';
import 'package:ollamaverse/models/streaming_state.dart';
import 'package:ollamaverse/models/thinking_state.dart';
import 'package:ollamaverse/models/ollama_response.dart';
import 'package:ollamaverse/services/thinking_content_processor.dart';

// Simple mock OllamaService for testing
class TestOllamaService extends OllamaService {
  TestOllamaService() : super(settings: AppSettings());
  
  Stream<OllamaStreamResponse>? mockStreamResponse;
  OllamaResponse? mockResponse;
  Exception? mockError;
  
  @override
  Stream<OllamaStreamResponse> generateStreamingResponseWithContext(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    List<Message>? conversationHistory,
    int? contextLength,
    Chat? chat,
    bool Function()? isCancelled,
  }) {
    if (mockError != null) {
      throw mockError!;
    }
    return mockStreamResponse ?? const Stream.empty();
  }
  
  @override
  Future<OllamaResponse> generateResponseWithContext(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    List<Message>? conversationHistory,
    int? contextLength,
    Chat? chat,
    bool Function()? isCancelled,
  }) async {
    if (mockError != null) {
      throw mockError!;
    }
    return mockResponse ?? const OllamaResponse(response: '', context: null);
  }
}

void main() {
  group('MessageStreamingService', () {
    late MessageStreamingService service;
    late TestOllamaService mockOllamaService;
    
    setUp(() {
      mockOllamaService = TestOllamaService();
      final thinkingContentProcessor = ThinkingContentProcessor();
      service = MessageStreamingService(
        ollamaService: mockOllamaService,
        thinkingContentProcessor: thinkingContentProcessor,
      );
    });
    
    tearDown(() {
      service.dispose();
    });

    group('Initialization', () {
      test('should initialize with correct default states', () {
        expect(service.streamingState, equals(StreamingState.initial()));
        expect(service.thinkingState, equals(ThinkingState.initial()));
        expect(service.isStreaming, isFalse);
        expect(service.isCancelled, isFalse);
      });

      test('should validate initial state', () {
        expect(service.validateState(), isTrue);
      });
    });

    group('State Callbacks', () {
      test('should set and call streaming state callback', () {
        StreamingState? receivedState;
        service.setStreamingStateCallback((state) {
          receivedState = state;
        });

        // Trigger internal state change
        service.cancelStreaming();

        expect(receivedState, isNotNull);
        expect(receivedState, equals(StreamingState.initial()));
      });

      test('should set and call thinking state callback', () {
        ThinkingState? receivedState;
        service.setThinkingStateCallback((state) {
          receivedState = state;
        });

        // Trigger internal state change
        service.cancelStreaming();

        expect(receivedState, isNotNull);
        expect(receivedState, equals(ThinkingState.initial()));
      });
    });

    group('Non-Streaming Response', () {
      test('should handle non-streaming response', () async {
        // Mock non-streaming response
        mockOllamaService.mockResponse = const OllamaResponse(
          response: 'Complete response',
          context: [1, 2, 3],
        );

        // Start non-streaming generation
        final responseStream = service.generateStreamingMessage(
          content: 'Test message',
          model: 'test-model',
          conversationHistory: [],
          showLiveResponse: false,
        );

        final responses = <Map<String, dynamic>>[];
        await for (final response in responseStream) {
          responses.add(response);
        }

        // Verify response
        expect(responses.length, equals(1));
        expect(responses.first['type'], equals('complete'));
        expect(responses.first['fullResponse'], equals('Complete response'));
        expect(responses.first['context'], equals([1, 2, 3]));
      });
    });

    group('Thinking Bubble Management', () {
      test('should toggle thinking bubble expansion', () {
        const messageId = 'test-message-id';
        
        // Initially not expanded
        expect(service.isThinkingBubbleExpanded(messageId), isFalse);
        
        // Toggle to expand
        service.toggleThinkingBubble(messageId);
        expect(service.isThinkingBubbleExpanded(messageId), isTrue);
        
        // Toggle to collapse
        service.toggleThinkingBubble(messageId);
        expect(service.isThinkingBubbleExpanded(messageId), isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle non-streaming errors gracefully', () async {
        // Mock non-streaming error
        mockOllamaService.mockError = Exception('Non-streaming error');

        // Start non-streaming generation
        final responseStream = service.generateStreamingMessage(
          content: 'Test message',
          model: 'test-model',
          conversationHistory: [],
          showLiveResponse: false,
        );

        // Expect error to be thrown
        expect(
          () async {
            await for (final _ in responseStream) {
              // Should not reach here
            }
          },
          throwsException,
        );
      });
    });

    group('Statistics and Debugging', () {
      test('should provide streaming statistics', () {
        final stats = service.getStreamingStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('isStreaming'), isTrue);
        expect(stats.containsKey('isCancelled'), isTrue);
        expect(stats.containsKey('streamingState'), isTrue);
        expect(stats.containsKey('thinkingStats'), isTrue);
        expect(stats.containsKey('hasActiveSubscription'), isTrue);
      });

      test('should validate state consistency', () {
        expect(service.validateState(), isTrue);
        
        // After cancellation, state should still be valid
        service.cancelStreaming();
        expect(service.validateState(), isTrue);
      });
    });

    group('Resource Management', () {
      test('should dispose resources properly', () {
        // Set callbacks
        service.setStreamingStateCallback((_) {});
        service.setThinkingStateCallback((_) {});
        
        // Dispose
        service.dispose();
        
        // Verify cancellation token is cancelled after dispose
        expect(service.isCancelled, isTrue);
      });
    });

    group('Basic Functionality', () {
      test('should handle basic message generation workflow', () async {
        // Mock non-streaming response
        mockOllamaService.mockResponse = const OllamaResponse(
          response: 'Test response',
          context: [1, 2, 3],
        );

        // Track state changes
        final streamingStates = <StreamingState>[];
        final thinkingStates = <ThinkingState>[];
        
        service.setStreamingStateCallback((state) {
          streamingStates.add(state);
        });
        
        service.setThinkingStateCallback((state) {
          thinkingStates.add(state);
        });

        // Start generation with processed files
        final processedFiles = [
          ProcessedFile.text(
            originalPath: '/test/test.txt',
            fileName: 'test.txt',
            textContent: 'Test file content',
            fileSizeBytes: 100,
            mimeType: 'text/plain',
          ),
        ];

        final responseStream = service.generateStreamingMessage(
          content: 'Analyze this file',
          model: 'test-model',
          conversationHistory: [
            Message(
              id: '1',
              content: 'Previous message',
              role: MessageRole.user,
              timestamp: DateTime.now(),
            ),
          ],
          processedFiles: processedFiles,
          context: [1, 2, 3],
          contextLength: 4096,
          showLiveResponse: false, // Use non-streaming for simpler test
        );

        final responses = <Map<String, dynamic>>[];
        await for (final response in responseStream) {
          responses.add(response);
        }

        // Verify workflow
        expect(responses.length, equals(1));
        expect(responses.first['type'], equals('complete'));
        expect(responses.first['fullResponse'], equals('Test response'));
        expect(responses.first['context'], equals([1, 2, 3]));
        
        // Verify state changes occurred
        expect(streamingStates.length, greaterThan(0));
        expect(thinkingStates.length, greaterThan(0));
        
        // Verify final states
        expect(service.streamingState.isStreaming, isFalse);
        expect(service.thinkingState.isThinkingPhase, isFalse);
      });
    });
  });
}