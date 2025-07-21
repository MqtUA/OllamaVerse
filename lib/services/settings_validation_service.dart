import '../models/app_settings.dart';
import '../models/generation_settings.dart';
import '../utils/logger.dart';

/// Service to validate and ensure all settings are properly applied throughout the app
class SettingsValidationService {

  /// Validate all settings and return validation results
  static Map<String, dynamic> validateAllSettings(AppSettings settings) {
    final results = <String, dynamic>{
      'isValid': true,
      'warnings': <String>[],
      'errors': <String>[],
      'recommendations': <String>[],
    };

    try {
      // Validate Ollama connection settings
      _validateOllamaSettings(settings, results);
      
      // Validate UI settings
      _validateUISettings(settings, results);
      
      // Validate performance settings
      _validatePerformanceSettings(settings, results);
      
      // Validate system prompt
      _validateSystemPrompt(settings, results);
      
      // Validate generation settings
      _validateGenerationSettings(settings, results);

      // Overall validation status
      results['isValid'] = (results['errors'] as List).isEmpty;

      AppLogger.debug('Settings validation completed: ${results['isValid'] ? 'PASSED' : 'FAILED'}');
      
      return results;
    } catch (e) {
      AppLogger.error('Error during settings validation', e);
      results['isValid'] = false;
      (results['errors'] as List<String>).add('Validation failed due to an error: ${e.toString()}');
      return results;
    }
  }

  /// Validate Ollama connection settings
  static void _validateOllamaSettings(AppSettings settings, Map<String, dynamic> results) {
    final warnings = results['warnings'] as List<String>;
    final errors = results['errors'] as List<String>;

    // Validate host
    if (settings.ollamaHost.isEmpty) {
      errors.add('Ollama host cannot be empty');
    } else if (settings.ollamaHost == 'localhost' || settings.ollamaHost == '127.0.0.1') {
      // This is fine for local development
    } else if (!_isValidHostname(settings.ollamaHost)) {
      warnings.add('Ollama host format may be invalid: ${settings.ollamaHost}');
    }

    // Validate port
    if (settings.ollamaPort < 1 || settings.ollamaPort > 65535) {
      errors.add('Ollama port must be between 1 and 65535');
    } else if (settings.ollamaPort != 11434) {
      warnings.add('Using non-standard Ollama port: ${settings.ollamaPort}');
    }

    // Validate URL construction
    try {
      final url = settings.ollamaUrl;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        errors.add('Invalid Ollama URL format: $url');
      }
    } catch (e) {
      errors.add('Failed to construct Ollama URL: ${e.toString()}');
    }
  }

  /// Validate UI settings
  static void _validateUISettings(AppSettings settings, Map<String, dynamic> results) {
    final warnings = results['warnings'] as List<String>;
    final recommendations = results['recommendations'] as List<String>;

    // Validate font size
    if (settings.fontSize < 10 || settings.fontSize > 30) {
      warnings.add('Font size ${settings.fontSize} may be too extreme for comfortable reading');
    } else if (settings.fontSize < 12) {
      recommendations.add('Consider increasing font size for better readability');
    } else if (settings.fontSize > 20) {
      recommendations.add('Consider decreasing font size for more content on screen');
    }

    // Validate thinking bubble settings
    if (settings.thinkingBubbleDefaultExpanded && !settings.thinkingBubbleAutoCollapse) {
      recommendations.add('Consider enabling auto-collapse for thinking bubbles to reduce screen clutter');
    }
  }

  /// Validate performance settings
  static void _validatePerformanceSettings(AppSettings settings, Map<String, dynamic> results) {
    final warnings = results['warnings'] as List<String>;
    final recommendations = results['recommendations'] as List<String>;

    // Validate context length
    if (settings.contextLength < 1024) {
      warnings.add('Context length ${settings.contextLength} is very low and may limit conversation quality');
    } else if (settings.contextLength > 32768) {
      warnings.add('Context length ${settings.contextLength} is very high and may impact performance');
    } else if (settings.contextLength > 16384) {
      recommendations.add('High context length may slow down responses. Consider reducing if performance is an issue');
    }

    // Validate context length is a power of 2 or common value
    final commonValues = [1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072];
    if (!commonValues.contains(settings.contextLength)) {
      recommendations.add('Consider using a standard context length value for optimal performance');
    }

    // Live response setting
    if (!settings.showLiveResponse) {
      recommendations.add('Enable live response for better user experience during long generations');
    }
  }

  /// Validate system prompt
  static void _validateSystemPrompt(AppSettings settings, Map<String, dynamic> results) {
    final warnings = results['warnings'] as List<String>;
    final recommendations = results['recommendations'] as List<String>;

    if (settings.systemPrompt.isNotEmpty) {
      // Check length
      if (settings.systemPrompt.length > 1000) {
        warnings.add('System prompt is very long (${settings.systemPrompt.length} characters) and may consume significant context');
      }

      // Check for common issues
      if (settings.systemPrompt.toLowerCase().contains('you are chatgpt') ||
          settings.systemPrompt.toLowerCase().contains('you are gpt')) {
        warnings.add('System prompt references ChatGPT/GPT which may confuse local models');
      }

      // Recommendations for good system prompts
      if (!settings.systemPrompt.toLowerCase().contains('helpful') &&
          !settings.systemPrompt.toLowerCase().contains('assistant')) {
        recommendations.add('Consider including "helpful assistant" in your system prompt for better behavior');
      }
    } else {
      recommendations.add('Consider adding a system prompt to define the AI assistant\'s behavior and personality');
    }
  }

  /// Check if hostname is valid format
  static bool _isValidHostname(String hostname) {
    // Basic hostname validation
    if (hostname.isEmpty) return false;
    
    // Check for valid characters
    final validHostnameRegex = RegExp(r'^[a-zA-Z0-9.-]+$');
    if (!validHostnameRegex.hasMatch(hostname)) return false;
    
    // Check for valid IP address format
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipRegex.hasMatch(hostname)) {
      final parts = hostname.split('.');
      return parts.every((part) {
        final num = int.tryParse(part);
        return num != null && num >= 0 && num <= 255;
      });
    }
    
    // Assume valid hostname if not IP
    return true;
  }

  /// Get settings health score (0-100)
  static int getSettingsHealthScore(AppSettings settings) {
    try {
      final validation = validateAllSettings(settings);
      
      int score = 100;
      
      // Deduct points for errors (major issues)
      final errors = validation['errors'] as List<String>;
      score -= errors.length * 25; // 25 points per error
      
      // Deduct points for warnings (moderate issues)
      final warnings = validation['warnings'] as List<String>;
      score -= warnings.length * 10; // 10 points per warning
      
      // Deduct points for recommendations (minor issues)
      final recommendations = validation['recommendations'] as List<String>;
      score -= recommendations.length * 5; // 5 points per recommendation
      
      return score.clamp(0, 100);
    } catch (e) {
      AppLogger.error('Error calculating settings health score', e);
      return 0;
    }
  }

  /// Get quick settings status
  static String getSettingsStatus(AppSettings settings) {
    final score = getSettingsHealthScore(settings);
    
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Critical';
  }

  /// Auto-fix common settings issues
  static AppSettings autoFixSettings(AppSettings settings) {
    try {
      AppLogger.info('Auto-fixing settings issues');
      
      var fixedSettings = settings;
      
      // Fix font size if too extreme
      if (settings.fontSize < 10) {
        fixedSettings = fixedSettings.copyWith(fontSize: 12.0);
        AppLogger.info('Fixed font size: ${settings.fontSize} -> 12.0');
      } else if (settings.fontSize > 30) {
        fixedSettings = fixedSettings.copyWith(fontSize: 20.0);
        AppLogger.info('Fixed font size: ${settings.fontSize} -> 20.0');
      }
      
      // Fix context length if too extreme
      if (settings.contextLength < 1024) {
        fixedSettings = fixedSettings.copyWith(contextLength: 4096);
        AppLogger.info('Fixed context length: ${settings.contextLength} -> 4096');
      } else if (settings.contextLength > 131072) {
        fixedSettings = fixedSettings.copyWith(contextLength: 32768);
        AppLogger.info('Fixed context length: ${settings.contextLength} -> 32768');
      }
      
      // Fix port if invalid
      if (settings.ollamaPort < 1 || settings.ollamaPort > 65535) {
        fixedSettings = fixedSettings.copyWith(ollamaPort: 11434);
        AppLogger.info('Fixed Ollama port: ${settings.ollamaPort} -> 11434');
      }
      
      // Fix host if empty
      if (settings.ollamaHost.isEmpty) {
        fixedSettings = fixedSettings.copyWith(ollamaHost: '127.0.0.1');
        AppLogger.info('Fixed Ollama host: empty -> 127.0.0.1');
      }
      
      return fixedSettings;
    } catch (e) {
      AppLogger.error('Error auto-fixing settings', e);
      return settings;
    }
  }

  /// Check if settings need to be applied to existing chats
  static bool shouldUpdateExistingChats(AppSettings oldSettings, AppSettings newSettings) {
    return oldSettings.systemPrompt != newSettings.systemPrompt;
  }

  /// Validate generation settings
  static void _validateGenerationSettings(AppSettings settings, Map<String, dynamic> results) {
    final warnings = results['warnings'] as List<String>;
    final errors = results['errors'] as List<String>;
    final recommendations = results['recommendations'] as List<String>;
    
    final genSettings = settings.generationSettings;
    
    // Get validation errors from the model
    final validationErrors = genSettings.getValidationErrors();
    errors.addAll(validationErrors);
    
    // Get performance warnings from the model
    final performanceWarnings = genSettings.getWarnings();
    warnings.addAll(performanceWarnings);
    
    // Additional contextual validation
    _validateGenerationSettingsCombinations(genSettings, warnings, recommendations);
    
    // Validate against system capabilities
    _validateGenerationSettingsCapabilities(genSettings, warnings, recommendations);
  }

  /// Validate combinations of generation settings that might cause issues
  static void _validateGenerationSettingsCombinations(
    GenerationSettings settings, 
    List<String> warnings, 
    List<String> recommendations
  ) {
    // Temperature and Top P combination
    if (settings.temperature > 1.2 && settings.topP > 0.95) {
      warnings.add('Very high temperature with very high Top P may produce unpredictable results');
      recommendations.add('Consider lowering either temperature or Top P for more consistent responses');
    }
    
    // Temperature and Top K combination
    if (settings.temperature < 0.2 && settings.topK < 10) {
      warnings.add('Very low temperature with very low Top K may produce repetitive responses');
      recommendations.add('Consider increasing either temperature or Top K for more variety');
    }
    
    // Repeat penalty and temperature combination
    if (settings.repeatPenalty > 1.4 && settings.temperature < 0.3) {
      warnings.add('High repeat penalty with low temperature may produce incoherent responses');
      recommendations.add('Balance repeat penalty and temperature for better coherence');
    }
    
    // Max tokens and context length relationship
    if (settings.maxTokens > 0 && settings.maxTokens > 2048) {
      recommendations.add('High max tokens may consume significant context length');
    }
    
    // Thread count recommendations
    if (settings.numThread > 8) {
      recommendations.add('High thread count may not improve performance on all devices');
    } else if (settings.numThread < 2) {
      recommendations.add('Consider using 2-4 threads for better performance');
    }
  }

  /// Validate generation settings against system capabilities
  static void _validateGenerationSettingsCapabilities(
    GenerationSettings settings, 
    List<String> warnings, 
    List<String> recommendations
  ) {
    // Memory usage warnings
    if (settings.numThread > 6 && settings.maxTokens > 2000) {
      warnings.add('High thread count with high max tokens may consume significant memory');
    }
    
    // Performance recommendations
    if (settings.temperature > 1.0 && settings.topK > 80) {
      recommendations.add('High creativity settings may slow down generation');
    }
    
    // Quality recommendations
    if (settings.topP < 0.3 && settings.topK < 20) {
      recommendations.add('Very restrictive sampling may reduce response quality');
    }
    
    // Efficiency recommendations
    if (settings.maxTokens == -1) {
      recommendations.add('Consider setting a max token limit to prevent very long responses');
    } else if (settings.maxTokens > 0 && settings.maxTokens < 50) {
      warnings.add('Very low max tokens may cut off responses mid-sentence');
    }
  }

  /// Validate individual generation settings with real-time feedback
  static Map<String, dynamic> validateGenerationSettingsRealTime(GenerationSettings settings) {
    final results = <String, dynamic>{
      'isValid': true,
      'errors': <String>[],
      'warnings': <String>[],
      'suggestions': <String>[],
      'fieldErrors': <String, String>{},
    };

    try {
      // Basic validation
      final errors = settings.getValidationErrors();
      results['errors'] = errors;
      results['isValid'] = errors.isEmpty;
      
      // Performance warnings
      final warnings = settings.getWarnings();
      results['warnings'] = warnings;
      
      // Field-specific errors for UI
      final fieldErrors = <String, String>{};
      
      // Temperature field validation
      if (settings.temperature < 0.0 || settings.temperature > 2.0) {
        fieldErrors['temperature'] = 'Must be between 0.0 and 2.0';
      } else if (settings.temperature > 1.5) {
        fieldErrors['temperature'] = 'Very high - may produce random responses';
      } else if (settings.temperature < 0.1) {
        fieldErrors['temperature'] = 'Very low - may produce repetitive responses';
      }
      
      // Top P field validation
      if (settings.topP < 0.0 || settings.topP > 1.0) {
        fieldErrors['topP'] = 'Must be between 0.0 and 1.0';
      } else if (settings.topP < 0.1) {
        fieldErrors['topP'] = 'Very low - may limit diversity';
      }
      
      // Top K field validation
      if (settings.topK < 1 || settings.topK > 100) {
        fieldErrors['topK'] = 'Must be between 1 and 100';
      } else if (settings.topK < 5) {
        fieldErrors['topK'] = 'Very low - may cause repetition';
      }
      
      // Repeat Penalty field validation
      if (settings.repeatPenalty < 0.5 || settings.repeatPenalty > 2.0) {
        fieldErrors['repeatPenalty'] = 'Must be between 0.5 and 2.0';
      } else if (settings.repeatPenalty > 1.5) {
        fieldErrors['repeatPenalty'] = 'Very high - may cause incoherence';
      }
      
      // Max Tokens field validation
      if (settings.maxTokens != -1 && (settings.maxTokens < 1 || settings.maxTokens > 4096)) {
        fieldErrors['maxTokens'] = 'Must be -1 (unlimited) or 1-4096';
      } else if (settings.maxTokens > 0 && settings.maxTokens < 50) {
        fieldErrors['maxTokens'] = 'Very low - may cut off responses';
      }
      
      // Num Thread field validation
      if (settings.numThread < 1 || settings.numThread > 16) {
        fieldErrors['numThread'] = 'Must be between 1 and 16';
      } else if (settings.numThread > 8) {
        fieldErrors['numThread'] = 'High count may not help on all devices';
      }
      
      results['fieldErrors'] = fieldErrors;
      
      // Helpful suggestions
      final suggestions = <String>[];
      
      if (errors.isEmpty && warnings.isEmpty) {
        suggestions.add('Settings look good for general use');
      }
      
      if (settings.temperature >= 0.6 && settings.temperature <= 0.8 && 
          settings.topP >= 0.8 && settings.topP <= 0.95) {
        suggestions.add('Good balance for creative but coherent responses');
      }
      
      if (settings.temperature <= 0.3 && settings.topK <= 20) {
        suggestions.add('Conservative settings - good for factual responses');
      }
      
      if (settings.temperature >= 1.0 && settings.topP >= 0.9) {
        suggestions.add('Creative settings - good for storytelling and brainstorming');
      }
      
      results['suggestions'] = suggestions;
      
      return results;
    } catch (e) {
      AppLogger.error('Error in real-time generation settings validation', e);
      results['isValid'] = false;
      (results['errors'] as List<String>).add('Validation error: ${e.toString()}');
      return results;
    }
  }

  /// Get helpful error messages with suggestions for fixing
  static String getHelpfulErrorMessage(String field, dynamic value) {
    switch (field.toLowerCase()) {
      case 'temperature':
        if (value is double) {
          if (value < 0.0) return 'Temperature cannot be negative. Try 0.1 for very focused responses.';
          if (value > 2.0) return 'Temperature too high. Try 1.2 for very creative responses.';
          if (value > 1.5) return 'Very high temperature may produce random text. Consider 0.7-1.0 for balanced creativity.';
          if (value < 0.1) return 'Very low temperature may cause repetition. Consider 0.3-0.7 for more variety.';
        }
        return 'Temperature controls randomness. Use 0.1-0.5 for focused responses, 0.6-1.0 for balanced, 1.0+ for creative.';
        
      case 'topp':
        if (value is double) {
          if (value < 0.0) return 'Top P cannot be negative. Try 0.1 for very focused word selection.';
          if (value > 1.0) return 'Top P cannot exceed 1.0. Try 0.95 for diverse word selection.';
          if (value < 0.1) return 'Very low Top P may limit vocabulary. Consider 0.3-0.9 for better variety.';
        }
        return 'Top P controls word diversity. Use 0.1-0.5 for focused vocabulary, 0.6-0.95 for diverse responses.';
        
      case 'topk':
        if (value is int) {
          if (value < 1) return 'Top K must be at least 1. Try 10-40 for balanced word selection.';
          if (value > 100) return 'Top K too high. Try 20-80 for good vocabulary range.';
          if (value < 5) return 'Very low Top K may cause repetition. Consider 10-40 for variety.';
        }
        return 'Top K limits vocabulary size. Use 5-20 for focused responses, 20-80 for varied vocabulary.';
        
      case 'repeatpenalty':
        if (value is double) {
          if (value < 0.5) return 'Repeat penalty too low. Try 0.8-1.2 for balanced repetition control.';
          if (value > 2.0) return 'Repeat penalty too high. Try 1.0-1.3 to avoid incoherent responses.';
          if (value > 1.5) return 'High repeat penalty may cause strange responses. Consider 1.0-1.2 for balance.';
        }
        return 'Repeat penalty reduces repetition. Use 0.8-1.0 to allow some repetition, 1.1-1.3 to reduce it.';
        
      case 'maxtokens':
        if (value is int) {
          if (value != -1 && value < 1) return 'Max tokens must be -1 (unlimited) or positive. Try 100-1000 for typical responses.';
          if (value > 4096) return 'Max tokens too high. Try 500-2000 for long responses, or -1 for unlimited.';
          if (value > 0 && value < 50) return 'Very low max tokens may cut off responses. Consider 100+ or -1 for unlimited.';
        }
        return 'Max tokens limits response length. Use 100-500 for short responses, 1000+ for long ones, -1 for unlimited.';
        
      case 'numthread':
        if (value is int) {
          if (value < 1) return 'Thread count must be at least 1. Try 2-6 for good performance.';
          if (value > 16) return 'Too many threads. Try 2-8 for optimal performance on most devices.';
          if (value > 8) return 'High thread count may not improve performance. Consider 2-6 for balance.';
        }
        return 'Thread count affects generation speed. Use 2-4 for most devices, up to 8 for powerful systems.';
        
      default:
        return 'Please check the value and try again.';
    }
  }

  /// Get settings migration recommendations
  static List<String> getMigrationRecommendations(AppSettings oldSettings, AppSettings newSettings) {
    final recommendations = <String>[];
    
    try {
      // System prompt changes
      if (oldSettings.systemPrompt != newSettings.systemPrompt) {
        if (newSettings.systemPrompt.isNotEmpty && oldSettings.systemPrompt.isEmpty) {
          recommendations.add('Apply new system prompt to existing chats for consistent behavior');
        } else if (newSettings.systemPrompt.isEmpty && oldSettings.systemPrompt.isNotEmpty) {
          recommendations.add('System prompt removed - existing chats will keep their current prompts');
        } else {
          recommendations.add('System prompt changed - consider updating existing chats');
        }
      }
      
      // Generation settings changes
      if (oldSettings.generationSettings != newSettings.generationSettings) {
        recommendations.add('Generation settings changed - new settings will apply to future messages');
        
        // Specific recommendations for significant changes
        final oldGen = oldSettings.generationSettings;
        final newGen = newSettings.generationSettings;
        
        if ((oldGen.temperature - newGen.temperature).abs() > 0.3) {
          recommendations.add('Temperature changed significantly - response creativity will be affected');
        }
        
        if ((oldGen.topP - newGen.topP).abs() > 0.2) {
          recommendations.add('Top P changed significantly - response diversity will be affected');
        }
        
        if ((oldGen.repeatPenalty - newGen.repeatPenalty).abs() > 0.3) {
          recommendations.add('Repeat penalty changed significantly - response repetition patterns will change');
        }
      }
      
      // Context length changes
      if (oldSettings.contextLength != newSettings.contextLength) {
        if (newSettings.contextLength > oldSettings.contextLength) {
          recommendations.add('Increased context length will improve conversation memory for new messages');
        } else {
          recommendations.add('Decreased context length may improve performance but reduce conversation memory');
        }
      }
      
      // Host/port changes
      if (oldSettings.ollamaHost != newSettings.ollamaHost || 
          oldSettings.ollamaPort != newSettings.ollamaPort) {
        recommendations.add('Ollama server settings changed - test connection to ensure models are available');
      }
      
      return recommendations;
    } catch (e) {
      AppLogger.error('Error generating migration recommendations', e);
      return ['Unable to generate migration recommendations due to an error'];
    }
  }
}