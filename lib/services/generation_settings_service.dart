import '../models/generation_settings.dart';
import '../models/chat.dart';
import '../models/app_settings.dart';

/// Service for resolving generation settings and converting them to API format
class GenerationSettingsService {
  /// Resolves the effective generation settings for a chat
  /// 
  /// Returns per-chat settings if available, otherwise returns global settings
  /// from app settings. Always returns a valid GenerationSettings instance.
  static GenerationSettings getEffectiveSettings({
    required Chat? chat,
    required AppSettings globalSettings,
  }) {
    // If chat has custom settings, use those
    if (chat?.hasCustomGenerationSettings == true) {
      return chat!.customGenerationSettings!;
    }
    
    // Otherwise use global settings
    return globalSettings.generationSettings;
  }

  /// Builds Ollama API options from generation settings
  /// 
  /// Only includes non-default values to avoid API conflicts.
  /// Optionally includes context length and streaming-specific options.
  static Map<String, dynamic> buildOllamaOptions({
    required GenerationSettings settings,
    int? contextLength,
    bool isStreaming = false,
  }) {
    // Start with the base options from the settings
    final options = settings.toOllamaOptions();
    
    // Add context length if provided and different from default
    if (contextLength != null && contextLength != 4096) {
      options['num_ctx'] = contextLength;
    }
    
    // Add streaming-specific options if needed
    if (isStreaming) {
      // Ensure we have proper streaming configuration
      // Most streaming options are handled at the request level,
      // but we can add any streaming-specific generation options here
    }
    
    return options;
  }

  /// Validates generation settings and returns true if all settings are valid
  static bool validateSettings(GenerationSettings settings) {
    return settings.isValid();
  }

  /// Returns a list of validation errors for the given settings
  static List<String> getValidationErrors(GenerationSettings settings) {
    return settings.getValidationErrors();
  }

  /// Returns recommendations and warnings for the given settings
  /// 
  /// This includes both validation errors and performance warnings
  /// to help users understand the impact of their settings choices.
  static List<String> getRecommendations(GenerationSettings settings) {
    final recommendations = <String>[];
    
    // Add validation errors first (these are critical)
    final errors = settings.getValidationErrors();
    for (final error in errors) {
      recommendations.add('ERROR: $error');
    }
    
    // Add performance warnings
    final warnings = settings.getWarnings();
    for (final warning in warnings) {
      recommendations.add('WARNING: $warning');
    }
    
    // Add positive recommendations for good settings
    if (errors.isEmpty && warnings.isEmpty) {
      recommendations.add('Settings look good! These values should work well for most use cases.');
    }
    
    // Add specific recommendations based on settings combinations
    if (settings.temperature > 1.0 && settings.topP > 0.95) {
      recommendations.add('SUGGESTION: High temperature with high Top P may produce very unpredictable results. Consider lowering one of these values.');
    }
    
    if (settings.temperature < 0.3 && settings.topK < 10) {
      recommendations.add('SUGGESTION: Very conservative settings may produce repetitive responses. Consider increasing temperature or Top K for more variety.');
    }
    
    if (settings.maxTokens > 0 && settings.maxTokens < 100) {
      recommendations.add('SUGGESTION: Low max tokens may cut off responses mid-sentence. Consider increasing or setting to unlimited (-1).');
    }
    
    return recommendations;
  }

  /// Creates a safe, validated version of the given settings
  /// 
  /// This method ensures all values are within valid ranges,
  /// clamping invalid values to safe defaults.
  static GenerationSettings createSafeSettings(GenerationSettings settings) {
    return GenerationSettings.validated(
      temperature: settings.temperature,
      topP: settings.topP,
      topK: settings.topK,
      repeatPenalty: settings.repeatPenalty,
      maxTokens: settings.maxTokens,
      numThread: settings.numThread,
    );
  }

  /// Compares two generation settings and returns a summary of differences
  /// 
  /// Useful for showing users what will change when switching between
  /// global and per-chat settings.
  static Map<String, dynamic> compareSettings(
    GenerationSettings settings1,
    GenerationSettings settings2,
  ) {
    final differences = <String, dynamic>{};
    
    if (settings1.temperature != settings2.temperature) {
      differences['temperature'] = {
        'from': settings1.temperature,
        'to': settings2.temperature,
      };
    }
    
    if (settings1.topP != settings2.topP) {
      differences['topP'] = {
        'from': settings1.topP,
        'to': settings2.topP,
      };
    }
    
    if (settings1.topK != settings2.topK) {
      differences['topK'] = {
        'from': settings1.topK,
        'to': settings2.topK,
      };
    }
    
    if (settings1.repeatPenalty != settings2.repeatPenalty) {
      differences['repeatPenalty'] = {
        'from': settings1.repeatPenalty,
        'to': settings2.repeatPenalty,
      };
    }
    
    if (settings1.maxTokens != settings2.maxTokens) {
      differences['maxTokens'] = {
        'from': settings1.maxTokens,
        'to': settings2.maxTokens,
      };
    }
    
    if (settings1.numThread != settings2.numThread) {
      differences['numThread'] = {
        'from': settings1.numThread,
        'to': settings2.numThread,
      };
    }
    
    return differences;
  }

  /// Returns a human-readable summary of the generation settings
  /// 
  /// Useful for displaying settings information in the UI
  static String getSettingsSummary(GenerationSettings settings) {
    final parts = <String>[];
    
    parts.add('Temp: ${settings.temperature.toStringAsFixed(1)}');
    parts.add('Top-P: ${settings.topP.toStringAsFixed(2)}');
    parts.add('Top-K: ${settings.topK}');
    parts.add('Repeat: ${settings.repeatPenalty.toStringAsFixed(1)}');
    
    if (settings.maxTokens == -1) {
      parts.add('Tokens: Unlimited');
    } else {
      parts.add('Tokens: ${settings.maxTokens}');
    }
    
    parts.add('Threads: ${settings.numThread}');
    
    return parts.join(' | ');
  }

  /// Determines if the given settings are "extreme" and might need user confirmation
  /// 
  /// This helps prevent users from accidentally setting values that could
  /// cause poor performance or unexpected behavior.
  static bool areSettingsExtreme(GenerationSettings settings) {
    return settings.temperature > 1.5 ||
           settings.temperature < 0.1 ||
           settings.topP < 0.1 ||
           settings.topK < 5 ||
           settings.repeatPenalty > 1.5 ||
           (settings.maxTokens > 0 && settings.maxTokens < 50) ||
           settings.numThread > 8;
  }

  /// Returns the default settings for quick reset functionality
  static GenerationSettings getDefaultSettings() {
    return GenerationSettings.defaults();
  }
}