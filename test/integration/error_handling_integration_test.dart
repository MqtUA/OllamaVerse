import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/error_recovery_service.dart';
import '../../lib/services/recovery_strategies.dart';
import '../../lib/services/chat_state_manager.dart';
import '../../lib/services/model_manager.dart';
import '../../lib/services/chat_history_service.dart';
import '../../lib/models/chat.dart';
import '../../lib/utils/error_handler.dart';
import '../../lib/services/ollama_service.dart';

// Mock implementations for integration testing
class MockChatHistoryService implements ChatHistoryService {
  @override
  bool get isInitialized => true;
  
  @override
  List<Chat> get chats => [];
  
  @override
  Stream<List<Chat>> get chatStream => Stream.value([]);
  
  @override
  Future<void> saveChat(Chat chat) async {}
  
  @override
  Future<void> deleteChat(String chatId) async {}
  
  @override
  Future<void> dispose() async {}
  
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

class MockOllamaService implements OllamaService {
  final bool shouldFailConnection;
  final bool shouldFailModels;
  int connectionAttempts = 0;
  int modelAttempts = 0;

  MockOllamaService({
    this.shouldFailConnection = false,
    this.shouldFailModels = false,
  });

  @override
  Future<bool> testConnection() async {
    connectionAttempts++;
    if (shouldFailConnection) {
      throw OllamaConnectionException('Mock connection failure');
    }
    return true;
  }

  @override
  Future<List<String>> getModels() async {
    modelAttempts++;
    if (shouldFailModels) {
      throw OllamaApiException('Mock API failure');
    }
    return ['model1', 'model2'];
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockThinkingContentProcessor {
  // Mock implementation
}



void main() {
  group('Error Handling Integration Tests', () {
    late ErrorRecoveryService errorRecoveryService;
    late ChatStateManager chatStateManager;
    late ModelManager modelManager;
    // late MockOllamaService ollamaService; // Unused variable removed

    setUp(() {
      errorRecoveryService = ErrorRecoveryService();
      // ollamaService = MockOllamaService(); // Unused variable removed
      
      chatStateManager = ChatStateManager(
        chatHistoryService: MockChatHistoryService(),
        errorRecoveryService: errorRecoveryService,
      );
      
      modelManager = ModelManager(
        settingsProvider: MockSettingsProvider(),
        errorRecoveryService: errorRecoveryService,
      );
    });

    tearDown(() {
      errorRecoveryService.dispose();
      chatStateManager.dispose();
    });

    group('Service Integration with Error Recovery', () {
      test('should handle ChatStateManager errors with recovery', () async {
        // Register recovery strategy
        errorRecoveryService.registerRecoveryStrategy(
          'ChatStateManager',
          StateRecoveryStrategy(resetStateCallback: () {
            // Reset state callback - this would reset the chat state manager
          }),
        );

        // Simulate an error in chat state manager
        await errorRecoveryService.handleServiceError(
          'ChatStateManager',
          StateError('Invalid chat state'),
          operation: 'setActiveChat',
        );

        // Since recovery strategy is successful, error should be cleared
        expect(errorRecoveryService.hasServiceError('ChatStateManager'), isFalse);
        
        // Verify service health is recovering after successful recovery
        final health = errorRecoveryService.getServiceHealth('ChatStateManager');
        expect(health, equals(ServiceHealthStatus.recovering));
      });

      test('should handle ModelManager errors with recovery', () async {
        // Simulate an error without recovery strategy to test error tracking
        await errorRecoveryService.handleServiceError(
          'ModelManager',
          OllamaConnectionException('Connection failed'),
          operation: 'loadModels',
        );
        
        // Error should be recorded since no recovery strategy is registered
        expect(errorRecoveryService.hasServiceError('ModelManager'), isTrue);
        
        // Service health should be degraded
        final health = errorRecoveryService.getServiceHealth('ModelManager');
        expect(health, equals(ServiceHealthStatus.degraded));
      });

      test('should coordinate multiple service errors', () async {
        // Simulate errors in multiple services
        await errorRecoveryService.handleServiceError(
          'ChatStateManager',
          StateError('Chat state error'),
        );
        
        await errorRecoveryService.handleServiceError(
          'ModelManager',
          OllamaConnectionException('Connection error'),
        );
        
        await errorRecoveryService.handleServiceError(
          'MessageStreamingService',
          TimeoutException('Streaming timeout', Duration(seconds: 30)),
        );

        // Verify all errors are tracked
        expect(errorRecoveryService.hasServiceError('ChatStateManager'), isTrue);
        expect(errorRecoveryService.hasServiceError('ModelManager'), isTrue);
        expect(errorRecoveryService.hasServiceError('MessageStreamingService'), isTrue);

        // Check system health
        final systemHealth = errorRecoveryService.getSystemHealth();
        expect(systemHealth, equals(SystemHealthStatus.degraded));

        // Clear all errors
        errorRecoveryService.clearAllErrors();
        
        // Verify all errors are cleared
        expect(errorRecoveryService.hasServiceError('ChatStateManager'), isFalse);
        expect(errorRecoveryService.hasServiceError('ModelManager'), isFalse);
        expect(errorRecoveryService.hasServiceError('MessageStreamingService'), isFalse);
      });
    });

    group('Circuit Breaker Integration', () {
      test('should open circuit breaker after repeated failures', () async {
        const serviceName = 'TestService';
        
        // Generate multiple errors to trigger circuit breaker
        for (int i = 0; i < 6; i++) {
          await errorRecoveryService.handleServiceError(
            serviceName,
            OllamaConnectionException('Connection error $i'),
          );
        }

        // Circuit breaker should be open
        expect(errorRecoveryService.isServiceCircuitBreakerOpen(serviceName), isTrue);
        
        // Service should be unavailable
        final health = errorRecoveryService.getServiceHealth(serviceName);
        expect(health, equals(ServiceHealthStatus.unavailable));

        // Operations should fail with ServiceUnavailableException
        expect(
          () => errorRecoveryService.executeServiceOperation(
            serviceName,
            () async => 'success',
          ),
          throwsA(isA<ServiceUnavailableException>()),
        );
      });
    });

    group('Recovery Strategy Integration', () {
      test('should successfully recover from connection errors', () async {
        final workingOllamaService = MockOllamaService(shouldFailConnection: false);
        
        // Register connection recovery strategy
        errorRecoveryService.registerRecoveryStrategy(
          'ConnectionTest',
          ConnectionRecoveryStrategy(ollamaService: workingOllamaService),
        );

        // Simulate connection error and recovery
        final result = await errorRecoveryService.handleServiceError<String>(
          'ConnectionTest',
          OllamaConnectionException('Connection failed'),
          recoveryAction: () async => 'recovered',
        );

        // Recovery should succeed
        expect(result, equals('recovered'));
        expect(errorRecoveryService.hasServiceError('ConnectionTest'), isFalse);
      });

      test('should handle failed recovery gracefully', () async {
        final failingOllamaService = MockOllamaService(shouldFailConnection: true);
        
        // Register connection recovery strategy that will fail
        errorRecoveryService.registerRecoveryStrategy(
          'FailingConnectionTest',
          ConnectionRecoveryStrategy(ollamaService: failingOllamaService),
        );

        // Simulate connection error and failed recovery
        final result = await errorRecoveryService.handleServiceError<String>(
          'FailingConnectionTest',
          OllamaConnectionException('Connection failed'),
          recoveryAction: () async => 'recovered',
        );

        // Recovery should fail
        expect(result, isNull);
        expect(errorRecoveryService.hasServiceError('FailingConnectionTest'), isTrue);
      });
    });

    group('Error State Streaming', () {
      test('should stream error state changes', () async {
        final errorStates = <Map<String, ErrorState>>[];
        
        // Listen to error state stream
        final subscription = errorRecoveryService.errorStateStream.listen(
          (states) => errorStates.add(Map.from(states)),
        );

        // Generate some errors
        await errorRecoveryService.handleServiceError(
          'Service1',
          Exception('Error 1'),
        );
        
        await errorRecoveryService.handleServiceError(
          'Service2',
          Exception('Error 2'),
        );

        // Clear one error
        errorRecoveryService.clearServiceError('Service1');

        // Allow stream to process
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify state changes were streamed
        expect(errorStates.length, greaterThan(0));
        
        // Last state should only have Service2 error
        final lastState = errorStates.last;
        expect(lastState.containsKey('Service2'), isTrue);
        expect(lastState.containsKey('Service1'), isFalse);

        await subscription.cancel();
      });
    });

    group('Service State Validation', () {
      test('should validate service states correctly', () {
        // Test valid state
        expect(chatStateManager.validateState(), isTrue);
        expect(modelManager.validateState(), isTrue);

        // Test state reset
        chatStateManager.resetState();
        modelManager.resetState();
        
        // States should still be valid after reset
        expect(chatStateManager.validateState(), isTrue);
        expect(modelManager.validateState(), isTrue);
      });
    });

    group('Error Classification and Recovery', () {
      test('should classify and handle different error types appropriately', () async {
        final testCases = [
          {
            'error': OllamaConnectionException('Connection failed'),
            'expectedType': ErrorType.connection,
            'expectedRetryable': true,
          },
          {
            'error': OllamaApiException('API error'),
            'expectedType': ErrorType.api,
            'expectedRetryable': true,
          },
          {
            'error': TimeoutException('Timeout', Duration(seconds: 30)),
            'expectedType': ErrorType.timeout,
            'expectedRetryable': true,
          },
          {
            'error': ArgumentError('Invalid argument'),
            'expectedType': ErrorType.validation,
            'expectedRetryable': false,
          },
          {
            'error': StateError('Invalid state'),
            'expectedType': ErrorType.state,
            'expectedRetryable': false,
          },
        ];

        for (final testCase in testCases) {
          final error = testCase['error'] as Object;
          final expectedType = testCase['expectedType'] as ErrorType;
          final expectedRetryable = testCase['expectedRetryable'] as bool;

          // Test error classification
          final actualType = ErrorHandler.classifyError(error);
          expect(actualType, equals(expectedType), 
                 reason: 'Error type mismatch for ${error.runtimeType}');

          // Test retryability
          final isRetryable = ErrorHandler.isRetryableError(error);
          expect(isRetryable, equals(expectedRetryable),
                 reason: 'Retryability mismatch for ${error.runtimeType}');

          // Test error state creation
          final errorState = ErrorHandler.createErrorState(error);
          expect(errorState.errorType, equals(expectedType));
          expect(errorState.canRetry, equals(expectedRetryable));
          expect(errorState.message.isNotEmpty, isTrue);
          expect(errorState.suggestions.isNotEmpty, isTrue);
        }
      });
    });
  });
}