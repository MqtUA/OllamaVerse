// Flutter test imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ollamaverse/providers/chat_provider.dart';
import 'package:ollamaverse/providers/settings_provider.dart';
import 'package:ollamaverse/services/chat_history_service.dart';
import 'package:ollamaverse/services/ollama_service.dart';

import 'package:ollamaverse/models/app_settings.dart';

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

  setUp(() {
    mockOllamaService = MockOllamaServiceTest();
    mockChatHistoryService = MockChatHistoryServiceTest();
    mockSettingsProvider = MockSettingsProviderTest();

    // Setup mock behavior
    when(mockOllamaService.getModels()).thenAnswer((_) async => testModels);

    // Setup mock settings provider
    when(mockSettingsProvider.settings).thenReturn(
      AppSettings(showLiveResponse: false),
    );
    when(mockSettingsProvider.getOllamaService()).thenReturn(mockOllamaService);
    when(mockSettingsProvider.getLastSelectedModel())
        .thenAnswer((_) async => 'llama2');

    // Create the provider with the mocks
    chatProvider = ChatProvider(
      chatHistoryService: mockChatHistoryService,
      settingsProvider: mockSettingsProvider,
    );
  });

  group('ChatProvider', () {
    test('initializes with empty chats', () {
      expect(chatProvider.chats, isEmpty);
    });

    test('refreshModels fetches models from OllamaService', () async {
      await chatProvider.refreshModels();
      verify(mockSettingsProvider.getOllamaService()).called(greaterThan(0));
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
      const response = 'Hi there!';

      when(mockOllamaService.generateResponse(
        any,
        model: anyNamed('model'),
      )).thenAnswer((_) async => response);

      await chatProvider.createNewChat('llama2');
      await chatProvider.sendMessage(message);

      verify(mockSettingsProvider.getOllamaService()).called(greaterThan(0));
      verify(mockOllamaService.generateResponse(
        message,
        model: 'llama2',
      )).called(1);

      expect(chatProvider.activeChat!.messages.length,
          2); // user message + AI response
      expect(chatProvider.activeChat!.messages.last.content, response);
    });

    test('handles streaming responses', () async {
      const message = 'Hello';
      const responses = ['Hi', ' there', '!'];

      when(mockSettingsProvider.settings).thenReturn(
        AppSettings(showLiveResponse: true),
      );

      when(mockOllamaService.generateStreamingResponse(
        any,
        model: anyNamed('model'),
        context: anyNamed('context'),
      )).thenAnswer((_) => Stream.fromIterable(responses));

      await chatProvider.createNewChat('llama2');
      await chatProvider.sendMessage(message);

      verify(mockSettingsProvider.getOllamaService()).called(greaterThan(0));
      verify(mockOllamaService.generateStreamingResponse(
        message,
        model: 'llama2',
      )).called(1);

      expect(chatProvider.activeChat!.messages.last.content, responses.join());
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
