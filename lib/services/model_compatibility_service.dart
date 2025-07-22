import '../services/model_manager.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';

/// Service responsible for model compatibility validation and recommendations
/// 
/// Handles model-specific settings validation, performance recommendations,
/// and compatibility checks between models and application settings.
class ModelCompatibilityService {
  final SettingsProvider _settingsProvider;

  ModelCompatibilityService({
    required ModelManager modelManager,
    required SettingsProvider settingsProvider,
  })  : _settingsProvider = settingsProvider;

  /// Validate settings for a specific model and provide recommendations
  Future<Map<String, dynamic>> validateSettingsForModel(String modelName) async {
    if (modelName.isEmpty) {
      return {
        'isValid': true,
        'recommendations': ['No model selected for validation'],
        'modelName': 'unknown',
      };
    }

    try {
      // Wait for settings to be ready
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final recommendations = ollamaService.getPerformanceRecommendations(modelName);
      final isValid = ollamaService.validateSettingsForModel(modelName);
      final recommendedContext = ollamaService.getRecommendedContextLength(modelName);

      return {
        'isValid': isValid,
        'modelName': modelName,
        'recommendedContextLength': recommendedContext,
        'currentContextLength': _settingsProvider.settings.contextLength,
        'recommendations': recommendations,
      };
    } catch (e) {
      AppLogger.error('Error validating settings for model', e);
      return {
        'isValid': false,
        'error': e.toString(),
        'modelName': modelName,
        'recommendations': ['Unable to validate settings due to an error'],
      };
    }
  }

  /// Get performance recommendations for the current model
  List<String> getPerformanceRecommendations(String modelName) {
    try {
      if (_settingsProvider.isLoading) {
        return ['Settings still loading, unable to provide recommendations'];
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final recommendationsMap = ollamaService.getPerformanceRecommendations(modelName);
      
      // Extract suggestions from the map
      final suggestions = recommendationsMap['suggestions'] as List<String>? ?? [];
      final warnings = recommendationsMap['warnings'] as List<String>? ?? [];
      
      // Combine suggestions and warnings
      return [...suggestions, ...warnings];
    } catch (e) {
      AppLogger.error('Error getting performance recommendations', e);
      return ['Unable to get recommendations due to an error'];
    }
  }

  /// Check if a model supports specific features
  Future<Map<String, bool>> getModelFeatureSupport(String modelName) async {
    try {
      if (_settingsProvider.isLoading) {
        return {
          'systemPrompt': true,
          'streaming': true,
          'contextWindow': true,
        };
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final systemPromptSupport = await ollamaService.validateSystemPromptSupport(modelName);
      
      return {
        'systemPrompt': systemPromptSupport['supported'] as bool,
        'streaming': true, // Most models support streaming
        'contextWindow': true, // All models have some context window
      };
    } catch (e) {
      AppLogger.error('Error checking model feature support', e);
      return {
        'systemPrompt': true,
        'streaming': true,
        'contextWindow': true,
      };
    }
  }

  /// Get recommended context length for a model
  int getRecommendedContextLength(String modelName) {
    try {
      if (_settingsProvider.isLoading) {
        return 4096; // Default fallback
      }

      final ollamaService = _settingsProvider.getOllamaService();
      return ollamaService.getRecommendedContextLength(modelName);
    } catch (e) {
      AppLogger.error('Error getting recommended context length', e);
      return 4096; // Default fallback
    }
  }

  /// Validate if current settings are compatible with the model
  bool areSettingsCompatibleWithModel(String modelName) {
    try {
      if (_settingsProvider.isLoading) {
        return true; // Assume compatible if still loading
      }

      final ollamaService = _settingsProvider.getOllamaService();
      return ollamaService.validateSettingsForModel(modelName);
    } catch (e) {
      AppLogger.error('Error validating settings compatibility', e);
      return true; // Default to compatible
    }
  }

  /// Get model-specific optimization suggestions
  Map<String, dynamic> getModelOptimizationSuggestions(String modelName) {
    try {
      final recommendations = getPerformanceRecommendations(modelName);
      final recommendedContext = getRecommendedContextLength(modelName);
      final currentContext = _settingsProvider.settings.contextLength;

      return {
        'modelName': modelName,
        'recommendations': recommendations,
        'contextOptimization': {
          'current': currentContext,
          'recommended': recommendedContext,
          'shouldAdjust': currentContext != recommendedContext,
        },
        'performanceImpact': _assessPerformanceImpact(modelName),
      };
    } catch (e) {
      AppLogger.error('Error getting optimization suggestions', e);
      return {
        'modelName': modelName,
        'recommendations': ['Unable to get optimization suggestions'],
        'error': e.toString(),
      };
    }
  }

  /// Assess performance impact of current settings on the model
  String _assessPerformanceImpact(String modelName) {
    try {
      final currentContext = _settingsProvider.settings.contextLength;
      final recommendedContext = getRecommendedContextLength(modelName);

      if (currentContext > recommendedContext * 1.5) {
        return 'high'; // Context is significantly higher than recommended
      } else if (currentContext > recommendedContext) {
        return 'medium'; // Context is moderately higher
      } else {
        return 'low'; // Context is within recommended range
      }
    } catch (e) {
      AppLogger.error('Error assessing performance impact', e);
      return 'unknown';
    }
  }
}