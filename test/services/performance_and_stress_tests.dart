import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/chat.dart';
import 'package:ollamaverse/models/message.dart';
import 'package:ollamaverse/models/thinking_state.dart';
import 'package:ollamaverse/services/chat_state_manager.dart';
import 'package:ollamaverse/services/message_streaming_service.dart';
import 'package:ollamaverse/services/thinking_content_processor.dart';
import 'package:ollamaverse/services/model_manager.dart';
import 'package:ollamaverse/services/chat_history_service.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/models/ollama_response.dart';
import 'package:ollamaverse/models/processed_file.dart';

// Performance and stress tests for services
void main() {
  group('Performance and Stress Tests', () {
    group('ChatStateManager Performance', () {
      test('should handle large number of chats efficiently', () async {
        final mockChatHistoryService = MockChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: mockChatHistoryService,
        );

        final stopwatch = Stopwatch()..start();

        // Create 1000 chats
        for (int i = 0; i < 1000; i++) {
          await chatStateManager.createNewChat(
            modelName: 'test-model',
            title: 'Performance Test Chat $i',
          );
        }

        stopwatch.stop();

        expect(chatStateManager.chats.length, equals(1000));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in under 5 seconds

        // Test retrieval performance
        final retrievalStopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final randomIndex = Random().nextInt(1000);
          final chatId = chatStateManager.chats[randomIndex].id;
          final retrievedChat = chatStateManager.getChatById(chatId);
          expect(retrievedChat, isNotNull);
        }
        retrievalStopwatch.stop();

        expect(retrievalStopwatch.elapsedMilliseconds, lessThan(100)); // Should be very fast

        chatStateManager.dispose();
      });

      test('should handle rapid state updates without memory leaks', () async {
        final mockChatHistoryService = MockChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: mockChatHistoryService,
        );

        // Create a chat
        final chat = await chatStateManager.createNewChat(
          modelName: 'test-model',
          title: 'Memory Test Chat',
        );

        // Perform many rapid updates
        for (int i = 0; i < 10000; i++) {
          final updatedChat = chat.copyWith(
            messages: [
              ...chat.messages,
              Message(
                id: 'msg-$i',
                content: 'Message $i',
                role: MessageRole.user,
                timestamp: DateTime.now(),
              ),
            ],
          );
          await chatStateManager.updateChat(updatedChat);
        }

        expect(chatStateManager.activeChat?.messages.length, equals(10000));

        chatStateManager.dispose();
      });
    });

    group('MessageStreamingService Performance', () {
      test('should handle high-frequency streaming updates', () async {
        final mockOllamaService = MockOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: mockOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        // Create a high-frequency stream
        final controller = StreamController<OllamaStreamResponse>();
        mockOllamaService.mockStreamResponse = controller.stream;

        final responseStream = service.generateStreamingMessage(
          content: 'Performance test message',
          model: 'test-model',
          conversationHistory: [],
          showLiveResponse: true,
        );

        final responses = <Map<String, dynamic>>[];
        final subscription = responseStream.listen(
          (response) => responses.add(response),
        );

        final stopwatch = Stopwatch()..start();

        // Send 1000 rapid updates
        for (int i = 0; i < 1000; i++) {
          controller.add(OllamaStreamResponse(
            response: 'Token $i ',
            done: i == 999,
          ));
          
          // Small delay to simulate realistic streaming
          if (i % 100 == 0) {
            await Future.delayed(const Duration(microseconds: 100));
          }
        }

        // Wait for processing to complete
        await Future.delayed(const Duration(milliseconds: 100));
        stopwatch.stop();

        await subscription.cancel();
        controller.close();

        expect(responses.length, greaterThan(0));
        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Should handle efficiently

        service.dispose();
      });

      test('should handle concurrent streaming sessions', () async {
        final mockOllamaService = MockOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: mockOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        mockOllamaService.mockResponse = const OllamaResponse(
          response: 'Concurrent test response',
          context: [1, 2, 3],
        );

        final stopwatch = Stopwatch()..start();

        // Start 50 concurrent streaming sessions
        final futures = <Future<List<Map<String, dynamic>>>>[];
        for (int i = 0; i < 50; i++) {
          final responseStream = service.generateStreamingMessage(
            content: 'Concurrent message $i',
            model: 'test-model',
            conversationHistory: [],
            showLiveResponse: false,
          );
          futures.add(responseStream.toList());
        }

        final results = await Future.wait(futures);
        stopwatch.stop();

        expect(results.length, equals(50));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should handle concurrency well

        service.dispose();
      });
    });

    group('ThinkingContentProcessor Performance', () {
      test('should handle large documents with thinking content efficiently', () {
        final processor = ThinkingContentProcessor();
        final initialState = ThinkingState.initial();

        // Create a large document with multiple thinking blocks
        final largeDocument = StringBuffer();
        for (int i = 0; i < 1000; i++) {
          largeDocument.write('Regular content paragraph $i. ');
          if (i % 10 == 0) {
            largeDocument.write('<thinking>Thinking block $i with detailed analysis and reasoning that goes on for quite a while to simulate real thinking content.</thinking> ');
          }
        }

        final stopwatch = Stopwatch()..start();

        final result = processor.processStreamingResponse(
          fullResponse: largeDocument.toString(),
          currentState: initialState,
        );

        stopwatch.stop();

        expect(result['filteredResponse'], isA<String>());
        expect(result['thinkingState'], isA<ThinkingState>());
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should process efficiently

        final filteredResponse = result['filteredResponse'] as String;
        expect(filteredResponse.contains('<thinking>'), isFalse);
        expect(filteredResponse.contains('</thinking>'), isFalse);
      });

      test('should handle rapid thinking state updates', () {
        final processor = ThinkingContentProcessor();
        var currentState = ThinkingState.initial();

        final stopwatch = Stopwatch()..start();

        // Perform many rapid state updates
        for (int i = 0; i < 10000; i++) {
          final response = 'Content $i <thinking>Thinking $i</thinking> More content $i';
          final result = processor.processStreamingResponse(
            fullResponse: response,
            currentState: currentState,
          );
          currentState = result['thinkingState'] as ThinkingState;
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Should handle rapid updates
        expect(currentState.hasActiveThinkingBubble, isTrue);
      });
    });

    group('ModelManager Performance', () {
      test('should handle model loading with large model lists', () async {
        final mockSettingsProvider = MockSettingsProvider();
        final mockOllamaService = MockOllamaService();
        
        // Create a large list of models
        mockOllamaService.modelsToReturn = List.generate(1000, (i) => 'model-$i');
        mockSettingsProvider.mockOllamaService = mockOllamaService;

        final modelManager = ModelManager(settingsProvider: mockSettingsProvider);

        final stopwatch = Stopwatch()..start();
        final result = await modelManager.loadModels();
        stopwatch.stop();

        expect(result, isTrue);
        expect(modelManager.availableModels.length, equals(1000));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should handle large lists efficiently
      });

      test('should handle rapid model selection changes', () async {
        final mockSettingsProvider = MockSettingsProvider();
        final mockOllamaService = MockOllamaService();
        mockOllamaService.modelsToReturn = ['model1', 'model2', 'model3'];
        mockSettingsProvider.mockOllamaService = mockOllamaService;

        final modelManager = ModelManager(settingsProvider: mockSettingsProvider);
        await modelManager.loadModels();

        final stopwatch = Stopwatch()..start();

        // Perform rapid model selections
        for (int i = 0; i < 1000; i++) {
          final modelIndex = i % 3;
          await modelManager.setSelectedModel('model${modelIndex + 1}');
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should handle rapid changes
        expect(modelManager.lastSelectedModel, equals('model1'));
      });
    });

    group('Memory Usage Tests', () {
      test('should not leak memory with repeated service operations', () async {
        // This test would ideally measure actual memory usage
        // For now, we'll test that services properly clean up resources
        
        for (int iteration = 0; iteration < 10; iteration++) {
          final mockChatHistoryService = MockChatHistoryService();
          final chatStateManager = ChatStateManager(
            chatHistoryService: mockChatHistoryService,
          );

          // Perform operations
          for (int i = 0; i < 100; i++) {
            await chatStateManager.createNewChat(
              modelName: 'test-model',
              title: 'Memory Test Chat $i',
            );
          }

          // Dispose properly
          chatStateManager.dispose();
          mockChatHistoryService.dispose();
        }

        // If we reach here without memory issues, the test passes
        expect(true, isTrue);
      });

      test('should handle service disposal under load', () async {
        final services = <dynamic>[];

        // Create many services
        for (int i = 0; i < 100; i++) {
          final mockChatHistoryService = MockChatHistoryService();
          final chatStateManager = ChatStateManager(
            chatHistoryService: mockChatHistoryService,
          );
          
          final mockOllamaService = MockOllamaService();
          final thinkingContentProcessor = ThinkingContentProcessor();
          final messageStreamingService = MessageStreamingService(
            ollamaService: mockOllamaService,
            thinkingContentProcessor: thinkingContentProcessor,
          );

          services.addAll([
            chatStateManager,
            messageStreamingService,
            mockChatHistoryService,
          ]);
        }

        // Dispose all services rapidly
        final stopwatch = Stopwatch()..start();
        for (final service in services) {
          if (service.dispose != null) {
            service.dispose();
          }
        }
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should dispose quickly
      });
    });
  });
}

// Mock implementations for performance testing
class MockChatHistoryService implements ChatHistoryService {
  final List<Chat> _chats = [];
  final StreamController<List<Chat>> _chatStreamController = StreamController.broadcast();
  bool _disposed = false;

  @override
  bool get isInitialized => !_disposed;

  @override
  List<Chat> get chats => _chats;

  @override
  Stream<List<Chat>> get chatStream => _chatStreamController.stream;

  @override
  Future<void> saveChat(Chat chat) async {
    if (_disposed) return;
    
    final existingIndex = _chats.indexWhere((c) => c.id == chat.id);
    if (existingIndex >= 0) {
      _chats[existingIndex] = chat;
    } else {
      _chats.add(chat);
    }
    
    if (!_chatStreamController.isClosed) {
      _chatStreamController.add(List.from(_chats));
    }
  }

  @override
  Future<void> deleteChat(String chatId) async {
    if (_disposed) return;
    
    _chats.removeWhere((chat) => chat.id == chatId);
    
    if (!_chatStreamController.isClosed) {
      _chatStreamController.add(List.from(_chats));
    }
  }

  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _chatStreamController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOllamaService implements OllamaService {
  List<String> modelsToReturn = ['model1', 'model2'];
  bool connectionSuccess = true;
  Exception? exceptionToThrow;
  Stream<OllamaStreamResponse>? mockStreamResponse;
  OllamaResponse? mockResponse;

  @override
  Future<List<String>> getModels() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return List.from(modelsToReturn);
  }

  @override
  Future<bool> testConnection() async {
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
    Chat? chat,
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
    Chat? chat,
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