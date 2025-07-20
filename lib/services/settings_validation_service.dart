import '../models/app_settings.dart';
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