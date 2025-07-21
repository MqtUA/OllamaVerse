import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/chat.dart';
import 'package:ollamaverse/models/message.dart';
import 'package:ollamaverse/models/processed_file.dart';
import 'package:ollamaverse/services/chat_state_manager.dart';
import 'package:ollamaverse/services/message_streaming_service.dart';
import 'package:ollamaverse/services/thinking_content_processor.dart';
import 'package:ollamaverse/services/model_manager.dart';
import 'package:ollamaverse/services/chat_title_generator.dart';
import 'package:ollamaverse/services/file_processing_manager.dart';
import 'package:ollamaverse/services/chat_history_service.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/services/file_content_processor.dart';
import 'package:ollamaverse/models/ollama_response.dart';

// Critical error scenario tests to ensure robustness
void main() {
  group('Critical Error Scenarios', () {
    group('Service Initialization Failures', () {
      test('should handle ChatStateManager initialization with corrupted data', () async {
        final corruptedChatHistoryService = CorruptedChatHistoryService();
        
        expect(
          () => ChatStateManager(chatHistoryService: corruptedChatHistoryService),
          returnsNormally,
        );

        // Service should handle corrupted data gracefully
        final chatStateManager = ChatStateManager(
          chatHistoryService: corruptedChatHistoryService,
        );
        
        expect(chatStateManager.chats, isEmpty);
        chatStateManager.dispose();
      });

      test('should handle ModelManager with unreachable service', () async {
        final unreachableSettingsProvider = UnreachableSettingsProvider();
        final modelManager = ModelManager(settingsProvider: unreachableSettingsProvider);

        final result = await modelManager.loadModels();
        expect(result, isFalse);
        expect(modelManager.availableModels, isEmpty);
        expect(modelManager.lastError, isNotNull);
      });
    });

    group('Runtime Failures', () {
      test('should handle MessageStreamingService with connection drops', () async {
        final unreliableOllamaService = UnreliableOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: unreliableOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        // Should handle connection drops gracefully
        final responseStream = service.generateStreamingMessage(
          content: 'Test message',
          model: 'test-model',
          conversationHistory: [],
          showLiveResponse: true,
        );

        expect(
          () async {
            await for (final _ in responseStream) {
              // Stream should handle errors internally
            }
          },
          throwsException,
        );

        service.dispose();
      });

      test('should handle ChatTitleGenerator with service timeouts', () async {
        final timeoutOllamaService = TimeoutOllamaService();
        final mockSettingsProvider = MockSettingsProvider();
        mockSettingsProvider.setMockOllamaService(timeoutOllamaService);
        final modelManager = ModelManager(settingsProvider: mockSettingsProvider);
        
        final titleGenerator = ChatTitleGenerator(
          ollamaService: timeoutOllamaService,
          modelManager: modelManager,
        );

        final result = await titleGenerator.generateTitle(
          chatId: 'test-chat',
          userMessage: 'Test message',
          aiResponse: 'Test response',
          modelName: 'test-model',
        );

        // Should return fallback title on timeout
        expect(result, isNotNull);
        expect(result.isNotEmpty, isTrue);
      });

      test('should handle FileProcessingManager with file system errors', () async {
        final errorFileContentProcessor = ErrorFileContentProcessor();
        final manager = FileProcessingManager(
          fileContentProcessor: errorFileContentProcessor,
        );

        expect(
          () => manager.processFiles(['test/file.txt']),
          throwsA(isA<FileProcessingException>()),
        );

        expect(manager.isProcessingFiles, isFalse);
      });
    });

    group('Resource Exhaustion Scenarios', () {
      test('should handle memory pressure gracefully', () async {
        final mockChatHistoryService = MockChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: mockChatHistoryService,
        );

        // Simulate memory pressure by creating many large chats
        try {
          for (int i = 0; i < 10000; i++) {
            final chat = await chatStateManager.createNewChat(
              modelName: 'test-model',
              title: 'Large Chat $i',
            );
            
            // Add many messages to each chat
            for (int j = 0; j < 1000; j++) {
              chat.messages.add(Message(
                id: 'msg-$i-$j',
                content: 'Large message content ' * 100, // Large content
                role: MessageRole.user,
                timestamp: DateTime.now(),
              ));
            }
            
            await chatStateManager.updateChat(chat);
          }
        } catch (e) {
          // Expected to fail at some point due to memory constraints
          // The important thing is that it fails gracefully
        }

        // Service should still be functional
        expect(chatStateManager.chats.isNotEmpty, isTrue);
        chatStateManager.dispose();
      });

      test('should handle concurrent operation limits', () async {
        final mockOllamaService = MockOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: mockOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        mockOllamaService.mockResponse = const OllamaResponse(
          response: 'Test response',
          context: [1, 2, 3],
        );

        // Start many concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 1000; i++) {
          final responseStream = service.generateStreamingMessage(
            content: 'Concurrent message $i',
            model: 'test-model',
            conversationHistory: [],
            showLiveResponse: false,
          );
          futures.add(responseStream.toList());
        }

        // Should handle high concurrency without crashing
        final results = await Future.wait(futures, eagerError: false);
        
        // Most operations should succeed
        final successCount = results.where((r) => r is List && r.isNotEmpty).length;
        expect(successCount, greaterThan(500)); // At least 50% should succeed

        service.dispose();
      });
    });

    group('Data Corruption Scenarios', () {
      test('should handle corrupted chat data', () async {
        final corruptedChatHistoryService = CorruptedChatHistoryService();
        final chatStateManager = ChatStateManager(
          chatHistoryService: corruptedChatHistoryService,
        );

        // Should handle corrupted data without crashing
        expect(chatStateManager.chats, isEmpty);
        
        // Should be able to create new chats despite corruption
        final newChat = await chatStateManager.createNewChat(
          modelName: 'test-model',
          title: 'New Chat',
        );
        
        expect(newChat, isNotNull);
        expect(chatStateManager.activeChat?.id, equals(newChat.id));
        
        chatStateManager.dispose();
      });

      test('should handle malformed streaming responses', () {
        final processor = ThinkingContentProcessor();
        final initialState = processor.initializeThinkingState();

        final malformedResponses = [
          null,
          '',
          '<thinking>',
          '</thinking>',
          '<thinking><thinking><thinking>',
          'Normal text <invalid>tag</invalid> more text',
          String.fromCharCodes([0, 1, 2, 3, 4, 5]), // Invalid characters
        ];

        for (final response in malformedResponses) {
          expect(
            () => processor.processStreamingResponse(
              fullResponse: response ?? '',
              currentState: initialState,
            ),
            returnsNormally,
          );
        }
      });
    });

    group('Network Failure Scenarios', () {
      test('should handle complete network failure', () async {
        final networkFailureOllamaService = NetworkFailureOllamaService();
        final mockSettingsProvider = MockSettingsProvider();
        mockSettingsProvider.setMockOllamaService(networkFailureOllamaService);
        
        final modelManager = ModelManager(settingsProvider: mockSettingsProvider);

        // Should handle network failure gracefully
        final result = await modelManager.loadModels();
        expect(result, isFalse);
        expect(modelManager.lastError, contains('network'));
      });

      test('should handle intermittent network issues', () async {
        final intermittentOllamaService = IntermittentOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: intermittentOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        // Should eventually succeed despite intermittent failures
        var successCount = 0;
        for (int i = 0; i < 10; i++) {
          try {
            final responseStream = service.generateStreamingMessage(
              content: 'Test message $i',
              model: 'test-model',
              conversationHistory: [],
              showLiveResponse: false,
            );
            
            final responses = await responseStream.toList();
            if (responses.isNotEmpty) {
              successCount++;
            }
          } catch (e) {
            // Expected intermittent failures
          }
        }

        expect(successCount, greaterThan(0)); // Should have some successes
        service.dispose();
      });
    });

    group('Service Disposal Under Stress', () {
      test('should handle disposal during active operations', () async {
        final mockOllamaService = MockOllamaService();
        final thinkingContentProcessor = ThinkingContentProcessor();
        final service = MessageStreamingService(
          ollamaService: mockOllamaService,
          thinkingContentProcessor: thinkingContentProcessor,
        );

        // Start a long-running operation
        final controller = StreamController<OllamaStreamResponse>();
        mockOllamaService.setMockStreamResponse(controller.stream);

        final responseStream = service.generateStreamingMessage(
          content: 'Long running message',
          model: 'test-model',
          conversationHistory: [],
          showLiveResponse: true,
        );

        final subscription = responseStream.listen((_) {});

        // Dispose service while operation is active
        service.dispose();

        // Should handle disposal gracefully
        await subscription.cancel();
        controller.close();

        expect(service.isCancelled, isTrue);
      });
    });
  });
}

// Mock implementations for error scenario testing
class CorruptedChatHistoryService implements ChatHistoryService {
  @override
  bool get isInitialized => true;

  @override
  List<Chat> get chats => []; // Return empty list for corrupted data

  @override
  Stream<List<Chat>> get chatStream => Stream.value([]);

  @override
  Future<void> saveChat(Chat chat) async {
    // Simulate save failure
    throw Exception('Data corruption: Unable to save chat');
  }

  @override
  Future<void> deleteChat(String chatId) async {
    // Simulate delete failure
    throw Exception('Data corruption: Unable to delete chat');
  }

  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UnreachableSettingsProvider implements ISettingsProvider {
  @override
  bool get isLoading => false;

  @override
  OllamaService getOllamaService() => UnreachableOllamaService();

  @override
  Future<String> getLastSelectedModel() async => 'unreachable-model';

  @override
  Future<void> setLastSelectedModel(String modelName) async {
    throw Exception('Service unreachable');
  }
}

class UnreachableOllamaService implements OllamaService {
  @override
  Future<List<String>> getModels() async {
    throw OllamaConnectionException('Service unreachable');
  }

  @override
  Future<bool> testConnection() async {
    throw OllamaConnectionException('Service unreachable');
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UnreliableOllamaService implements OllamaService {
  int _callCount = 0;

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
    _callCount++;
    if (_callCount % 2 == 0) {
      throw Exception('Connection dropped');
    }
    return Stream.fromIterable([
      const OllamaStreamResponse(response: 'Unreliable', done: true),
    ]);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TimeoutOllamaService implements OllamaService {
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
    // Simulate timeout
    await Future.delayed(const Duration(seconds: 60));
    return const OllamaResponse(response: 'Timeout response', context: null);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ErrorFileContentProcessor extends FileContentProcessor {
  @override
  Future<List<ProcessedFile>> processFiles(
    List<String> filePaths, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    throw FileProcessingException('File system error');
  }

  @override
  Future<ProcessedFile> processFile(
    String filePath, {
    void Function(FileProcessingProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    throw FileProcessingException('File system error');
  }
}

class NetworkFailureOllamaService implements OllamaService {
  @override
  Future<List<String>> getModels() async {
    throw Exception('Network failure: Unable to connect');
  }

  @override
  Future<bool> testConnection() async {
    throw Exception('Network failure: Unable to connect');
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IntermittentOllamaService implements OllamaService {
  int _callCount = 0;

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
    _callCount++;
    if (_callCount % 3 == 0) {
      return const OllamaResponse(response: 'Success', context: [1, 2, 3]);
    } else {
      throw Exception('Intermittent network failure');
    }
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Helper classes
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
  OllamaResponse? mockResponse;
  Stream<OllamaStreamResponse>? _mockStreamResponse;

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
    return mockResponse ?? const OllamaResponse(response: 'Mock response', context: null);
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
    return _mockStreamResponse ?? const Stream.empty();
  }

  void setMockStreamResponse(Stream<OllamaStreamResponse> stream) {
    _mockStreamResponse = stream;
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsProvider implements ISettingsProvider {
  OllamaService? _mockOllamaService;

  @override
  bool get isLoading => false;

  @override
  OllamaService getOllamaService() => _mockOllamaService ?? MockOllamaService();

  @override
  Future<String> getLastSelectedModel() async => 'test-model';

  @override
  Future<void> setLastSelectedModel(String modelName) async {}
  
  void setMockOllamaService(OllamaService service) {
    _mockOllamaService = service;
  }
}

// Exception classes
class FileProcessingException implements Exception {
  final String message;
  FileProcessingException(this.message);
  
  @override
  String toString() => 'FileProcessingException: $message';
}