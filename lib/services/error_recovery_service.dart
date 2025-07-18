import 'dart:async';
import '../utils/error_handler.dart';
import '../utils/logger.dart';
import '../utils/cancellation_token.dart';

/// Service responsible for coordinating error recovery across the application
/// Provides centralized error handling, recovery strategies, and state management
class ErrorRecoveryService {
  // Error state tracking
  final Map<String, ErrorState> _serviceErrors = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  
  // Recovery strategies
  final Map<String, RecoveryStrategy> _recoveryStrategies = {};
  
  // Stream controller for error state changes
  final _errorStateController = StreamController<Map<String, ErrorState>>.broadcast();
  
  // Configuration
  static const int _maxErrorsPerService = 5;
  static const Duration _errorResetWindow = Duration(minutes: 5);
  static const Duration _circuitBreakerTimeout = Duration(minutes: 1);
  
  /// Stream of error state changes across all services
  Stream<Map<String, ErrorState>> get errorStateStream => _errorStateController.stream;
  
  /// Get current error states for all services
  Map<String, ErrorState> get currentErrorStates => Map.unmodifiable(_serviceErrors);
  
  /// Check if a service has active errors
  bool hasServiceError(String serviceName) => _serviceErrors.containsKey(serviceName);
  
  /// Get error state for a specific service
  ErrorState? getServiceError(String serviceName) => _serviceErrors[serviceName];
  
  /// Check if a service is in circuit breaker state
  bool isServiceCircuitBreakerOpen(String serviceName) {
    final errorCount = _errorCounts[serviceName] ?? 0;
    final lastErrorTime = _lastErrorTimes[serviceName];
    
    if (errorCount >= _maxErrorsPerService && lastErrorTime != null) {
      final timeSinceLastError = DateTime.now().difference(lastErrorTime);
      return timeSinceLastError < _circuitBreakerTimeout;
    }
    
    return false;
  }

  /// Register a recovery strategy for a service
  void registerRecoveryStrategy(String serviceName, RecoveryStrategy strategy) {
    _recoveryStrategies[serviceName] = strategy;
    AppLogger.info('Registered recovery strategy for service: $serviceName');
  }

  /// Handle an error from a service with automatic recovery
  Future<T?> handleServiceError<T>(
    String serviceName,
    Object error, {
    String? operation,
    Future<T> Function()? recoveryAction,
    Map<String, dynamic>? context,
  }) async {
    try {
      // Update error tracking
      _updateErrorTracking(serviceName, error);
      
      // Create error state
      final errorState = ErrorHandler.createErrorState(
        error,
        operation: operation,
        context: context,
      );
      
      // Store error state
      _serviceErrors[serviceName] = errorState;
      _notifyErrorStateChange();
      
      // Log the error
      ErrorHandler.logError(
        '${serviceName}${operation != null ? '.$operation' : ''}',
        error,
        context: context,
      );
      
      // Check circuit breaker
      if (isServiceCircuitBreakerOpen(serviceName)) {
        AppLogger.warning('Circuit breaker open for service: $serviceName');
        return null;
      }
      
      // Attempt recovery if strategy is available
      final strategy = _recoveryStrategies[serviceName];
      if (strategy != null) {
        return await _attemptRecovery<T>(
          serviceName,
          errorState,
          strategy,
          recoveryAction,
        );
      }
      
      // No recovery strategy, return null
      return null;
    } catch (recoveryError) {
      AppLogger.error('Error during recovery for service: $serviceName', recoveryError);
      return null;
    }
  }

  /// Execute an operation with service-level error handling
  Future<T> executeServiceOperation<T>(
    String serviceName,
    Future<T> Function() operation, {
    String? operationName,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 30),
    CancellationToken? cancellationToken,
  }) async {
    // Check circuit breaker
    if (isServiceCircuitBreakerOpen(serviceName)) {
      throw ServiceUnavailableException(
        'Service $serviceName is temporarily unavailable due to repeated errors'
      );
    }

    try {
      // Clear any previous error for this service
      clearServiceError(serviceName);
      
      // Execute with retry and timeout
      final result = await ErrorHandler.executeWithTimeout(
        () => ErrorHandler.executeWithRetry(
          operation,
          operationName: '${serviceName}${operationName != null ? '.$operationName' : ''}',
          maxRetries: maxRetries,
          shouldRetry: ErrorHandler.isRetryableError,
          cancellationToken: cancellationToken,
        ),
        timeout: timeout,
        operationName: '${serviceName}${operationName != null ? '.$operationName' : ''}',
        cancellationToken: cancellationToken,
      );
      
      // Reset error count on success
      _resetErrorCount(serviceName);
      
      return result;
    } catch (error) {
      // Handle the error and attempt recovery
      final recoveredResult = await handleServiceError<T>(
        serviceName,
        error,
        operation: operationName,
      );
      
      if (recoveredResult != null) {
        return recoveredResult;
      }
      
      // Recovery failed, rethrow original error
      rethrow;
    }
  }

  /// Clear error state for a specific service
  void clearServiceError(String serviceName) {
    if (_serviceErrors.remove(serviceName) != null) {
      _notifyErrorStateChange();
      AppLogger.info('Cleared error state for service: $serviceName');
    }
  }

  /// Clear all error states
  void clearAllErrors() {
    if (_serviceErrors.isNotEmpty) {
      _serviceErrors.clear();
      _notifyErrorStateChange();
      AppLogger.info('Cleared all service error states');
    }
  }

  /// Reset error count for a service (called on successful operations)
  void _resetErrorCount(String serviceName) {
    if (_errorCounts.remove(serviceName) != null) {
      _lastErrorTimes.remove(serviceName);
      AppLogger.info('Reset error count for service: $serviceName');
    }
  }

  /// Update error tracking for a service
  void _updateErrorTracking(String serviceName, Object error) {
    final now = DateTime.now();
    final lastErrorTime = _lastErrorTimes[serviceName];
    
    // Reset count if enough time has passed
    if (lastErrorTime != null && now.difference(lastErrorTime) > _errorResetWindow) {
      _errorCounts[serviceName] = 0;
    }
    
    // Increment error count
    _errorCounts[serviceName] = (_errorCounts[serviceName] ?? 0) + 1;
    _lastErrorTimes[serviceName] = now;
    
    AppLogger.warning(
      'Error count for $serviceName: ${_errorCounts[serviceName]}/$_maxErrorsPerService'
    );
  }

  /// Attempt recovery using registered strategy
  Future<T?> _attemptRecovery<T>(
    String serviceName,
    ErrorState errorState,
    RecoveryStrategy strategy,
    Future<T> Function()? recoveryAction,
  ) async {
    try {
      AppLogger.info('Attempting recovery for service: $serviceName');
      
      // Execute recovery strategy
      final recoveryResult = await strategy.recover(errorState);
      
      if (recoveryResult.success) {
        AppLogger.info('Recovery successful for service: $serviceName');
        
        // Clear error state on successful recovery
        clearServiceError(serviceName);
        
        // Execute recovery action if provided
        if (recoveryAction != null) {
          return await recoveryAction();
        }
      } else {
        AppLogger.warning(
          'Recovery failed for service: $serviceName - ${recoveryResult.message}'
        );
      }
      
      return null;
    } catch (error) {
      AppLogger.error('Recovery attempt failed for service: $serviceName', error);
      return null;
    }
  }

  /// Notify listeners of error state changes
  void _notifyErrorStateChange() {
    if (!_errorStateController.isClosed) {
      _errorStateController.add(Map.from(_serviceErrors));
    }
  }

  /// Get service health status
  ServiceHealthStatus getServiceHealth(String serviceName) {
    final errorCount = _errorCounts[serviceName] ?? 0;
    final hasActiveError = hasServiceError(serviceName);
    final isCircuitBreakerOpen = isServiceCircuitBreakerOpen(serviceName);
    
    if (isCircuitBreakerOpen) {
      return ServiceHealthStatus.unavailable;
    } else if (hasActiveError) {
      return ServiceHealthStatus.degraded;
    } else if (errorCount > 0) {
      return ServiceHealthStatus.recovering;
    } else {
      return ServiceHealthStatus.healthy;
    }
  }

  /// Get overall system health
  SystemHealthStatus getSystemHealth() {
    final services = {..._errorCounts.keys, ..._serviceErrors.keys};
    
    if (services.isEmpty) {
      return SystemHealthStatus.healthy;
    }
    
    int healthyCount = 0;
    int degradedCount = 0;
    int unavailableCount = 0;
    
    for (final service in services) {
      final health = getServiceHealth(service);
      switch (health) {
        case ServiceHealthStatus.healthy:
        case ServiceHealthStatus.recovering:
          healthyCount++;
          break;
        case ServiceHealthStatus.degraded:
          degradedCount++;
          break;
        case ServiceHealthStatus.unavailable:
          unavailableCount++;
          break;
      }
    }
    
    if (unavailableCount > 0) {
      return SystemHealthStatus.critical;
    } else if (degradedCount > services.length / 2) {
      return SystemHealthStatus.degraded;
    } else if (degradedCount > 0) {
      return SystemHealthStatus.warning;
    } else {
      return SystemHealthStatus.healthy;
    }
  }

  /// Dispose resources
  void dispose() {
    _errorStateController.close();
    _serviceErrors.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _recoveryStrategies.clear();
    AppLogger.info('ErrorRecoveryService disposed');
  }
}

/// Abstract base class for recovery strategies
abstract class RecoveryStrategy {
  /// Attempt to recover from an error
  Future<RecoveryResult> recover(ErrorState errorState);
}

/// Result of a recovery attempt
class RecoveryResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const RecoveryResult({
    required this.success,
    this.message,
    this.data,
  });

  factory RecoveryResult.success([String? message, Map<String, dynamic>? data]) {
    return RecoveryResult(success: true, message: message, data: data);
  }

  factory RecoveryResult.failure(String message, [Map<String, dynamic>? data]) {
    return RecoveryResult(success: false, message: message, data: data);
  }
}

/// Exception thrown when a service is unavailable
class ServiceUnavailableException implements Exception {
  final String message;

  ServiceUnavailableException(this.message);

  @override
  String toString() => 'ServiceUnavailableException: $message';
}

/// Service health status enumeration
enum ServiceHealthStatus {
  healthy,
  recovering,
  degraded,
  unavailable,
}

/// System health status enumeration
enum SystemHealthStatus {
  healthy,
  warning,
  degraded,
  critical,
}