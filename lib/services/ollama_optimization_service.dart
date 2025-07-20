import '../models/app_settings.dart';
import '../utils/logger.dart';

/// Service for optimizing Ollama API requests based on model capabilities and user settings
class OllamaOptimizationService {
  static const Map<String, Map<String, dynamic>> _modelOptimizations = {
    // Llama models
    'llama': {
      'temperature': 0.7,
      'top_p': 0.9,
      'repeat_penalty': 1.1,
      'num_thread': 4,
    },
    'llama2': {
      'temperature': 0.7,
      'top_p': 0.9,
      'repeat_penalty': 1.1,
      'num_thread': 4,
    },
    'llama3': {
      'temperature': 0.8,
      'top_p': 0.95,
      'repeat_penalty': 1.05,
      'num_thread': 6,
    },
    // Code models
    'codellama': {
      'temperature': 0.3,
      'top_p': 0.8,
      'repeat_penalty': 1.2,
      'num_thread': 4,
    },
    'codegemma': {
      'temperature': 0.2,
      'top_p': 0.7,
      'repeat_penalty': 1.3,
      'num_thread': 4,
    },
    // Vision models
    'llava': {
      'temperature': 0.6,
      'top_p': 0.9,
      'repeat_penalty': 1.1,
      'num_thread': 6,
    },
    'bakllava': {
      'temperature': 0.6,
      'top_p': 0.9,
      'repeat_penalty': 1.1,
      'num_thread': 6,
    },
    // Thinking models
    'qwen2.5': {
      'temperature': 0.7,
      'top_p': 0.9,
      'repeat_penalty': 1.0,
      'num_thread': 4,
    },
  };

  /// Get optimized options for a specific model and operation
  static Map<String, dynamic> getOptimizedOptions({
    required String modelName,
    required AppSettings settings,
    bool isStreaming = false,
    String operationType = 'generate',
    int? contextLength,
  }) {
    try {
      final options = <String, dynamic>{};

      // Context length from settings (highest priority)
      final effectiveContextLength = contextLength ?? settings.contextLength;
      if (effectiveContextLength > 0) {
        options['num_ctx'] = effectiveContextLength;
      }

      // Get model-specific optimizations
      final modelKey = _getModelKey(modelName);
      final modelOpts =
          _modelOptimizations[modelKey] ?? _modelOptimizations['llama']!;

      // Apply model-specific settings
      options.addAll(Map<String, dynamic>.from(modelOpts));

      // Operation-specific adjustments
      switch (operationType) {
        case 'chat':
          options['temperature'] = (options['temperature'] as double) * 1.1;
          break;
        case 'title':
          options['temperature'] = 0.3;
          options['num_predict'] = 50;
          options['top_p'] = 0.7;
          break;
        case 'system':
          options['temperature'] = 0.5;
          options['top_p'] = 0.8;
          break;
      }

      // Streaming-specific optimizations
      if (isStreaming) {
        options['num_predict'] = -1; // No prediction limit
        // Reduce thread count slightly for streaming to prevent blocking
        options['num_thread'] =
            ((options['num_thread'] as int) * 0.75).round().clamp(2, 8);
      }

      // Performance optimizations based on context length
      if (effectiveContextLength > 8192) {
        // Large context optimizations
        options['num_thread'] = (options['num_thread'] as int).clamp(2, 6);
        options['num_batch'] = 512;
      } else if (effectiveContextLength > 4096) {
        // Medium context optimizations
        options['num_batch'] = 256;
      }

      AppLogger.debug(
          'Optimized options for $modelName ($operationType): $options');
      return options;
    } catch (e) {
      AppLogger.error('Error generating optimized options', e);
      // Return basic safe options
      return {
        'num_ctx': contextLength ?? settings.contextLength,
        'temperature': 0.7,
        'top_p': 0.9,
        'repeat_penalty': 1.1,
        'num_thread': 4,
      };
    }
  }

  /// Get the optimization key for a model name
  static String _getModelKey(String modelName) {
    final lowerName = modelName.toLowerCase();

    // Check for exact matches first
    for (final key in _modelOptimizations.keys) {
      if (lowerName.contains(key)) {
        return key;
      }
    }

    // Special cases
    if (lowerName.contains('code')) {
      return 'codellava';
    }
    if (lowerName.contains('vision') || lowerName.contains('visual')) {
      return 'llava';
    }
    if (lowerName.contains('qwen')) {
      return 'qwen2.5';
    }

    // Default to llama optimizations
    return 'llama';
  }

  /// Check if a model supports advanced optimizations
  static bool supportsAdvancedOptimizations(String modelName) {
    final modelKey = _getModelKey(modelName);
    return _modelOptimizations.containsKey(modelKey);
  }

  /// Get recommended context length for a model
  static int getRecommendedContextLength(String modelName) {
    final lowerName = modelName.toLowerCase();

    if (lowerName.contains('llama3') || lowerName.contains('qwen2.5')) {
      return 8192; // Newer models support larger contexts
    } else if (lowerName.contains('code')) {
      return 16384; // Code models benefit from larger contexts
    } else if (lowerName.contains('vision') || lowerName.contains('llava')) {
      return 4096; // Vision models need moderate context for images
    }

    return 4096; // Safe default
  }

  /// Get performance recommendations for current settings
  static Map<String, dynamic> getPerformanceRecommendations({
    required String modelName,
    required AppSettings settings,
  }) {
    final recommendations = <String, dynamic>{
      'warnings': <String>[],
      'suggestions': <String>[],
      'optimizations': <String, dynamic>{},
    };

    try {
      final recommendedContext = getRecommendedContextLength(modelName);

      // Context length recommendations
      if (settings.contextLength > recommendedContext * 2) {
        (recommendations['warnings'] as List<String>).add(
            'Context length (${settings.contextLength}) is very high for $modelName. '
            'Consider reducing to $recommendedContext for better performance.');
        recommendations['optimizations']['recommended_context'] =
            recommendedContext;
      } else if (settings.contextLength < recommendedContext ~/ 2) {
        (recommendations['suggestions'] as List<String>).add(
            'Context length (${settings.contextLength}) could be increased to $recommendedContext '
            'for better conversation memory with $modelName.');
        recommendations['optimizations']['recommended_context'] =
            recommendedContext;
      }

      // Model-specific suggestions
      final modelKey = _getModelKey(modelName);
      switch (modelKey) {
        case 'codellama':
        case 'codegemma':
          (recommendations['suggestions'] as List<String>).add(
              'For code generation, consider using a system prompt that specifies the programming language and coding style.');
          break;
        case 'llava':
        case 'bakllava':
          (recommendations['suggestions'] as List<String>).add(
              'Vision models work best with clear, high-resolution images and specific questions about visual content.');
          break;
        case 'qwen2.5':
          (recommendations['suggestions'] as List<String>).add(
              'This model supports thinking processes. Enable thinking bubbles in settings for better insight into reasoning.');
          break;
      }

      return recommendations;
    } catch (e) {
      AppLogger.error('Error generating performance recommendations', e);
      return {
        'warnings': <String>[],
        'suggestions': <String>[
          'Unable to generate recommendations due to an error.'
        ],
        'optimizations': <String, dynamic>{},
      };
    }
  }

  /// Validate current settings for optimal performance
  static bool validateSettings({
    required String modelName,
    required AppSettings settings,
  }) {
    try {
      final recommendedContext = getRecommendedContextLength(modelName);

      // Check if context length is reasonable
      if (settings.contextLength > recommendedContext * 4) {
        AppLogger.warning('Context length too high for optimal performance');
        return false;
      }

      if (settings.contextLength < 1024) {
        AppLogger.warning(
            'Context length too low for meaningful conversations');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('Error validating settings', e);
      return false;
    }
  }
}
