import 'dart:async';
import '../services/ollama_service.dart';
import '../utils/logger.dart';
import 'cancellation_token.dart';

/// Centralized error handling utility for the application
/// Provides consistent error classification, recovery, and reporting
class ErrorHandler {
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(seconds: 10);

  /// Execute an operation with automatic retry and error handling
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
    int maxRetries = _maxRetryAttempts,
    Duration baseDelay = _baseRetryDelay,
    bool Function(Object error)? shouldRetry,
    void Function(Object error, int attempt)? onRetry,
    CancellationToken? cancellationToken,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= maxRetries) {
      try {
        // Check for cancellation before each attempt
        if (cancellationToken?.isCancelled == true) {
          throw CancellationException('Operation cancelled');
        }

        final result = await operation();

        // Log successful retry if this wasn't the first attempt
        if (attempt > 0) {
          AppLogger.info(
              '${operationName ?? 'Operation'} succeeded on attempt ${attempt + 1}');
        }

        return result;
      } catch (error) {
        lastError = error;
        attempt++;

        // Don't retry if we've exceeded max attempts
        if (attempt > maxRetries) break;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          AppLogger.warning(
              '${operationName ?? 'Operation'} failed with non-retryable error: $error');
          break;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateRetryDelay(attempt, baseDelay);

        AppLogger.warning(
            '${operationName ?? 'Operation'} failed on attempt $attempt: $error. '
            'Retrying in ${delay.inMilliseconds}ms...');

        // Notify retry callback
        onRetry?.call(error, attempt);

        // Wait before retry, checking for cancellation
        await _delayWithCancellation(delay, cancellationToken);
      }
    }

    // All retries exhausted, throw the last error
    AppLogger.error(
      '${operationName ?? 'Operation'} failed after $maxRetries retries',
      lastError,
    );

    throw lastError!;
  }

  /// Execute an operation with timeout and error handling
  static Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final result = await operation().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            '${operationName ?? 'Operation'} timed out after ${timeout.inSeconds}s',
            timeout,
          );
        },
      );

      return result;
    } catch (error) {
      AppLogger.error('${operationName ?? 'Operation'} failed', error);
      rethrow;
    }
  }

  /// Classify error type for appropriate handling
  static ErrorType classifyError(Object error) {
    if (error is CancellationException) {
      return ErrorType.cancellation;
    } else if (error is TimeoutException) {
      return ErrorType.timeout;
    } else if (error is OllamaConnectionException) {
      return ErrorType.connection;
    } else if (error is OllamaApiException) {
      return ErrorType.api;
    } else if (error is StateError) {
      return ErrorType.state;
    } else if (error is ArgumentError) {
      return ErrorType.validation;
    } else if (error is FormatException) {
      return ErrorType.format;
    } else {
      return ErrorType.unknown;
    }
  }

  /// Check if an error is retryable with enhanced logic
  static bool isRetryableError(Object error) {
    // Use enhanced exception logic if available
    if (error is OllamaApiException) {
      return error.isRetryable;
    }
    
    final errorType = classifyError(error);

    switch (errorType) {
      case ErrorType.connection:
      case ErrorType.timeout:
        return true;
      case ErrorType.api:
        return true; // Default to retryable for API errors
      case ErrorType.cancellation:
      case ErrorType.validation:
      case ErrorType.format:
      case ErrorType.state:
      case ErrorType.unknown:
        return false;
    }
  }

  /// Get user-friendly error message with enhanced context
  static String getUserFriendlyMessage(Object error) {
    final errorType = classifyError(error);

    switch (errorType) {
      case ErrorType.connection:
        if (error is OllamaConnectionException) {
          return error.userFriendlyMessage;
        }
        return 'Unable to connect to the server. Please check your connection settings.';
      case ErrorType.timeout:
        return 'The operation timed out. Please try again.';
      case ErrorType.api:
        if (error is OllamaApiException) {
          return error.userFriendlyMessage;
        }
        return 'An error occurred while communicating with the server.';
      case ErrorType.cancellation:
        return 'Operation was cancelled.';
      case ErrorType.validation:
        return 'Invalid input provided. Please check your data.';
      case ErrorType.format:
        return 'Data format error. Please try again.';
      case ErrorType.state:
        return 'Invalid operation state. Please refresh and try again.';
      case ErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get recovery suggestions for an error with enhanced context
  static List<String> getRecoverySuggestions(Object error) {
    final errorType = classifyError(error);

    switch (errorType) {
      case ErrorType.connection:
        if (error is OllamaConnectionException) {
          switch (error.errorCategory) {
            case 'connection_refused':
              return [
                'Start the Ollama service',
                'Check if Ollama is running on the correct port',
                'Verify firewall settings',
                'Try restarting Ollama',
              ];
            case 'dns_error':
              return [
                'Check the server URL spelling',
                'Verify the server address is correct',
                'Try using an IP address instead of hostname',
                'Check your DNS settings',
              ];
            case 'network_error':
              return [
                'Check your internet connection',
                'Try connecting to a different network',
                'Verify network permissions',
                'Check proxy settings if applicable',
              ];
            case 'timeout':
              return [
                'Check your network connection speed',
                'Try again when the server is less busy',
                'Increase timeout settings if available',
                'Use a faster network connection',
              ];
          }
        }
        return [
          'Check your internet connection',
          'Verify Ollama server is running',
          'Check server URL and port settings',
          'Try refreshing the connection',
        ];
      case ErrorType.timeout:
        return [
          'Try again with a shorter request',
          'Check your internet connection speed',
          'Increase timeout settings if available',
          'Break large requests into smaller parts',
        ];
      case ErrorType.api:
        if (error is OllamaApiException) {
          switch (error.errorCategory) {
            case 'client_error':
              return [
                'Check your input format',
                'Verify the selected model is correct',
                'Reduce the size of your request',
                'Check authentication if required',
              ];
            case 'server_error':
              return [
                'Try again in a few moments',
                'Check if the server is overloaded',
                'Verify server configuration',
                'Contact server administrator if problem persists',
              ];
          }
        }
        return [
          'Check if the selected model is available',
          'Verify server configuration',
          'Try with a different model',
          'Check server logs for details',
        ];
      case ErrorType.validation:
        return [
          'Check your input data',
          'Ensure all required fields are filled',
          'Verify file formats are supported',
          'Reduce file sizes if too large',
        ];
      case ErrorType.state:
        return [
          'Refresh the application',
          'Try creating a new chat',
          'Clear application cache',
          'Restart the application if needed',
        ];
      default:
        return [
          'Try the operation again',
          'Restart the application',
          'Check application logs for details',
          'Contact support if problem persists',
        ];
    }
  }

  /// Calculate retry delay with exponential backoff
  static Duration _calculateRetryDelay(int attempt, Duration baseDelay) {
    final exponentialDelay = baseDelay * (1 << (attempt - 1)); // 2^(attempt-1)
    return exponentialDelay > _maxRetryDelay
        ? _maxRetryDelay
        : exponentialDelay;
  }

  /// Delay with cancellation support
  static Future<void> _delayWithCancellation(
    Duration delay,
    CancellationToken? cancellationToken,
  ) async {
    if (cancellationToken == null) {
      await Future.delayed(delay);
      return;
    }

    final completer = Completer<void>();

    // Set up the delay
    Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Check for cancellation periodically
    const checkInterval = Duration(milliseconds: 100);
    Timer.periodic(checkInterval, (timer) {
      if (cancellationToken.isCancelled) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(CancellationException('Delay cancelled'));
        }
      } else if (completer.isCompleted) {
        timer.cancel();
      }
    });

    await completer.future;
  }

  /// Log error with enhanced context information and correlation ID
  static void logError(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? correlationId,
  }) {
    final errorType = classifyError(error);
    final timestamp = DateTime.now().toIso8601String();
    final corrId = correlationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Build enhanced context
    final enhancedContext = <String, dynamic>{
      'timestamp': timestamp,
      'correlationId': corrId,
      'errorType': errorType.name,
      'operation': operation,
    };
    
    // Add original context
    if (context != null) {
      enhancedContext.addAll(context);
    }
    
    // Add enhanced error details if available
    if (error is OllamaApiException) {
      enhancedContext.addAll(error.toLogMap());
    } else if (error is OllamaConnectionException) {
      enhancedContext.addAll(error.toLogMap());
    }

    AppLogger.error(
      '[$corrId] $operation failed with ${errorType.name} error: $error',
      error,
      stackTrace,
    );
    
    // Log detailed context at debug level to avoid cluttering main logs
    AppLogger.debug('[$corrId] Error context: $enhancedContext');
  }

  /// Create error state for UI components
  static ErrorState createErrorState(
    Object error, {
    String? operation,
    bool canRetry = true,
    Map<String, dynamic>? context,
  }) {
    return ErrorState(
      error: error,
      errorType: classifyError(error),
      message: getUserFriendlyMessage(error),
      suggestions: getRecoverySuggestions(error),
      operation: operation,
      canRetry: canRetry && isRetryableError(error),
      context: context,
      timestamp: DateTime.now(),
    );
  }
}

/// Enumeration of error types for classification
enum ErrorType {
  connection,
  timeout,
  api,
  cancellation,
  validation,
  format,
  state,
  unknown,
}

/// Error state container for UI components
class ErrorState {
  final Object error;
  final ErrorType errorType;
  final String message;
  final List<String> suggestions;
  final String? operation;
  final bool canRetry;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  const ErrorState({
    required this.error,
    required this.errorType,
    required this.message,
    required this.suggestions,
    this.operation,
    required this.canRetry,
    this.context,
    required this.timestamp,
  });

  /// Check if error is recent (within last 30 seconds)
  bool get isRecent {
    return DateTime.now().difference(timestamp).inSeconds < 30;
  }

  /// Get error severity level
  ErrorSeverity get severity {
    switch (errorType) {
      case ErrorType.cancellation:
        return ErrorSeverity.info;
      case ErrorType.validation:
      case ErrorType.format:
        return ErrorSeverity.warning;
      case ErrorType.connection:
      case ErrorType.timeout:
      case ErrorType.api:
        return ErrorSeverity.error;
      case ErrorType.state:
      case ErrorType.unknown:
        return ErrorSeverity.critical;
    }
  }

  @override
  String toString() {
    return 'ErrorState(type: ${errorType.name}, message: $message, '
        'canRetry: $canRetry, operation: $operation)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorState &&
        other.errorType == errorType &&
        other.message == message &&
        other.operation == operation;
  }

  @override
  int get hashCode {
    return Object.hash(errorType, message, operation);
  }
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}
