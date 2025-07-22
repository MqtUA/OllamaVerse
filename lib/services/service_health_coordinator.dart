import '../services/error_recovery_service.dart';
import '../services/model_manager.dart';
import '../services/chat_state_manager.dart';
import '../services/message_streaming_service.dart';
import '../services/file_processing_manager.dart';
import '../services/chat_title_generator.dart';
import '../utils/logger.dart';

/// Service responsible for coordinating service health monitoring and recovery
/// 
/// Provides centralized health monitoring, service state validation,
/// and coordinated recovery operations across all application services.
class ServiceHealthCoordinator {
  final ErrorRecoveryService _errorRecoveryService;
  final ModelManager _modelManager;
  final ChatStateManager _chatStateManager;
  final MessageStreamingService _messageStreamingService;
  final FileProcessingManager _fileProcessingManager;
  final ChatTitleGenerator _chatTitleGenerator;

  ServiceHealthCoordinator({
    required ErrorRecoveryService errorRecoveryService,
    required ModelManager modelManager,
    required ChatStateManager chatStateManager,
    required MessageStreamingService messageStreamingService,
    required FileProcessingManager fileProcessingManager,
    required ChatTitleGenerator chatTitleGenerator,
  })  : _errorRecoveryService = errorRecoveryService,
        _modelManager = modelManager,
        _chatStateManager = chatStateManager,
        _messageStreamingService = messageStreamingService,
        _fileProcessingManager = fileProcessingManager,
        _chatTitleGenerator = chatTitleGenerator;

  /// Get current error recovery status
  Map<String, dynamic> getErrorRecoveryStatus() {
    final serviceErrors = _errorRecoveryService.currentErrorStates;
    final systemHealth = _errorRecoveryService.getSystemHealth();

    return {
      'systemHealth': systemHealth.name,
      'serviceErrors': serviceErrors.map((key, value) => MapEntry(key, {
            'errorType': value.errorType.name,
            'message': value.message,
            'canRetry': value.canRetry,
            'severity': value.severity.name,
            'isRecent': value.isRecent,
            'operation': value.operation,
          })),
      'hasActiveErrors': serviceErrors.isNotEmpty,
      'errorCount': serviceErrors.length,
    };
  }

  /// Get service health status for all services
  Map<String, String> getServiceHealthStatus() {
    final services = [
      'ModelManager',
      'MessageStreamingService',
      'ChatStateManager',
      'FileProcessingManager',
      'ChatTitleGenerator',
    ];

    return Map.fromEntries(
      services.map((service) => MapEntry(
            service,
            _errorRecoveryService.getServiceHealth(service).name,
          )),
    );
  }

  /// Validate all service states
  bool validateAllServiceStates() {
    try {
      final modelManagerValid = _modelManager.validateState();
      final chatStateValid = _chatStateManager.validateState();
      final streamingValid = _messageStreamingService.validateStreamingState();

      final allValid = modelManagerValid && chatStateValid && streamingValid;

      if (!allValid) {
        AppLogger.warning('Service state validation failed: '
            'ModelManager=$modelManagerValid, '
            'ChatState=$chatStateValid, '
            'Streaming=$streamingValid');
      }

      return allValid;
    } catch (e) {
      AppLogger.error('Error validating service states', e);
      return false;
    }
  }

  /// Reset all service states to consistent state
  Future<void> resetAllServiceStates() async {
    try {
      AppLogger.info('Resetting all service states');

      // Cancel any ongoing operations
      _cancelAllOperations();

      // Reset individual service states
      _modelManager.resetState();
      _chatStateManager.resetState();
      _messageStreamingService.resetStreamingState();

      // Clear error recovery state
      _errorRecoveryService.clearAllErrors();

      AppLogger.info('All service states reset completed');
    } catch (e) {
      AppLogger.error('Error resetting service states', e);
      rethrow;
    }
  }

  /// Cancel all ongoing operations across services
  void _cancelAllOperations() {
    try {
      _messageStreamingService.cancelStreaming();
      _fileProcessingManager.clearProcessingState();
      _chatTitleGenerator.clearAllTitleGenerationState();
    } catch (e) {
      AppLogger.error('Error canceling operations', e);
    }
  }

  /// Manually trigger error recovery for a specific service
  Future<bool> recoverService(String serviceName) async {
    try {
      final errorState = _errorRecoveryService.getServiceError(serviceName);
      if (errorState == null) {
        AppLogger.info('No error state found for service: $serviceName');
        return true;
      }

      final result = await _errorRecoveryService.handleServiceError(
        serviceName,
        errorState.error,
        operation: 'manualRecovery',
      );

      return result != null;
    } catch (e) {
      AppLogger.error('Error during manual service recovery', e);
      return false;
    }
  }

  /// Clear all service errors
  void clearAllServiceErrors() {
    _errorRecoveryService.clearAllErrors();
  }

  /// Get detailed health report for all services
  Map<String, dynamic> getDetailedHealthReport() {
    try {
      final serviceHealth = getServiceHealthStatus();
      final errorRecoveryStatus = getErrorRecoveryStatus();
      final stateValidation = validateAllServiceStates();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'overallHealth': _calculateOverallHealth(serviceHealth, errorRecoveryStatus),
        'serviceHealth': serviceHealth,
        'errorRecovery': errorRecoveryStatus,
        'stateValidation': {
          'allStatesValid': stateValidation,
          'details': _getStateValidationDetails(),
        },
        'recommendations': _generateHealthRecommendations(serviceHealth, errorRecoveryStatus),
      };
    } catch (e) {
      AppLogger.error('Error generating health report', e);
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'overallHealth': 'unknown',
        'error': e.toString(),
      };
    }
  }

  /// Calculate overall system health
  String _calculateOverallHealth(Map<String, String> serviceHealth, Map<String, dynamic> errorStatus) {
    final hasErrors = errorStatus['hasActiveErrors'] as bool;
    final errorCount = errorStatus['errorCount'] as int;
    
    if (hasErrors && errorCount > 2) {
      return 'critical';
    } else if (hasErrors) {
      return 'degraded';
    }
    
    final healthyServices = serviceHealth.values.where((health) => health == 'healthy').length;
    final totalServices = serviceHealth.length;
    
    if (healthyServices == totalServices) {
      return 'healthy';
    } else if (healthyServices >= totalServices * 0.8) {
      return 'good';
    } else {
      return 'degraded';
    }
  }

  /// Get detailed state validation information
  Map<String, bool> _getStateValidationDetails() {
    try {
      return {
        'modelManager': _modelManager.validateState(),
        'chatState': _chatStateManager.validateState(),
        'messageStreaming': _messageStreamingService.validateStreamingState(),
      };
    } catch (e) {
      AppLogger.error('Error getting state validation details', e);
      return {
        'modelManager': false,
        'chatState': false,
        'messageStreaming': false,
      };
    }
  }

  /// Generate health recommendations based on current status
  List<String> _generateHealthRecommendations(
    Map<String, String> serviceHealth, 
    Map<String, dynamic> errorStatus
  ) {
    final recommendations = <String>[];
    
    final hasErrors = errorStatus['hasActiveErrors'] as bool;
    final errorCount = errorStatus['errorCount'] as int;
    
    if (hasErrors) {
      recommendations.add('Address $errorCount active service error${errorCount > 1 ? 's' : ''}');
    }
    
    final unhealthyServices = serviceHealth.entries
        .where((entry) => entry.value != 'healthy')
        .map((entry) => entry.key)
        .toList();
    
    if (unhealthyServices.isNotEmpty) {
      recommendations.add('Check health of services: ${unhealthyServices.join(', ')}');
    }
    
    if (!validateAllServiceStates()) {
      recommendations.add('Consider resetting service states to resolve inconsistencies');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('All services are operating normally');
    }
    
    return recommendations;
  }
}