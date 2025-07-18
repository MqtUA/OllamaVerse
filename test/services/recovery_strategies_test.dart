import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/recovery_strategies.dart';
import '../../lib/services/error_recovery_service.dart';
import '../../lib/utils/error_handler.dart';
import '../../lib/services/ollama_service.dart';
import '../../lib/services/model_manager.dart';

// Mock classes for testing
class MockOllamaService extends OllamaService {
  final bool shouldSucceed;
  int testConnectionCallCount = 0;

  MockOllamaService({
    this.shouldSucceed = true,
  }) : super(
    client: MockHttpClient(),
    settings: MockAppSettings(),
  );

  @override
  Future<bool> testConnection() async {
    testConnectionCallCount++;
    return shouldSucceed;
  }
}

class MockModelManager extends ModelManager {
  final bool shouldSucceed;
  final List<String> mockModels;
  int refreshCallCount = 0;

  MockModelManager({
    this.shouldSucceed = true,
    this.mockModels = const ['model1', 'model2'],
  }) : super(settingsProvider: MockSettingsProvider());

  @override
  Future<bool> refreshModels() async {
    refreshCallCount++;
    if (shouldSucceed) {
      // Simulate successful model loading
      return true;
    }
    return false;
  }

  @override
  bool get hasModels => shouldSucceed ? mockModels.isNotEmpty : false;

  @override
  List<String> get availableModels => shouldSucceed ? mockModels : [];
}

// Mock implementations for dependencies
class MockHttpClient {
  // Mock implementation
}

class MockAppSettings {
  // Mock implementation
}

class MockSettingsProvider implements ISettingsProvider {
  @override
  bool get isLoading => false;

  @override
  OllamaService getOllamaService() => MockOllamaService();

  @override
  Future<String> getLastSelectedModel() async => 'model1';

  @override
  Future<void> setLastSelectedModel(String modelName) async {}
}

void main() {
  group('ConnectionRecoveryStrategy', () {
    test('should succeed when connection test passes', () async {
      final ollamaService = MockOllamaService(shouldSucceed: true);
      final strategy = ConnectionRecoveryStrategy(ollamaService: ollamaService);
      
      final errorState = ErrorState(
        error: OllamaConnectionException('Connection failed'),
        errorType: ErrorType.connection,
        message: 'Connection failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('Connection restored'));
      expect(ollamaService.testConnectionCallCount, equals(1));
    });

    test('should fail when connection test fails', () async {
      final ollamaService = MockOllamaService(shouldSucceed: false);
      final strategy = ConnectionRecoveryStrategy(ollamaService: ollamaService);
      
      final errorState = ErrorState(
        error: OllamaConnectionException('Connection failed'),
        errorType: ErrorType.connection,
        message: 'Connection failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isFalse);
      expect(result.message, equals('Connection test failed'));
      expect(ollamaService.testConnectionCallCount, equals(1));
    });

    test('should handle timeout during connection test', () async {
      final strategy = ConnectionRecoveryStrategy(
        ollamaService: MockOllamaService(shouldSucceed: true),
        testTimeout: const Duration(milliseconds: 1),
      );
      
      final errorState = ErrorState(
        error: OllamaConnectionException('Connection failed'),
        errorType: ErrorType.connection,
        message: 'Connection failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isFalse);
      expect(result.message, contains('Connection recovery failed'));
    });
  });

  group('ModelLoadingRecoveryStrategy', () {
    test('should succeed when model refresh succeeds', () async {
      final modelManager = MockModelManager(shouldSucceed: true);
      final strategy = ModelLoadingRecoveryStrategy(modelManager: modelManager);
      
      final errorState = ErrorState(
        error: Exception('Model loading failed'),
        errorType: ErrorType.unknown,
        message: 'Model loading failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('Models loaded successfully'));
      expect(result.data?['modelCount'], equals(2));
      expect(modelManager.refreshCallCount, equals(1));
    });

    test('should retry multiple times before failing', () async {
      final modelManager = MockModelManager(shouldSucceed: false);
      final strategy = ModelLoadingRecoveryStrategy(
        modelManager: modelManager,
        maxRetries: 2,
      );
      
      final errorState = ErrorState(
        error: Exception('Model loading failed'),
        errorType: ErrorType.unknown,
        message: 'Model loading failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isFalse);
      expect(result.message, contains('Failed to load models after 2 attempts'));
      expect(modelManager.refreshCallCount, equals(2));
    });
  });

  group('StreamingRecoveryStrategy', () {
    test('should complete cooldown period', () async {
      final strategy = StreamingRecoveryStrategy(
        cooldownPeriod: const Duration(milliseconds: 10),
      );
      
      final errorState = ErrorState(
        error: Exception('Streaming failed'),
        errorType: ErrorType.unknown,
        message: 'Streaming failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final stopwatch = Stopwatch()..start();
      final result = await strategy.recover(errorState);
      stopwatch.stop();
      
      expect(result.success, isTrue);
      expect(result.message, equals('Streaming service ready for retry'));
      expect(result.data?['cooldownPeriod'], equals(0)); // 10ms rounds to 0 seconds
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10));
    });
  });

  group('FileProcessingRecoveryStrategy', () {
    test('should succeed for retryable errors', () async {
      final strategy = FileProcessingRecoveryStrategy();
      
      final errorState = ErrorState(
        error: Exception('File processing failed'),
        errorType: ErrorType.unknown,
        message: 'File processing failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('File processing ready for retry'));
    });

    test('should fail for validation errors', () async {
      final strategy = FileProcessingRecoveryStrategy();
      
      final errorState = ErrorState(
        error: ArgumentError('Invalid file'),
        errorType: ErrorType.validation,
        message: 'Invalid file',
        suggestions: [],
        canRetry: false,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isFalse);
      expect(result.message, equals('File processing error requires user intervention'));
    });

    test('should fail for format errors', () async {
      final strategy = FileProcessingRecoveryStrategy();
      
      final errorState = ErrorState(
        error: FormatException('Invalid format'),
        errorType: ErrorType.format,
        message: 'Invalid format',
        suggestions: [],
        canRetry: false,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isFalse);
      expect(result.message, equals('File processing error requires user intervention'));
    });
  });

  group('StateRecoveryStrategy', () {
    test('should call reset callback', () async {
      bool callbackCalled = false;
      final strategy = StateRecoveryStrategy(
        resetStateCallback: () {
          callbackCalled = true;
        },
      );
      
      final errorState = ErrorState(
        error: StateError('Invalid state'),
        errorType: ErrorType.state,
        message: 'Invalid state',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('State reset successfully'));
      expect(callbackCalled, isTrue);
    });

    test('should succeed without callback', () async {
      final strategy = StateRecoveryStrategy();
      
      final errorState = ErrorState(
        error: StateError('Invalid state'),
        errorType: ErrorType.state,
        message: 'Invalid state',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('State reset successfully'));
    });
  });

  group('TitleGenerationRecoveryStrategy', () {
    test('should always succeed', () async {
      final strategy = TitleGenerationRecoveryStrategy();
      
      final errorState = ErrorState(
        error: Exception('Title generation failed'),
        errorType: ErrorType.unknown,
        message: 'Title generation failed',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await strategy.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('Title generation cleared, will use fallback'));
    });
  });

  group('CompositeRecoveryStrategy', () {
    test('should try first successful strategy', () async {
      final strategy1 = MockRecoveryStrategy(shouldSucceed: false);
      final strategy2 = MockRecoveryStrategy(shouldSucceed: true, message: 'Success');
      final strategy3 = MockRecoveryStrategy(shouldSucceed: true);
      
      final composite = CompositeRecoveryStrategy([strategy1, strategy2, strategy3]);
      
      final errorState = ErrorState(
        error: Exception('Test error'),
        errorType: ErrorType.unknown,
        message: 'Test error',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await composite.recover(errorState);
      
      expect(result.success, isTrue);
      expect(result.message, equals('Success'));
      expect(strategy1.callCount, equals(1));
      expect(strategy2.callCount, equals(1));
      expect(strategy3.callCount, equals(0)); // Should not be called
    });

    test('should fail if all strategies fail', () async {
      final strategy1 = MockRecoveryStrategy(shouldSucceed: false, message: 'Fail 1');
      final strategy2 = MockRecoveryStrategy(shouldSucceed: false, message: 'Fail 2');
      
      final composite = CompositeRecoveryStrategy([strategy1, strategy2]);
      
      final errorState = ErrorState(
        error: Exception('Test error'),
        errorType: ErrorType.unknown,
        message: 'Test error',
        suggestions: [],
        canRetry: true,
        timestamp: DateTime.now(),
      );
      
      final result = await composite.recover(errorState);
      
      expect(result.success, isFalse);
      expect(result.message, contains('All recovery strategies failed'));
      expect(result.message, contains('Fail 1'));
      expect(result.message, contains('Fail 2'));
      expect(strategy1.callCount, equals(1));
      expect(strategy2.callCount, equals(1));
    });
  });

  group('RecoveryStrategyFactory', () {
    test('should create connection strategy for ollama service', () {
      final ollamaService = MockOllamaService();
      
      final strategy = RecoveryStrategyFactory.createForService(
        'ollama',
        ollamaService: ollamaService,
      );
      
      expect(strategy, isA<ConnectionRecoveryStrategy>());
    });

    test('should create composite strategy for model service', () {
      final ollamaService = MockOllamaService();
      final modelManager = MockModelManager();
      
      final strategy = RecoveryStrategyFactory.createForService(
        'model',
        ollamaService: ollamaService,
        modelManager: modelManager,
      );
      
      expect(strategy, isA<CompositeRecoveryStrategy>());
    });

    test('should create composite strategy for streaming service', () {
      final ollamaService = MockOllamaService();
      
      final strategy = RecoveryStrategyFactory.createForService(
        'streaming',
        ollamaService: ollamaService,
      );
      
      expect(strategy, isA<CompositeRecoveryStrategy>());
    });

    test('should create file processing strategy', () {
      final strategy = RecoveryStrategyFactory.createForService('fileprocessing');
      
      expect(strategy, isA<FileProcessingRecoveryStrategy>());
    });

    test('should create state strategy', () {
      bool callbackCalled = false;
      final strategy = RecoveryStrategyFactory.createForService(
        'state',
        resetStateCallback: () => callbackCalled = true,
      );
      
      expect(strategy, isA<StateRecoveryStrategy>());
    });

    test('should create title generation strategy', () {
      final strategy = RecoveryStrategyFactory.createForService('titlegeneration');
      
      expect(strategy, isA<TitleGenerationRecoveryStrategy>());
    });

    test('should create fallback strategy for unknown service', () {
      final strategy = RecoveryStrategyFactory.createForService('unknown');
      
      expect(strategy, isA<StateRecoveryStrategy>());
    });
  });
}

// Mock recovery strategy for testing
class MockRecoveryStrategy extends RecoveryStrategy {
  final bool shouldSucceed;
  final String? message;
  final Map<String, dynamic>? data;
  int callCount = 0;

  MockRecoveryStrategy({
    this.shouldSucceed = true,
    this.message,
    this.data,
  });

  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    callCount++;
    
    if (shouldSucceed) {
      return RecoveryResult.success(message, data);
    } else {
      return RecoveryResult.failure(message ?? 'Recovery failed', data);
    }
  }
}