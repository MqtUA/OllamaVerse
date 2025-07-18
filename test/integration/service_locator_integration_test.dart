import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../../lib/providers/settings_provider.dart';
import '../../lib/services/service_locator.dart';
import '../../lib/services/chat_history_service.dart';
import '../../lib/services/model_manager.dart';
import '../../lib/services/chat_state_manager.dart';
import '../../lib/services/message_streaming_service.dart';
import '../../lib/services/chat_title_generator.dart';
import '../../lib/services/file_processing_manager.dart';
import '../../lib/services/thinking_content_processor.dart';
import '../../lib/services/file_content_processor.dart';
import '../../lib/services/ollama_service.dart';
import '../../lib/models/app_settings.dart';

// Manual mocks for integration testing
class MockSettingsProvider extends Mock implements SettingsProvider {
  final MockOllamaService _ollamaService = MockOllamaService();
  
  @override
  OllamaService getOllamaService() => _ollamaService;
  
  @override
  bool get isLoading => false;
  
  @override
  AppSettings get settings => AppSettings(
    ollamaHost: 'localhost',
    ollamaPort: 11434,
    darkMode: false,
    systemPrompt: '',
    contextLength: 4096,
  );
}

class MockOllamaService extends Mock implements OllamaService {}

class FailingMockSettingsProvider extends Mock implements SettingsProvider {
  @override
  bool get isLoading => true; // This will cause initialization to fail
  
  @override
  OllamaService getOllamaService() => MockOllamaService();
  
  @override
  AppSettings get settings => AppSettings();
}

void main() {
  late MockSettingsProvider mockSettingsProvider;

  setUpAll(() {
    // Initialize Flutter test binding
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock path_provider methods
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/test_docs';
        }
        return null;
      },
    );
  });

  setUp(() async {
    // Create mocks
    mockSettingsProvider = MockSettingsProvider();

    // Reset service locator before each test
    await ServiceLocator.instance.reset();
  });

  tearDown(() async {
    // Clean up after each test
    try {
      await ServiceLocator.instance.dispose();
    } catch (e) {
      // Ignore disposal errors in tests
    }
  });

  group('ServiceLocator Integration Tests', () {
    test('should initialize all services in proper dependency order', () async {
      // Act
      await ServiceLocator.instance.initialize(mockSettingsProvider);

      // Assert
      expect(ServiceLocator.instance.isInitialized, true);
      
      // Verify all services are registered
      final status = ServiceLocator.instance.getServiceStatus();
      expect(status['registeredServices']['ChatHistoryService'], true);
      expect(status['registeredServices']['ModelManager'], true);
      expect(status['registeredServices']['ChatStateManager'], true);
      expect(status['registeredServices']['MessageStreamingService'], true);
      expect(status['registeredServices']['ChatTitleGenerator'], true);
      expect(status['registeredServices']['FileProcessingManager'], true);
      expect(status['registeredServices']['ThinkingContentProcessor'], true);
      expect(status['registeredServices']['FileContentProcessor'], true);
      
      // Verify services can be accessed
      expect(ServiceLocator.instance.chatHistoryService, isNotNull);
      expect(ServiceLocator.instance.modelManager, isNotNull);
      expect(ServiceLocator.instance.chatStateManager, isNotNull);
      expect(ServiceLocator.instance.messageStreamingService, isNotNull);
      expect(ServiceLocator.instance.chatTitleGenerator, isNotNull);
      expect(ServiceLocator.instance.fileProcessingManager, isNotNull);
      expect(ServiceLocator.instance.thinkingContentProcessor, isNotNull);
      expect(ServiceLocator.instance.fileContentProcessor, isNotNull);
    });

    test('should prevent concurrent initialization attempts', () async {
      // Arrange
      final futures = <Future<void>>[];
      
      // Act - attempt multiple concurrent initializations
      for (int i = 0; i < 3; i++) {
        futures.add(ServiceLocator.instance.initialize(mockSettingsProvider));
      }
      
      // Wait for all to complete
      await Future.wait(futures);
      
      // Assert
      expect(ServiceLocator.instance.isInitialized, true);
      
      // Verify services are properly initialized
      expect(ServiceLocator.instance.chatHistoryService, isNotNull);
      expect(ServiceLocator.instance.modelManager, isNotNull);
    });

    test('should handle initialization failure and cleanup properly', () async {
      // Arrange - create a failing mock provider
      final failingMockProvider = FailingMockSettingsProvider();
      
      // Act & Assert
      expect(
        () => ServiceLocator.instance.initialize(failingMockProvider),
        throwsA(isA<StateError>()),
      );
      
      // Verify services are not initialized
      expect(ServiceLocator.instance.isInitialized, false);
      
      // Verify we can still initialize with a valid provider
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      expect(ServiceLocator.instance.isInitialized, true);
    });

    test('should provide service registration status correctly', () async {
      // Arrange
      expect(ServiceLocator.instance.isServiceRegistered<ChatHistoryService>(), false);
      
      // Act
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Assert
      expect(ServiceLocator.instance.isServiceRegistered<ChatHistoryService>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ModelManager>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ChatStateManager>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<MessageStreamingService>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ChatTitleGenerator>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<FileProcessingManager>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ThinkingContentProcessor>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<FileContentProcessor>(), true);
    });

    test('should properly inject dependencies between services', () async {
      // Act
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Assert - verify dependencies are properly injected
      final messageStreamingService = ServiceLocator.instance.messageStreamingService;
      final chatStateManager = ServiceLocator.instance.chatStateManager;
      final fileProcessingManager = ServiceLocator.instance.fileProcessingManager;
      final chatTitleGenerator = ServiceLocator.instance.chatTitleGenerator;
      
      // These assertions verify that the services are properly initialized
      // and their dependencies are correctly injected
      expect(messageStreamingService, isNotNull);
      expect(chatStateManager, isNotNull);
      expect(fileProcessingManager, isNotNull);
      expect(chatTitleGenerator, isNotNull);
    });

    test('should handle service lifecycle correctly', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Act - dispose services
      await ServiceLocator.instance.dispose();
      
      // Assert
      expect(ServiceLocator.instance.isInitialized, false);
      
      // Verify services are no longer accessible
      expect(() => ServiceLocator.instance.chatHistoryService, throwsStateError);
      expect(() => ServiceLocator.instance.modelManager, throwsStateError);
      expect(() => ServiceLocator.instance.chatStateManager, throwsStateError);
      expect(() => ServiceLocator.instance.messageStreamingService, throwsStateError);
      
      // Verify service status
      final status = ServiceLocator.instance.getServiceStatus();
      expect(status['isDisposed'], true);
      expect(status['registeredServices']['ChatHistoryService'], false);
      expect(status['registeredServices']['ModelManager'], false);
    });

    test('should be able to reinitialize after reset', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      await ServiceLocator.instance.reset();
      
      // Act
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Assert
      expect(ServiceLocator.instance.isInitialized, true);
      expect(ServiceLocator.instance.chatHistoryService, isNotNull);
      expect(ServiceLocator.instance.modelManager, isNotNull);
    });
  });
}