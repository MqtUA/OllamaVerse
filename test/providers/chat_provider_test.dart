// Flutter test imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ollamaverse/models/app_settings.dart';
import 'package:ollamaverse/models/ollama_model.dart';
import 'package:ollamaverse/providers/chat_provider.dart';
import 'package:ollamaverse/providers/settings_provider.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/services/storage_service.dart';

// Generate mocks
@GenerateMocks([OllamaService, SettingsProvider, StorageService])
import 'chat_provider_test.mocks.dart';

// We can't easily mock the StorageService since it's instantiated inside ChatProvider
// For a real project, we would refactor ChatProvider to accept StorageService as a constructor parameter
// For now, we'll focus our tests on what we can test without accessing private members

void main() {
  // Initialize Flutter binding for tests that need it
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockOllamaService mockOllamaService;
  late MockSettingsProvider mockSettingsProvider;
  late MockStorageService mockStorageService;
  late ChatProvider chatProvider;
  
  final testSettings = AppSettings(
    ollamaHost: 'localhost',
    ollamaPort: 11434,
    authToken: '',
    contextLength: 4096,
    darkMode: false,
    fontSize: 14,
    showLiveResponse: true,
  );
  
  final testModels = [
    OllamaModel(
      name: 'llama2',
      modifiedAt: '2023-01-01T00:00:00Z',
      size: 4000000000,
      digest: 'abc123',
      details: {},
    ),
    OllamaModel(
      name: 'mistral',
      modifiedAt: '2023-01-02T00:00:00Z',
      size: 5000000000,
      digest: 'def456',
      details: {},
    ),
  ];

  setUp(() {
    mockOllamaService = MockOllamaService();
    mockSettingsProvider = MockSettingsProvider();
    mockStorageService = MockStorageService();
    
    // Setup mock behavior
    when(mockSettingsProvider.settings).thenReturn(testSettings);
    when(mockOllamaService.getModels()).thenAnswer((_) async => testModels);
    when(mockStorageService.loadAllChats()).thenAnswer((_) async => []);
    
    // Create the provider with the mocks we can inject
    chatProvider = ChatProvider(
      ollamaService: mockOllamaService,
      settingsProvider: mockSettingsProvider,
    );
  });

  group('ChatProvider', () {
    test('initializes with empty chats', () {
      // Only check that chats are empty initially
      expect(chatProvider.chats, isEmpty);
      // Models are loaded asynchronously, so we can't check them immediately
    });
    
    test('refreshModels fetches models from OllamaService', () async {
      // Since refreshModels is not a public method, we need to call a method that uses it
      // or expose it for testing
      
      // This is a workaround - in the real implementation, we might want to make refreshModels public
      // or add a public method for testing
      await Future.delayed(Duration.zero); // Allow any pending operations to complete
      
      verify(mockOllamaService.getModels()).called(greaterThanOrEqualTo(1));
      // We can't directly verify chatProvider.availableModels since it's populated asynchronously
    });
    
    test('handles errors when fetching models', () async {
      // Reset the mock to throw an exception
      reset(mockOllamaService);
      when(mockOllamaService.getModels()).thenThrow(
        OllamaConnectionException('Test error')
      );
      
      // Create a new provider instance that will use our mocked service with the error
      final errorProvider = ChatProvider(
        ollamaService: mockOllamaService,
        settingsProvider: mockSettingsProvider,
      );
      
      // Wait for async operations
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify that getModels was called
      verify(mockOllamaService.getModels()).called(greaterThanOrEqualTo(1));
      
      // Verify that the provider has an error state
      expect(errorProvider.error, isNotNull);
    });
    
    test('updates OllamaService when settings change', () async {
      // Simulate settings change
      final newSettings = AppSettings(
        ollamaHost: 'new-host',
        ollamaPort: 12345,
        authToken: 'new-token',
        contextLength: 2048,
        darkMode: true,
        fontSize: 16,
        showLiveResponse: false,
        systemPrompt: '',
      );
      
      // Setup the mock to return the new settings
      when(mockSettingsProvider.settings).thenReturn(newSettings);
      
      // Trigger the listener callback that was registered with the settings provider
      // We need to get the callback that was registered and call it directly
      final Function? callback = 
          verify(mockSettingsProvider.addListener(captureAny)).captured.first;
      
      // Call the captured callback
      callback!();
      
      // Wait for async operations
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify that updateSettings was called with the new settings
      verify(mockOllamaService.updateSettings(newSettings)).called(1);
    });
    
    test('createNewChat adds a new chat', () {
      // Skip this test as it requires mocking StorageService which is instantiated inside ChatProvider
      // In a real project, we would refactor ChatProvider to accept StorageService as a constructor parameter
    }, skip: 'This test requires refactoring ChatProvider to accept StorageService as a parameter');
    
    test('sendMessage calls OllamaService.generateResponse', () {
      // Skip this test as it also requires mocking StorageService which is instantiated inside ChatProvider
      // In a real project, we would refactor ChatProvider to accept StorageService as a constructor parameter
    }, skip: 'This test requires refactoring ChatProvider to accept StorageService as a parameter');
  });
}
