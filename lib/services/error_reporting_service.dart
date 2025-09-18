import 'dart:async';
import 'dart:convert';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../services/ollama_service.dart';

/// Comprehensive error reporting and analytics service
/// 
/// This service provides centralized error tracking, analysis, and reporting
/// capabilities to help diagnose and fix API integration issues quickly.
class ErrorReportingService {
  static final ErrorReportingService _instance = ErrorReportingService._internal();
  factory ErrorReportingService() => _instance;
  ErrorReportingService._internal();

  final List<ErrorReport> _errorHistory = [];
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final StreamController<ErrorReport> _errorStreamController = StreamController<ErrorReport>.broadcast();

  static const int _maxErrorHistory = 100;
  static const Duration _errorCooldown = Duration(minutes: 1);

  /// Stream of error reports for real-time monitoring
  Stream<ErrorReport> get errorStream => _errorStreamController.stream;

  /// Get current error statistics
  ErrorStatistics get statistics => ErrorStatistics(
    totalErrors: _errorHistory.length,
    uniqueErrors: _errorCounts.length,
    recentErrors: _getRecentErrors(const Duration(hours: 1)).length,
    criticalErrors: _errorHistory.where((e) => e.severity == ErrorSeverity.critical).length,
    errorsByType: Map.from(_errorCounts),
    lastErrorTime: _errorHistory.isNotEmpty ? _errorHistory.last.timestamp : null,
  );

  /// Report an error with enhanced context and analysis
  void reportError(
    Object error, {
    StackTrace? stackTrace,
    String? operation,
    Map<String, dynamic>? context,
    String? correlationId,
    ErrorSeverity? severity,
  }) {
    final errorReport = ErrorReport(
      error: error,
      stackTrace: stackTrace,
      operation: operation ?? 'Unknown operation',
      context: context ?? {},
      correlationId: correlationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      errorType: ErrorHandler.classifyError(error),
      severity: severity ?? _determineSeverity(error),
      userFriendlyMessage: ErrorHandler.getUserFriendlyMessage(error),
      recoverySuggestions: ErrorHandler.getRecoverySuggestions(error),
      isRetryable: ErrorHandler.isRetryableError(error),
    );

    _addErrorReport(errorReport);
    _updateErrorCounts(errorReport);
    _logErrorReport(errorReport);
    
    // Emit to stream for real-time monitoring
    _errorStreamController.add(errorReport);
  }

  /// Get error reports filtered by criteria
  List<ErrorReport> getErrors({
    Duration? since,
    ErrorType? errorType,
    ErrorSeverity? severity,
    String? operation,
    int? limit,
  }) {
    var filtered = _errorHistory.where((report) {
      if (since != null && report.timestamp.isBefore(DateTime.now().subtract(since))) {
        return false;
      }
      if (errorType != null && report.errorType != errorType) {
        return false;
      }
      if (severity != null && report.severity != severity) {
        return false;
      }
      if (operation != null && !report.operation.toLowerCase().contains(operation.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    // Sort by timestamp (most recent first)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  /// Get error patterns and trends
  ErrorAnalysis analyzeErrors({Duration? timeWindow}) {
    final window = timeWindow ?? const Duration(hours: 24);
    final recentErrors = _getRecentErrors(window);
    
    if (recentErrors.isEmpty) {
      return ErrorAnalysis.empty();
    }

    // Analyze error patterns
    final errorsByType = <ErrorType, int>{};
    final errorsByOperation = <String, int>{};
    final errorsBySeverity = <ErrorSeverity, int>{};
    final hourlyDistribution = <int, int>{};
    
    for (final error in recentErrors) {
      errorsByType[error.errorType] = (errorsByType[error.errorType] ?? 0) + 1;
      errorsByOperation[error.operation] = (errorsByOperation[error.operation] ?? 0) + 1;
      errorsBySeverity[error.severity] = (errorsBySeverity[error.severity] ?? 0) + 1;
      
      final hour = error.timestamp.hour;
      hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
    }

    // Find most common errors
    final sortedByType = errorsByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedByOperation = errorsByOperation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate error rate
    final totalMinutes = window.inMinutes;
    final errorRate = totalMinutes > 0 ? recentErrors.length / totalMinutes : 0.0;

    return ErrorAnalysis(
      timeWindow: window,
      totalErrors: recentErrors.length,
      errorRate: errorRate,
      mostCommonErrorType: sortedByType.isNotEmpty ? sortedByType.first.key : null,
      mostProblematicOperation: sortedByOperation.isNotEmpty ? sortedByOperation.first.key : null,
      errorsByType: errorsByType,
      errorsByOperation: errorsByOperation,
      errorsBySeverity: errorsBySeverity,
      hourlyDistribution: hourlyDistribution,
      criticalErrorCount: errorsBySeverity[ErrorSeverity.critical] ?? 0,
      recommendations: _generateRecommendations(recentErrors),
    );
  }

  /// Check if an error should be throttled (to prevent spam)
  bool shouldThrottleError(Object error) {
    final errorKey = _getErrorKey(error);
    final lastTime = _lastErrorTimes[errorKey];
    
    if (lastTime == null) {
      _lastErrorTimes[errorKey] = DateTime.now();
      return false;
    }
    
    final timeSinceLastError = DateTime.now().difference(lastTime);
    if (timeSinceLastError < _errorCooldown) {
      return true;
    }
    
    _lastErrorTimes[errorKey] = DateTime.now();
    return false;
  }

  /// Clear error history
  void clearHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
    AppLogger.info('Error reporting history cleared');
  }

  /// Export error reports for analysis
  Map<String, dynamic> exportErrorReports({Duration? timeWindow}) {
    final errors = timeWindow != null 
        ? _getRecentErrors(timeWindow)
        : _errorHistory;

    return {
      'exportTimestamp': DateTime.now().toIso8601String(),
      'timeWindow': timeWindow?.inHours,
      'totalErrors': errors.length,
      'statistics': statistics.toMap(),
      'analysis': analyzeErrors(timeWindow: timeWindow).toMap(),
      'errors': errors.map((e) => e.toMap()).toList(),
    };
  }

  /// Dispose resources
  void dispose() {
    _errorStreamController.close();
  }

  // Private methods

  void _addErrorReport(ErrorReport report) {
    _errorHistory.add(report);
    
    // Maintain history size limit
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  void _updateErrorCounts(ErrorReport report) {
    final errorKey = _getErrorKey(report.error);
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
  }

  void _logErrorReport(ErrorReport report) {
    final logLevel = _getLogLevelForSeverity(report.severity);
    final message = '[${report.correlationId}] ${report.operation}: ${report.userFriendlyMessage}';
    
    switch (logLevel) {
      case 'error':
        AppLogger.error(message, report.error, report.stackTrace);
        break;
      case 'warning':
        AppLogger.warning(message);
        break;
      case 'info':
        AppLogger.info(message);
        break;
    }

    // Log detailed context at debug level
    AppLogger.debug('[${report.correlationId}] Error context: ${jsonEncode(report.context)}');
  }

  String _getErrorKey(Object error) {
    if (error is OllamaApiException) {
      return 'OllamaApiException_${error.statusCode}_${error.errorCategory}';
    } else if (error is OllamaConnectionException) {
      return 'OllamaConnectionException_${error.errorCategory}';
    }
    return error.runtimeType.toString();
  }

  ErrorSeverity _determineSeverity(Object error) {
    if (error is OllamaApiException) {
      if (error.statusCode != null) {
        if (error.statusCode! >= 500) return ErrorSeverity.critical;
        if (error.statusCode! >= 400) return ErrorSeverity.error;
      }
      return ErrorSeverity.error;
    } else if (error is OllamaConnectionException) {
      return ErrorSeverity.error;
    } else if (error is TimeoutException) {
      return ErrorSeverity.warning;
    } else if (error is StateError) {
      return ErrorSeverity.critical;
    }
    return ErrorSeverity.error;
  }

  String _getLogLevelForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return 'error';
      case ErrorSeverity.error:
        return 'error';
      case ErrorSeverity.warning:
        return 'warning';
      case ErrorSeverity.info:
        return 'info';
    }
  }

  List<ErrorReport> _getRecentErrors(Duration timeWindow) {
    final cutoff = DateTime.now().subtract(timeWindow);
    return _errorHistory.where((error) => error.timestamp.isAfter(cutoff)).toList();
  }

  List<String> _generateRecommendations(List<ErrorReport> errors) {
    final recommendations = <String>[];
    
    if (errors.isEmpty) return recommendations;

    // Analyze error patterns and generate recommendations
    final connectionErrors = errors.where((e) => e.errorType == ErrorType.connection).length;
    final apiErrors = errors.where((e) => e.errorType == ErrorType.api).length;
    final timeoutErrors = errors.where((e) => e.errorType == ErrorType.timeout).length;

    if (connectionErrors > errors.length * 0.5) {
      recommendations.add('High number of connection errors detected. Check Ollama server status and network connectivity.');
    }

    if (apiErrors > errors.length * 0.3) {
      recommendations.add('Frequent API errors suggest server-side issues. Consider checking server logs and configuration.');
    }

    if (timeoutErrors > errors.length * 0.2) {
      recommendations.add('Multiple timeout errors indicate slow responses. Consider increasing timeout settings or optimizing requests.');
    }

    // Check for error spikes
    final recentHour = errors.where((e) => 
        e.timestamp.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).length;
    if (recentHour > 10) {
      recommendations.add('Error spike detected in the last hour. Monitor system resources and server health.');
    }

    return recommendations;
  }
}

/// Detailed error report with enhanced context
class ErrorReport {
  final Object error;
  final StackTrace? stackTrace;
  final String operation;
  final Map<String, dynamic> context;
  final String correlationId;
  final DateTime timestamp;
  final ErrorType errorType;
  final ErrorSeverity severity;
  final String userFriendlyMessage;
  final List<String> recoverySuggestions;
  final bool isRetryable;

  const ErrorReport({
    required this.error,
    this.stackTrace,
    required this.operation,
    required this.context,
    required this.correlationId,
    required this.timestamp,
    required this.errorType,
    required this.severity,
    required this.userFriendlyMessage,
    required this.recoverySuggestions,
    required this.isRetryable,
  });

  Map<String, dynamic> toMap() {
    return {
      'error': error.toString(),
      'operation': operation,
      'context': context,
      'correlationId': correlationId,
      'timestamp': timestamp.toIso8601String(),
      'errorType': errorType.name,
      'severity': severity.name,
      'userFriendlyMessage': userFriendlyMessage,
      'recoverySuggestions': recoverySuggestions,
      'isRetryable': isRetryable,
      'stackTrace': stackTrace?.toString(),
    };
  }
}

/// Error statistics summary
class ErrorStatistics {
  final int totalErrors;
  final int uniqueErrors;
  final int recentErrors;
  final int criticalErrors;
  final Map<String, int> errorsByType;
  final DateTime? lastErrorTime;

  const ErrorStatistics({
    required this.totalErrors,
    required this.uniqueErrors,
    required this.recentErrors,
    required this.criticalErrors,
    required this.errorsByType,
    this.lastErrorTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalErrors': totalErrors,
      'uniqueErrors': uniqueErrors,
      'recentErrors': recentErrors,
      'criticalErrors': criticalErrors,
      'errorsByType': errorsByType,
      'lastErrorTime': lastErrorTime?.toIso8601String(),
    };
  }
}

/// Error analysis and trends
class ErrorAnalysis {
  final Duration timeWindow;
  final int totalErrors;
  final double errorRate;
  final ErrorType? mostCommonErrorType;
  final String? mostProblematicOperation;
  final Map<ErrorType, int> errorsByType;
  final Map<String, int> errorsByOperation;
  final Map<ErrorSeverity, int> errorsBySeverity;
  final Map<int, int> hourlyDistribution;
  final int criticalErrorCount;
  final List<String> recommendations;

  const ErrorAnalysis({
    required this.timeWindow,
    required this.totalErrors,
    required this.errorRate,
    this.mostCommonErrorType,
    this.mostProblematicOperation,
    required this.errorsByType,
    required this.errorsByOperation,
    required this.errorsBySeverity,
    required this.hourlyDistribution,
    required this.criticalErrorCount,
    required this.recommendations,
  });

  factory ErrorAnalysis.empty() {
    return const ErrorAnalysis(
      timeWindow: Duration.zero,
      totalErrors: 0,
      errorRate: 0.0,
      errorsByType: {},
      errorsByOperation: {},
      errorsBySeverity: {},
      hourlyDistribution: {},
      criticalErrorCount: 0,
      recommendations: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timeWindowHours': timeWindow.inHours,
      'totalErrors': totalErrors,
      'errorRate': errorRate,
      'mostCommonErrorType': mostCommonErrorType?.name,
      'mostProblematicOperation': mostProblematicOperation,
      'errorsByType': errorsByType.map((k, v) => MapEntry(k.name, v)),
      'errorsByOperation': errorsByOperation,
      'errorsBySeverity': errorsBySeverity.map((k, v) => MapEntry(k.name, v)),
      'hourlyDistribution': hourlyDistribution,
      'criticalErrorCount': criticalErrorCount,
      'recommendations': recommendations,
    };
  }
}