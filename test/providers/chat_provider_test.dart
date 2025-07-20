// Flutter test imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ollamaverse/providers/chat_provider.dart';
import 'package:ollamaverse/providers/settings_provider.dart';
import 'package:ollamaverse/services/chat_history_service.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/services/model_manager.dart';
import 'package:ollamaverse/services/chat_state_manager.dart';
import 'package:ollamaverse/services/message_streaming_service.dart';
import 'package:ollamaverse/services/chat_title_generator.dart';
import 'package:ollamaverse/services/file_processing_manager.dart';
import 'package:ollamaverse/services/thinking_content_processor.dart';
import 'package:ollamaverse/services/file_content_processor.dart';
import 'package:ollamaverse/services/error_recovery_service.dart';

import 'package:ollamaverse/models/app_settings.dart';
import 'package:ollamaverse/models/ollama_response.dart';

// Generate mocks with custom names to avoid conflicts
@GenerateMocks([], customMocks: [
  MockSpec<OllamaService>(as: #MockOllamaServiceTest),
  MockSpec<ChatHistoryService>(as: #MockChatHistoryServiceTest),
  MockSpec<SettingsProvider>(as: #MockSettingsProviderTest),
])
import 'chat_provider_test.mocks.dart';

// We can't easily mock the StorageService since it's instantiated inside ChatProvider
// For a real project, we would refactor ChatProvider to accept StorageService as a constructor parameter
// For now, we'll focus our tests on what we can test without accessing private members

void main() {
  // Initialize Flutter binding for tests that need it
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOllamaServiceTest mockOllamaService;
  late MockChatHistoryServiceTest mockChatHistoryService;
  late MockSettingsProviderTest mockSettingsProvider;
  late ChatProvider chatProvider;

  final testModels = ['llama2', 'mistral'];

  setUp(() async {
    mockOllamaService = MockOllamaServiceTest();
    mockChatHistoryService = MockChatHistoryServiceTest();
    mockSettingsProvider = MockSettingsProviderTest();

    // Setup mock behavior
    when(mockOllamaService.getModels()).thenAnswer((_) async => testModels);

    // Setup mock settings provider
    when(mockSettingsProvider.settings).thenReturn(
      AppSettings(showLiveResponse: false),
    );
    when(mockSettingsProvider.isLoading)
        .thenReturn(false); // Important: not loading
    when(mockSettingsProvider.getOllamaService()).thenReturn(mockOllamaService);
    when(mockSettingsProvider.getLastSelectedModel())
        .thenAnswer((_) async => 'llama2');

    // Setup mock chat history service
    when(mockChatHistoryService.chats).thenReturn([]);
    when(mockChatHistoryService.chatStream).thenAnswer((_) => Stream.value([]));
    when(mockChatHistoryService.isInitialized).thenReturn(true);
    when(mockChatHistoryService.saveChat(any)).thenAnswer((_) async {});
    when(mockChatHistoryService.deleteChat(any)).thenAnswer((_) async {});

    // Setup model validation mocks
    when(mockOllamaService.validateSystemPromptSupport(any)).thenAnswer((_) async => {
      'supported': true,
      'modelName': 'llama2',
      'fallbackMethod': 'native',
      'recommendation': 'Model supports system prompts natively.',
    });
    when(mockOllamaService.getSystemPromptStrategy(any)).thenReturn('native');

    // Create the provider with the mocks and required services
    final modelManager = ModelManager(settingsProvider: mockSettingsProvider);
    final chatStateManager = ChatStateManager(chatHistoryService: mockChatHistoryService);
    final thinkingContentProcessor = ThinkingContentProcessor();
    final fileContentProcessor = FileContentProcessor();
    final messageStreamingService = MessageStreamingService(
      ollamaService: mockOllamaService,
      thinkingContentProcessor: thinkingContentProcessor,
    );
    final chatTitleGenerator = ChatTitleGenerator(
      ollamaService: mockOllamaService,
      modelManager: modelManager,
    );
    final fileProcessingManager = FileProcessingManager(
      fileContentProcessor: fileContentProcessor,
    );
    
    final errorRecoveryService = ErrorRecoveryService();
    
    chatProvider = ChatProvider(
      chatHistoryService: mockChatHistoryService,
      settingsProvider: mockSettingsProvider,
      modelManager: modelManager,
      chatStateManager: chatStateManager,
      messageStreamingService: messageStreamingService,
      chatTitleGenerator: chatTitleGenerator,
      fileProcessingManager: fileProcessingManager,
      thinkingContentProcessor: thinkingContentProcessor,
      errorRecoveryService: errorRecoveryService,
    );
    
    // Initialize the model manager with test models
    await modelManager.refreshModels();
    
    // Reset mock call counts after initialization
    reset(mockOllamaService);
    
    // Re-setup the mock behavior after reset
    when(mockOllamaService.getModels()).thenAnswer((_) async => testModels);
    when(mockOllamaService.validateSystemPromptSupport(any)).thenAnswer((_) async => {
      'supported': true,
      'modelName': 'llama2',
      'fallbackMethod': 'native',
      'recommendation': 'Model supports system prompts natively.',
    });
    when(mockOllamaService.getSystemPromptStrategy(any)).thenReturn('native');
    
    // Setup default mock for generateResponseWithContext
    when(mockOllamaService.generateResponseWithContext(
      any,
      model: anyNamed('model'),
      processedFiles: anyNamed('processedFiles'),
      context: anyNamed('context'),
      conversationHistory: anyNamed('conversationHistory'),
      contextLength: anyNamed('contextLength'),
      isCancelled: anyNamed('isCancelled'),
    )).thenAnswer((_) async => OllamaResponse(response: 'Test response', context: []));
  });

  group('ChatProvider', () {
    test('initializes with empty chats', () {
      expect(chatProvider.chats, isEmpty);
    });

    test('refreshModels fetches models from OllamaService', () async {
      await chatProvider.refreshModels();
      verify(mockOllamaService.getModels()).called(1);
    });

    test('handles errors when fetching models', () async {
      when(mockOllamaService.getModels()).thenThrow(Exception('Test error'));

      await chatProvider.refreshModels();
      expect(chatProvider.error, isNotNull);
    });

    test('creates new chat', () async {
      await chatProvider.createNewChat('llama2');

      expect(chatProvider.activeChat, isNotNull);
      expect(chatProvider.activeChat!.modelName, 'llama2');
    });

    test('sends message and receives response', () async {
      const message = 'Hello';
      final mockResponse = OllamaResponse(response: 'Hi there!', context: []);

      when(mockOllamaService.generateResponseWithContext(
        any,
        model: anyNamed('model'),
        processedFiles: anyNamed('processedFiles'),
        context: anyNamed('context'),
        conversationHistory: anyNamed('conversationHistory'),
        contextLength: anyNamed('contextLength'),
        isCancelled: anyNamed('isCancelled'),
      )).thenAnswer((_) async => mockResponse);

      await chatProvider.createNewChat('llama2');
      await chatProvider.sendMessage(message);

      verify(mockSettingsProvider.getOllamaService());
      verify(mockOllamaService.generateResponseWithContext(
        any,
        model: anyNamed('model'),
        processedFiles: anyNamed('processedFiles'),
        context: anyNamed('context'),
        conversationHistory: anyNamed('conversationHistory'),
        contextLength: anyNamed('contextLength'),
        isCancelled: anyNamed('isCancelled'),
      )).called(1);

      expect(chatProvider.activeChat!.messages.length,
          2); // user message + AI response
      expect(chatProvider.activeChat!.messages.last.content, 'Hi there!');
    });

    test('handles streaming responses', () async {
      const message = 'Hello';
      final responses = [
        OllamaStreamResponse(response: 'Hi', done: false),
        OllamaStreamResponse(response: ' there', done: false),
        OllamaStreamResponse(response: '!', done: true),
      ];

      when(mockSettingsProvider.settings).thenReturn(
        AppSettings(showLiveResponse: true),
      );

      when(mockOllamaService.generateStreamingResponseWithContext(
        any,
        model: anyNamed('model'),
        processedFiles: anyNamed('processedFiles'),
        context: anyNamed('context'),
        conversationHistory: anyNamed('conversationHistory'),
        contextLength: anyNamed('contextLength'),
        isCancelled: anyNamed('isCancelled'),
      )).thenAnswer((_) => Stream.fromIterable(responses));

      await chatProvider.createNewChat('llama2');
      await chatProvider.sendMessage(message);

      verify(mockSettingsProvider.getOllamaService());
      verify(mockOllamaService.generateStreamingResponseWithContext(
        any,
        model: anyNamed('model'),
        processedFiles: anyNamed('processedFiles'),
        context: anyNamed('context'),
        conversationHistory: anyNamed('conversationHistory'),
        contextLength: anyNamed('contextLength'),
        isCancelled: anyNamed('isCancelled'),
      )).called(1);

      expect(chatProvider.activeChat!.messages.last.content, 'Hi there!');
    });
  });

  group('Stop Button Functionality', () {
    testWidgets('isAnyOperationInProgress getter exists and works',
        (tester) async {
      // Verify the new getter exists
      expect(chatProvider.isAnyOperationInProgress, isA<bool>());

      // Initially should be false
      expect(chatProvider.isAnyOperationInProgress, false);
    });

    testWidgets('cancelGeneration method completes without errors',
        (tester) async {
      // Just verify the method can be called without throwing
      expect(() => chatProvider.cancelGeneration(), returnsNormally);

      // Verify operation states are false after cancellation
      expect(chatProvider.isGenerating, false);
      expect(chatProvider.isSendingMessage, false);
      expect(chatProvider.isProcessingFiles, false);
      expect(chatProvider.isAnyOperationInProgress, false);
    });
  });
}
