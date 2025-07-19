import 'dart:async';
import '../services/error_recovery_service.dart';
import '../services/ollama_service.dart';
import '../services/model_manager.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Recovery strategy for connection-related errors
class ConnectionRecoveryStrategy extends RecoveryStrategy {
  final OllamaService _ollamaService;
  final Duration _testTimeout;

  ConnectionRecoveryStrategy({
    required OllamaService ollamaService,
    Duration testTimeout = const Duration(seconds: 10),
  })  : _ollamaService = ollamaService,
        _testTimeout = testTimeout;

  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    try {
      AppLogger.info('Attempting connection recovery...');

      // Test connection with timeout
      final isConnected =
          await _ollamaService.testConnection().timeout(_testTimeout);

      if (isConnected) {
        AppLogger.info('Connection recovery successful');
        return RecoveryResult.success('Connection restored');
      } else {
        return RecoveryResult.failure('Connection test failed');
      }
    } catch (error) {
      AppLogger.error('Connection recovery failed', error);
      return RecoveryResult.failure('Connection recovery failed: $error');
    }
  }
}

/// Recovery strategy for model loading errors
class ModelLoadingRecoveryStrategy extends RecoveryStrategy {
  final ModelManager _modelManager;
  final int _maxRetries;

  ModelLoadingRecoveryStrategy({
    required ModelManager modelManager,
    int maxRetries = 2,
  })  : _modelManager = modelManager,
        _maxRetries = maxRetries;

  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    try {
      AppLogger.info('Attempting model loading recovery...');

      // Try to refresh models
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        final success = await _modelManager.refreshModels();

        if (success && _modelManager.hasModels) {
          AppLogger.info(
              'Model loading recovery successful on attempt $attempt');
          return RecoveryResult.success(
            'Models loaded successfully',
            {'modelCount': _modelManager.availableModels.length},
          );
        }

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      return RecoveryResult.failure(
          'Failed to load models after $_maxRetries attempts');
    } catch (error) {
      AppLogger.error('Model loading recovery failed', error);
      return RecoveryResult.failure('Model loading recovery failed: $error');
    }
  }
}

/// Recovery strategy for streaming errors
class StreamingRecoveryStrategy extends RecoveryStrategy {
  final Duration _cooldownPeriod;

  StreamingRecoveryStrategy({
    Duration cooldownPeriod = const Duration(seconds: 5),
  }) : _cooldownPeriod = cooldownPeriod;

  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    try {
      AppLogger.info('Attempting streaming recovery...');

      // Wait for cooldown period to allow server to recover
      await Future.delayed(_cooldownPeriod);

      // For streaming errors, recovery is mainly about clearing state
      // The actual retry will be handled by the calling service
      AppLogger.info('Streaming recovery cooldown completed');

      return RecoveryResult.success(
        'Streaming service ready for retry',
        {'cooldownPeriod': _cooldownPeriod.inSeconds},
      );
    } catch (error) {
      AppLogger.error('Streaming recovery failed', error);
      return RecoveryResult.failure('Streaming recovery failed: $error');
    }
  }
}

/// Recovery strategy for file processing errors
class FileProcessingRecoveryStrategy extends RecoveryStrategy {
  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    try {
      AppLogger.info('Attempting file processing recovery...');

      // For file processing errors, recovery mainly involves clearing state
      // Individual file processing will be retried by the service

      // Check if the error is related to file access or format
      final errorType = errorState.errorType;

      if (errorType == ErrorType.validation || errorType == ErrorType.format) {
        return RecoveryResult.failure(
            'File processing error requires user intervention');
      }

      // For other errors, allow retry
      AppLogger.info('File processing recovery completed');
      return RecoveryResult.success('File processing ready for retry');
    } catch (error) {
      AppLogger.error('File processing recovery failed', error);
      return RecoveryResult.failure('File processing recovery failed: $error');
    }
  }
}

/// Recovery strategy for state management errors
class StateRecoveryStrategy extends RecoveryStrategy {
  final void Function()? _resetStateCallback;

  StateRecoveryStrategy({
    void Function()? resetStateCallback,
  }) : _resetStateCallback = resetStateCallback;

  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    try {
      AppLogger.info('Attempting state recovery...');

      // Call reset callback if provided
      _resetStateCallback?.call();

      // Wait a moment for state to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      AppLogger.info('State recovery completed');
      return RecoveryResult.success('State reset successfully');
    } catch (error) {
      AppLogger.error('State recovery failed', error);
      return RecoveryResult.failure('State recovery failed: $error');
    }
  }
}

/// Recovery strategy for title generation errors
class TitleGenerationRecoveryStrategy extends RecoveryStrategy {
  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    try {
      AppLogger.info('Attempting title generation recovery...');

      // Title generation errors are usually not critical
      // Recovery involves clearing the generation state

      AppLogger.info('Title generation recovery completed');
      return RecoveryResult.success(
          'Title generation cleared, will use fallback');
    } catch (error) {
      AppLogger.error('Title generation recovery failed', error);
      return RecoveryResult.failure('Title generation recovery failed: $error');
    }
  }
}

/// Composite recovery strategy that tries multiple strategies
class CompositeRecoveryStrategy extends RecoveryStrategy {
  final List<RecoveryStrategy> _strategies;

  CompositeRecoveryStrategy(this._strategies);

  @override
  Future<RecoveryResult> recover(ErrorState errorState) async {
    final results = <RecoveryResult>[];

    for (int i = 0; i < _strategies.length; i++) {
      try {
        AppLogger.info(
            'Trying recovery strategy ${i + 1}/${_strategies.length}');

        final result = await _strategies[i].recover(errorState);
        results.add(result);

        if (result.success) {
          AppLogger.info('Recovery successful with strategy ${i + 1}');
          return result;
        }
      } catch (error) {
        AppLogger.error('Recovery strategy ${i + 1} failed', error);
        results.add(RecoveryResult.failure('Strategy ${i + 1} failed: $error'));
      }
    }

    // All strategies failed
    final messages =
        results.map((r) => r.message ?? 'Unknown error').join('; ');
    return RecoveryResult.failure('All recovery strategies failed: $messages');
  }
}

/// Factory for creating recovery strategies
class RecoveryStrategyFactory {
  /// Create recovery strategy for a specific service
  static RecoveryStrategy createForService(
    String serviceName, {
    OllamaService? ollamaService,
    ModelManager? modelManager,
    void Function()? resetStateCallback,
  }) {
    switch (serviceName.toLowerCase()) {
      case 'ollama':
      case 'connection':
        if (ollamaService != null) {
          return ConnectionRecoveryStrategy(ollamaService: ollamaService);
        }
        break;

      case 'model':
      case 'modelmanager':
        if (modelManager != null) {
          return CompositeRecoveryStrategy([
            if (ollamaService != null)
              ConnectionRecoveryStrategy(ollamaService: ollamaService),
            ModelLoadingRecoveryStrategy(modelManager: modelManager),
          ]);
        }
        break;

      case 'streaming':
      case 'messagestreaming':
        return CompositeRecoveryStrategy([
          if (ollamaService != null)
            ConnectionRecoveryStrategy(ollamaService: ollamaService),
          StreamingRecoveryStrategy(),
        ]);

      case 'fileprocessing':
        return FileProcessingRecoveryStrategy();

      case 'state':
      case 'chatstate':
        return StateRecoveryStrategy(resetStateCallback: resetStateCallback);

      case 'titlegeneration':
        return TitleGenerationRecoveryStrategy();

      default:
        // Generic recovery strategy
        return CompositeRecoveryStrategy([
          if (ollamaService != null)
            ConnectionRecoveryStrategy(ollamaService: ollamaService),
          StateRecoveryStrategy(resetStateCallback: resetStateCallback),
        ]);
    }

    // Fallback to basic state recovery
    return StateRecoveryStrategy(resetStateCallback: resetStateCallback);
  }
}
