import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:ollama_client/providers/settings_provider.dart';
import 'package:ollama_client/services/service_locator.dart';
import 'package:ollama_client/services/chat_history_service.dart';
import 'package:ollama_client/services/model_manager.dart';
import 'package:ollama_client/services/chat_state_manager.dart';
import 'package:ollama_client/services/message_streaming_service.dart';
import 'package:ollama_client/services/chat_title_generator.dart';
import 'package:ollama_client/services/file_processing_manager.dart';
import 'package:ollama_client/services/thinking_content_processor.dart';
import 'package:ollama_client/services/file_content_processor.dart';
import 'package:ollama_client/services/ollama_service.dart';

// Create manual mocks since we're having issues with code generation
class MockSettingsProvider extends Mock implements SettingsProvider {}
class MockOllamaService extends Mock implements OllamaService {}
void main() {
  late MockSettingsProvider mockSettingsProvider;
  late MockOllamaService mockOllamaService;

  setUp(() async {
    // Create mocks
    mockSettingsProvider = MockSettingsProvider();
    mockOllamaService = MockOllamaService();

    // Configure mock behavior
    when(mockSettingsProvider.getOllamaService()).thenReturn(mockOllamaService);
    when(mockSettingsProvider.isLoading).thenReturn(false);

    // Reset service locator before each test
    await ServiceLocator.instance.reset();
  });

  tearDown(() async {
    // Clean up after each test
    await ServiceLocator.instance.dispose();
  });

  group('ServiceLocator Initialization', () {
    test('should initialize all services correctly', () async {
      // Act
      await ServiceLocator.instance.initialize(mockSettingsProvider);

      // Assert
      expect(ServiceLocator.instance.isInitialized, true);
      expect(ServiceLocator.instance.isServiceRegistered<ChatHistoryService>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ModelManager>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ChatStateManager>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<MessageStreamingService>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ChatTitleGenerator>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<FileProcessingManager>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<ThinkingContentProcessor>(), true);
      expect(ServiceLocator.instance.isServiceRegistered<FileContentProcessor>(), true);
    });

    test('should not reinitialize if already initialized', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Create a new mock to verify it's not used
      final newMockSettingsProvider = MockSettingsProvider();
      
      // Act
      await ServiceLocator.instance.initialize(newMockSettingsProvider);
      
      // Assert - should still be using the original provider
      verify(mockSettingsProvider.getOllamaService()).called(greaterThan(0));
      verifyNever(newMockSettingsProvider.getOllamaService());
    });
  });

  group('ServiceLocator Service Access', () {
    test('should throw error when accessing services before initialization', () {
      // Assert
      expect(() => ServiceLocator.instance.chatHistoryService, throwsStateError);
      expect(() => ServiceLocator.instance.modelManager, throwsStateError);
      expect(() => ServiceLocator.instance.chatStateManager, throwsStateError);
      expect(() => ServiceLocator.instance.messageStreamingService, throwsStateError);
      expect(() => ServiceLocator.instance.chatTitleGenerator, throwsStateError);
      expect(() => ServiceLocator.instance.fileProcessingManager, throwsStateError);
      expect(() => ServiceLocator.instance.thinkingContentProcessor, throwsStateError);
      expect(() => ServiceLocator.instance.fileContentProcessor, throwsStateError);
    });

    test('should provide access to all services after initialization', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Act & Assert - should not throw
      expect(ServiceLocator.instance.chatHistoryService, isNotNull);
      expect(ServiceLocator.instance.modelManager, isNotNull);
      expect(ServiceLocator.instance.chatStateManager, isNotNull);
      expect(ServiceLocator.instance.messageStreamingService, isNotNull);
      expect(ServiceLocator.instance.chatTitleGenerator, isNotNull);
      expect(ServiceLocator.instance.fileProcessingManager, isNotNull);
      expect(ServiceLocator.instance.thinkingContentProcessor, isNotNull);
      expect(ServiceLocator.instance.fileContentProcessor, isNotNull);
    });
  });

  group('ServiceLocator Disposal', () {
    test('should dispose all services correctly', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Act
      await ServiceLocator.instance.dispose();
      
      // Assert
      expect(ServiceLocator.instance.isInitialized, false);
      expect(() => ServiceLocator.instance.chatHistoryService, throwsStateError);
      
      // Check service status
      final status = ServiceLocator.instance.getServiceStatus();
      expect(status['isDisposed'], true);
      expect(status['registeredServices']['ChatHistoryService'], false);
      expect(status['registeredServices']['ModelManager'], false);
      expect(status['registeredServices']['ChatStateManager'], false);
      expect(status['registeredServices']['MessageStreamingService'], false);
      expect(status['registeredServices']['ChatTitleGenerator'], false);
      expect(status['registeredServices']['FileProcessingManager'], false);
      expect(status['registeredServices']['ThinkingContentProcessor'], false);
      expect(status['registeredServices']['FileContentProcessor'], false);
    });

    test('should not dispose twice', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      await ServiceLocator.instance.dispose();
      
      // Act - should not throw
      await ServiceLocator.instance.dispose();
      
      // Assert
      expect(ServiceLocator.instance.isInitialized, false);
    });
  });

  group('ServiceLocator Reset', () {
    test('should reset the service locator for testing', () async {
      // Arrange
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Act
      await ServiceLocator.instance.reset();
      
      // Assert
      expect(ServiceLocator.instance.isInitialized, false);
      
      // Should be able to initialize again
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      expect(ServiceLocator.instance.isInitialized, true);
    });
  });

  group('ServiceLocator Integration', () {
    test('should maintain proper dependency order during initialization', () async {
      // Act
      await ServiceLocator.instance.initialize(mockSettingsProvider);
      
      // Assert - services should be accessible and properly configured
      final chatStateManager = ServiceLocator.instance.chatStateManager;
      final messageStreamingService = ServiceLocator.instance.messageStreamingService;
      final fileProcessingManager = ServiceLocator.instance.fileProcessingManager;
      
      expect(chatStateManager, isNotNull);
      expect(messageStreamingService, isNotNull);
      expect(fileProcessingManager, isNotNull);
    });
  });
}