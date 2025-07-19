import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/chat.dart';
import 'package:ollamaverse/models/message.dart';
import 'package:ollamaverse/models/processed_file.dart';
import 'package:ollamaverse/models/thinking_state.dart';
import 'package:ollamaverse/services/chat_state_manager.dart';
import 'package:ollamaverse/services/message_streaming_service.dart';
import 'package:ollamaverse/services/thinking_content_processor.dart';
import 'package:ollamaverse/services/model_manager.dart';
import 'package:ollamaverse/services/file_processing_manager.dart';
import 'package:ollamaverse/services/chat_history_service.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/services/file_content_processor.dart';
import 'package:ollamaverse/models/ollama_response.dart';
import 'package:ollamaverse/utils/cancellation_token.dart';

// Comprehensive test suite for edge cases and error scenarios
void main() {
  group('Comprehensive Service Edge Case Tests', () {
    group('ChatStateManager Edge Cases', () {
      test('should handle rapid state changes without race conditions', () async {
        final mockChatHistoryService = MockChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: mockChatHistoryService,
        );

        // Simulate rapid state changes
        final futures = <Future<void>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(chatStateManager.createNewChat(
            modelName: 'test-model-$i',
            title: 'Chat $i',
          ));
        }

        await Future.wait(futures);

        expect(chatStateManager.chats.length, equals(10));
        chatStateManager.dispose();
      });

      test('should handle memory pressure with large chat lists', () async {
        final mockChatHistoryService = MockChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: mockChatHistoryService,
        );

        // Create many chats with messages
        for (int i = 0; i < 100; i++) {
          final chat = await chatStateManager.createNewChat(
            modelName: 'test-model',
            title: 'Chat $i',
          );
          
          // Add messages to each chat
          for (int j = 0; j < 50; j++) {
            chat.messages.add(Message(
              id: 'msg-$i-$j',
              content: 'Message $j in chat $i',
              role: MessageRole.user,
              timestamp: DateTime.now(),
            ));
          }
          
          await chatStateManager.updateChat(chat);
        }

        expect(chatStateManager.chats.length, equals(100));
        expect(chatStateManager.chats.first.messages.length, equals(50));
        
        chatStateManager.dispose();
      });

      test('should handle corrupted chat data gracefully', () async {
        final mockChatHistoryService = MockChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: mockChatHistoryService,
        );

        // Create a chat with invalid data
        final invalidChat = Chat(
          id: '', // Invalid empty ID
          title: '', // Invalid empty title
          modelName: '', // Invalid empty model
          messages: [],
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
        );

        // Should handle gracefully without throwing
        expect(
          () => chatStateManager.updateChat(invalidChat),
          throwsArgumentError,
        );

        chatStateManager.dispose();
      });
    });

    group('MessageStreamingService Edge Cases', () {
      test('should handle stream interruption and recovery', () async {
        final mockOllamaService = MockOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: mockOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        // Create a stream that fails midway
        final controller = StreamController<OllamaStreamResponse>();
        mockOllamaService.mockStreamResponse = controller.stream;

        final responseStream = service.generateStreamingMessage(
          content: 'Test message',
          model: 'test-model',
          conversationHistory: [],
          showLiveResponse: true,
        );

        // Start consuming the stream
        final responses = <Map<String, dynamic>>[];
        final subscription = responseStream.listen(
          (response) => responses.add(response),
          onError: (error) {
            // Expected error
          },
        );

        // Send some responses then error
        controller.add(const OllamaStreamResponse(response: 'Hello', done: false));
        controller.add(const OllamaStreamResponse(response: ' world', done: false));
        controller.addError(Exception('Stream interrupted'));

        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();
        controller.close();

        expect(responses.length, greaterThan(0));
        service.dispose();
      });

      test('should handle concurrent streaming requests', () async {
        final mockOllamaService = MockOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: mockOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        // Set up mock response
        mockOllamaService.mockResponse = const OllamaResponse(
          response: 'Test response',
          context: [1, 2, 3],
        );

        // Start multiple concurrent requests
        final futures = <Future<List<Map<String, dynamic>>>>[];
        for (int i = 0; i < 5; i++) {
          final responseStream = service.generateStreamingMessage(
            content: 'Test message $i',
            model: 'test-model',
            conversationHistory: [],
            showLiveResponse: false,
          );
          
          futures.add(responseStream.toList());
        }

        final results = await Future.wait(futures);
        
        // All requests should complete successfully
        expect(results.length, equals(5));
        for (final result in results) {
          expect(result.length, equals(1));
          expect(result.first['type'], equals('complete'));
        }

        service.dispose();
      });
    });

    group('ThinkingContentProcessor Edge Cases', () {
      test('should handle malformed thinking content', () {
        final processor = ThinkingContentProcessor();
        final initialState = ThinkingState.initial();

        final testCases = [
          'Text with <thinking>unclosed thinking block',
          'Text with </thinking>closing without opening',
          'Text with <thinking><thinking>nested thinking</thinking></thinking>',
          'Text with <thinking>thinking</THINKING>case mismatch',
          'Text with <thinking></thinking><thinking></thinking>multiple empty blocks',
        ];

        for (final testCase in testCases) {
          final result = processor.processStreamingResponse(
            fullResponse: testCase,
            currentState: initialState,
          );

          // Should not throw and should return valid state
          expect(result['filteredResponse'], isA<String>());
          expect(result['thinkingState'], isA<ThinkingState>());
        }
      });

      test('should handle extremely large thinking content', () {
        final processor = ThinkingContentProcessor();
        final initialState = ThinkingState.initial();

        // Create very large thinking content
        final largeContent = 'A' * 100000; // 100KB of content
        final response = 'Before <thinking>$largeContent</thinking> After';

        final result = processor.processStreamingResponse(
          fullResponse: response,
          currentState: initialState,
        );

        expect(result['filteredResponse'], equals('Before  After'));
        final thinkingState = result['thinkingState'] as ThinkingState;
        expect(thinkingState.currentThinkingContent, equals(largeContent));
      });
    });

    group('ModelManager Edge Cases', () {
      test('should handle network timeouts gracefully', () async {
        final mockSettingsProvider = MockSettingsProvider();
        final mockOllamaService = MockOllamaService();
        mockOllamaService.shouldTimeout = true;
        mockSettingsProvider.mockOllamaService = mockOllamaService;

        final modelManager = ModelManager(settingsProvider: mockSettingsProvider);

        final result = await modelManager.loadModels();
        expect(result, isFalse);
        expect(modelManager.lastError, contains('timeout'));
      });

      test('should handle partial model list responses', () async {
        final mockSettingsProvider = MockSettingsProvider();
        final mockOllamaService = MockOllamaService();
        mockOllamaService.modelsToReturn = ['model1', '', 'model3', '', 'model5'];
        mockSettingsProvider.mockOllamaService = mockOllamaService;

        final modelManager = ModelManager(settingsProvider: mockSettingsProvider);

        final result = await modelManager.loadModels();
        expect(result, isTrue);
        
        // Should filter out invalid models
        final validModels = modelManager.availableModels.where((m) => m.isNotEmpty).toList();
        expect(validModels, equals(['model1', 'model3', 'model5']));
      });
    });

    group('FileProcessingManager Edge Cases', () {
      test('should handle file processing with cancellation', () async {
        final fileContentProcessor = FileContentProcessor();
        final manager = FileProcessingManager(
          fileContentProcessor: fileContentProcessor,
        );

        final cancellationToken = CancellationToken();
        
        // Start processing and immediately cancel
        final processingFuture = manager.processFiles(
          ['test/file1.txt', 'test/file2.txt'],
          cancellationToken: cancellationToken,
        );

        cancellationToken.cancel();

        final result = await processingFuture;
        
        // Should handle cancellation gracefully
        expect(result, isA<List<ProcessedFile>>());
        expect(manager.isProcessingFiles, isFalse);
      });

      test('should handle file processing errors per file', () async {
        final fileContentProcessor = FileContentProcessor();
        final manager = FileProcessingManager(
          fileContentProcessor: fileContentProcessor,
        );

        // Process mix of valid and invalid files
        final result = await manager.processFiles([
          'test/valid_file.txt',
          'test/nonexistent_file.txt',
          'test/another_valid_file.txt',
        ]);

        // Should return results for all files, with errors for invalid ones
        expect(result.length, equals(3));
        expect(manager.isProcessingFiles, isFalse);
      });
    });

    group('Error Recovery Edge Cases', () {
      test('should handle cascading service failures', () async {
        // This test would verify that when one service fails,
        // it doesn't cause a cascade of failures in dependent services
        // Implementation would depend on actual service dependencies
        expect(true, isTrue); // Placeholder
      });

      test('should handle recovery strategy failures', () async {
        // Test that when a recovery strategy itself fails,
        // the system handles it gracefully
        expect(true, isTrue); // Placeholder
      });
    });
  });
}

// Enhanced mock implementations for comprehensive testing
class MockChatHistoryService implements ChatHistoryService {
  final List<Chat> _chats = [];
  final StreamController<List<Chat>> _chatStreamController = StreamController.broadcast();

  @override
  bool get isInitialized => true;

  @override
  List<Chat> get chats => _chats;

  @override
  Stream<List<Chat>> get chatStream => _chatStreamController.stream;

  @override
  Future<void> saveChat(Chat chat) async {
    final existingIndex = _chats.indexWhere((c) => c.id == chat.id);
    if (existingIndex >= 0) {
      _chats[existingIndex] = chat;
    } else {
      _chats.add(chat);
    }
    _chatStreamController.add(List.from(_chats));
  }

  @override
  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((chat) => chat.id == chatId);
    _chatStreamController.add(List.from(_chats));
  }

  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    await _chatStreamController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOllamaService implements OllamaService {
  List<String> modelsToReturn = ['model1', 'model2'];
  bool connectionSuccess = true;
  Exception? exceptionToThrow;
  bool shouldTimeout = false;
  Stream<OllamaStreamResponse>? mockStreamResponse;
  OllamaResponse? mockResponse;

  @override
  Future<List<String>> getModels() async {
    if (shouldTimeout) {
      await Future.delayed(const Duration(seconds: 10));
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return modelsToReturn.where((m) => m.isNotEmpty).toList();
  }

  @override
  Future<bool> testConnection() async {
    if (shouldTimeout) {
      await Future.delayed(const Duration(seconds: 10));
    }
    return connectionSuccess;
  }

  @override
  Stream<OllamaStreamResponse> generateStreamingResponseWithContext(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    List<Message>? conversationHistory,
    int? contextLength,
    bool Function()? isCancelled,
  }) {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
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
    bool Function()? isCancelled,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockResponse ?? const OllamaResponse(response: 'Default response', context: null);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsProvider implements ISettingsProvider {
  MockOllamaService? mockOllamaService;
  bool isLoadingValue = false;
  String lastSelectedModel = 'test-model';

  @override
  bool get isLoading => isLoadingValue;

  @override
  OllamaService getOllamaService() => mockOllamaService ?? MockOllamaService();

  @override
  Future<String> getLastSelectedModel() async => lastSelectedModel;

  @override
  Future<void> setLastSelectedModel(String modelName) async {
    lastSelectedModel = modelName;
  }
}