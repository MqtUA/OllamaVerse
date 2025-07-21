import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Service for handling migration to new generation settings system
class SettingsMigrationService {
  static const String _settingsKey = 'app_settings';
  static const String _lastSelectedModelKey = 'last_selected_model';

  /// Check if settings need migration to new generation settings system
  static Future<bool> needsMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson == null) {
        // Check if this is a completely new user or an existing user without settings
        return await _isExistingUserWithoutSettings(prefs);
      }
      
      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      return !settingsMap.containsKey('generationSettings');
    } catch (e) {
      AppLogger.error('Error checking if settings need migration', e);
      return false;
    }
  }

  /// Check if this is an existing user who doesn't have settings yet
  static Future<bool> _isExistingUserWithoutSettings(SharedPreferences prefs) async {
    try {
      // Check for any existing chat data or other indicators of previous usage
      final keys = prefs.getKeys();
      
      // Look for chat data (chats are stored with keys like 'chat_[id]')
      final hasChats = keys.any((key) => key.startsWith('chat_'));
      
      // Look for other app usage indicators
      final hasLastModel = prefs.getString(_lastSelectedModelKey) != null;
      final hasOtherSettings = keys.any((key) => 
        key.contains('ollama') || 
        key.contains('font') || 
        key.contains('theme') ||
        key.contains('context')
      );
      
      // If user has chats or other settings, they're an existing user needing migration
      return hasChats || hasLastModel || hasOtherSettings;
    } catch (e) {
      AppLogger.error('Error checking for existing user data', e);
      return false;
    }
  }

  /// Perform migration to new generation settings system
  static Future<bool> migrateToGenerationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Handle both existing settings and new users
      Map<String, dynamic> settingsMap;
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        
        // Check if already migrated
        if (settingsMap.containsKey('generationSettings')) {
          AppLogger.info('Settings already migrated, skipping migration');
          return true; // Already migrated
        }
      } else {
        // Create new settings map for existing users without settings
        settingsMap = <String, dynamic>{};
        AppLogger.info('Creating new settings for existing user');
      }
      
      // Get last selected model to infer appropriate settings
      final lastSelectedModel = prefs.getString(_lastSelectedModelKey) ?? '';
      final generationSettings = _inferSettingsFromModel(lastSelectedModel);
      
      // Validate the inferred settings before applying
      final validatedSettings = _validateAndFixSettings(generationSettings);
      
      // Add generation settings to settings map
      settingsMap['generationSettings'] = validatedSettings;
      
      // Add migration metadata
      settingsMap['_migrationInfo'] = {
        'migratedFrom': settingsJson != null ? 'legacy_settings' : 'new_user_with_data',
        'migratedAt': DateTime.now().toIso8601String(),
        'previousModel': lastSelectedModel,
        'settingsValidated': true,
        'migrationVersion': '1.0',
      };
      
      // Ensure no existing functionality is broken by preserving other settings
      await _preserveExistingFunctionality(prefs, settingsMap);
      
      // Save updated settings
      await prefs.setString(_settingsKey, jsonEncode(settingsMap));
      
      AppLogger.info('Successfully migrated settings to generation settings system');
      AppLogger.info('Applied validated settings for model: $lastSelectedModel');
      
      return true;
    } catch (e) {
      AppLogger.error('Error migrating settings to new generation settings system', e);
      return false;
    }
  }

  /// Validate and fix generation settings to ensure they're safe
  static Map<String, dynamic> _validateAndFixSettings(Map<String, dynamic> settings) {
    final validated = Map<String, dynamic>.from(settings);
    
    // Validate temperature (0.0 - 2.0)
    final temp = validated['temperature'] as double? ?? 0.7;
    validated['temperature'] = temp.clamp(0.0, 2.0);
    
    // Validate topP (0.0 - 1.0)
    final topP = validated['topP'] as double? ?? 0.9;
    validated['topP'] = topP.clamp(0.0, 1.0);
    
    // Validate topK (1 - 100)
    final topK = validated['topK'] as int? ?? 40;
    validated['topK'] = topK.clamp(1, 100);
    
    // Validate repeatPenalty (0.5 - 2.0)
    final repeatPenalty = validated['repeatPenalty'] as double? ?? 1.1;
    validated['repeatPenalty'] = repeatPenalty.clamp(0.5, 2.0);
    
    // Validate maxTokens (-1 or 1 - 4096)
    final maxTokens = validated['maxTokens'] as int? ?? -1;
    if (maxTokens != -1) {
      validated['maxTokens'] = maxTokens.clamp(1, 4096);
    }
    
    // Validate numThread (1 - 16)
    final numThread = validated['numThread'] as int? ?? 4;
    validated['numThread'] = numThread.clamp(1, 16);
    
    return validated;
  }

  /// Preserve existing functionality during migration
  static Future<void> _preserveExistingFunctionality(
    SharedPreferences prefs, 
    Map<String, dynamic> settingsMap
  ) async {
    try {
      // Preserve existing app settings if they exist
      final existingKeys = [
        'ollamaHost', 'ollamaPort', 'fontSize', 'showLiveResponse',
        'contextLength', 'systemPrompt', 'darkMode', 
        'thinkingBubbleDefaultExpanded', 'thinkingBubbleAutoCollapse'
      ];
      
      for (final key in existingKeys) {
        if (!settingsMap.containsKey(key)) {
          // Set sensible defaults for missing settings
          switch (key) {
            case 'ollamaHost':
              settingsMap[key] = '127.0.0.1';
              break;
            case 'ollamaPort':
              settingsMap[key] = 11434;
              break;
            case 'fontSize':
              settingsMap[key] = 16.0;
              break;
            case 'showLiveResponse':
              settingsMap[key] = false;
              break;
            case 'contextLength':
              settingsMap[key] = 4096;
              break;
            case 'systemPrompt':
              settingsMap[key] = '';
              break;
            case 'darkMode':
              settingsMap[key] = false;
              break;
            case 'thinkingBubbleDefaultExpanded':
              settingsMap[key] = true;
              break;
            case 'thinkingBubbleAutoCollapse':
              settingsMap[key] = false;
              break;
          }
        }
      }
      
      AppLogger.info('Preserved existing functionality during migration');
    } catch (e) {
      AppLogger.error('Error preserving existing functionality', e);
    }
  }

  /// Get migration status information
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson == null) {
        return {
          'hasSavedSettings': false,
          'needsMigration': false,
          'hasGenerationSettings': false,
          'wasMigrated': false,
        };
      }
      
      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      final hasGenerationSettings = settingsMap.containsKey('generationSettings');
      final hasMigrationInfo = settingsMap.containsKey('_migrationInfo');
      
      return {
        'hasSavedSettings': true,
        'needsMigration': !hasGenerationSettings,
        'hasGenerationSettings': hasGenerationSettings,
        'wasMigrated': hasMigrationInfo,
        'migrationInfo': hasMigrationInfo ? settingsMap['_migrationInfo'] : null,
      };
    } catch (e) {
      AppLogger.error('Error getting migration status', e);
      return {
        'error': e.toString(),
        'hasSavedSettings': false,
        'needsMigration': false,
        'hasGenerationSettings': false,
        'wasMigrated': false,
      };
    }
  }

  /// Infer generation settings based on previously used model
  static Map<String, dynamic> _inferSettingsFromModel(String modelName) {
    // If no model name is available, use defaults
    if (modelName.isEmpty) {
      return _getDefaultGenerationSettings();
    }
    
    final lowerName = modelName.toLowerCase();
    
    // Infer settings based on model type
    if (lowerName.contains('codellama') || lowerName.contains('codegemma')) {
      // Code models - lower temperature, higher repeat penalty
      return {
        'temperature': 0.3,
        'topP': 0.8,
        'topK': 40,
        'repeatPenalty': 1.2,
        'maxTokens': -1,
        'numThread': 4,
      };
    } else if (lowerName.contains('llava') || lowerName.contains('bakllava') || 
               lowerName.contains('vision')) {
      // Vision models
      return {
        'temperature': 0.6,
        'topP': 0.9,
        'topK': 40,
        'repeatPenalty': 1.1,
        'maxTokens': -1,
        'numThread': 6,
      };
    } else if (lowerName.contains('llama3')) {
      // Llama 3 models
      return {
        'temperature': 0.8,
        'topP': 0.95,
        'topK': 40,
        'repeatPenalty': 1.05,
        'maxTokens': -1,
        'numThread': 6,
      };
    } else if (lowerName.contains('qwen')) {
      // Qwen models
      return {
        'temperature': 0.7,
        'topP': 0.9,
        'topK': 40,
        'repeatPenalty': 1.0,
        'maxTokens': -1,
        'numThread': 4,
      };
    }
    
    // Default Llama 2 settings
    return _getDefaultGenerationSettings();
  }

  /// Get default generation settings as Map
  static Map<String, dynamic> _getDefaultGenerationSettings() {
    return {
      'temperature': 0.7,
      'topP': 0.9,
      'topK': 40,
      'repeatPenalty': 1.1,
      'maxTokens': -1,
      'numThread': 4,
    };
  }

  /// Create a notification message about the migration
  static String getMigrationNotificationMessage() {
    return 'Your settings have been migrated from the old optimization system to the new universal generation settings. '
           'Custom settings have been applied based on your previously used model. '
           'You can now customize these settings globally or per-chat.';
  }

  /// Check if we should show a migration notification
  static Future<bool> shouldShowMigrationNotification() async {
    final status = await getMigrationStatus();
    
    // Only show notification if migration was performed but not acknowledged
    return status['wasMigrated'] == true && 
           status['migrationInfo'] != null &&
           !(status['migrationInfo']['notificationShown'] ?? false);
  }

  /// Mark migration notification as shown
  static Future<void> markMigrationNotificationShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson == null) {
        return;
      }
      
      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      
      if (settingsMap.containsKey('_migrationInfo')) {
        final migrationInfo = settingsMap['_migrationInfo'] as Map<String, dynamic>;
        migrationInfo['notificationShown'] = true;
        
        // Save updated settings
        await prefs.setString(_settingsKey, jsonEncode(settingsMap));
        AppLogger.info('Migration notification marked as shown');
      }
    } catch (e) {
      AppLogger.error('Error marking migration notification as shown', e);
    }
  }
}