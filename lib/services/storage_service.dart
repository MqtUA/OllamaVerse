import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_settings.dart';
import '../utils/logger.dart';

/// Unified storage service that handles both regular and secure storage
/// Provides a single interface for all storage operations
class StorageService {
  static const String _settingsKey = 'app_settings';
  static const String _lastSelectedModelKey = 'last_selected_model';

  // Secure storage keys
  static const String _authTokenKey = 'auth_token';

  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Initialize the storage service
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      AppLogger.info('StorageService initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize StorageService', e);
      rethrow;
    }
  }

  /// Ensure preferences are initialized
  static SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError(
          'StorageService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // === APP SETTINGS ===

  /// Load app settings from storage
  Future<AppSettings> loadSettings() async {
    try {
      final settingsJson = _preferences.getString(_settingsKey);
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        
        // Handle migration from old settings format
        final migratedSettings = _migrateSettingsIfNeeded(settingsMap);
        
        AppLogger.debug('Loaded settings from storage');
        return AppSettings.fromJson(migratedSettings);
      }
    } catch (e) {
      AppLogger.error('Error loading settings', e);
      
      // Handle corrupted settings data
      if (e is FormatException) {
        AppLogger.warning('Settings data appears corrupted, resetting to defaults');
        await _resetCorruptedSettings();
      }
    }

    // Return default settings if loading fails
    AppLogger.info('Using default settings');
    return AppSettings();
  }

  /// Save app settings to storage
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final settingsJson = jsonEncode(settings.toJson());
      await _preferences.setString(_settingsKey, settingsJson);
      AppLogger.debug('Settings saved to storage');
    } catch (e) {
      AppLogger.error('Error saving settings', e);
      rethrow;
    }
  }

  // === LAST SELECTED MODEL ===

  /// Load last selected model from storage
  Future<String> loadLastSelectedModel() async {
    try {
      final model = _preferences.getString(_lastSelectedModelKey) ?? '';
      AppLogger.debug(
          'Loaded last selected model: ${model.isEmpty ? 'none' : model}');
      return model;
    } catch (e) {
      AppLogger.error('Error loading last selected model', e);
      return '';
    }
  }

  /// Save last selected model to storage
  Future<void> saveLastSelectedModel(String modelName) async {
    try {
      await _preferences.setString(_lastSelectedModelKey, modelName);
      AppLogger.debug('Saved last selected model: $modelName');
    } catch (e) {
      AppLogger.error('Error saving last selected model', e);
    }
  }

  // === SECURE STORAGE (AUTH TOKEN) ===

  /// Get authentication token from secure storage
  Future<String?> getAuthToken() async {
    try {
      final token = await _secureStorage.read(key: _authTokenKey);
      AppLogger.debug(
          'Auth token ${token != null ? 'retrieved' : 'not found'}');
      return token;
    } catch (e) {
      AppLogger.error('Error getting auth token', e);
      return null;
    }
  }

  /// Save authentication token to secure storage
  Future<void> saveAuthToken(String token) async {
    try {
      await _secureStorage.write(key: _authTokenKey, value: token);
      AppLogger.debug('Auth token saved to secure storage');
    } catch (e) {
      AppLogger.error('Error saving auth token', e);
      rethrow;
    }
  }

  /// Delete authentication token from secure storage
  Future<void> deleteAuthToken() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
      AppLogger.debug('Auth token deleted from secure storage');
    } catch (e) {
      AppLogger.error('Error deleting auth token', e);
    }
  }

  // === GENERIC STORAGE METHODS ===

  /// Store a string value (regular storage)
  Future<void> setString(String key, String value) async {
    try {
      await _preferences.setString(key, value);
      AppLogger.debug('Stored string value for key: $key');
    } catch (e) {
      AppLogger.error('Error storing string value for key: $key', e);
      rethrow;
    }
  }

  /// Get a string value (regular storage)
  String? getString(String key, {String? defaultValue}) {
    try {
      final value = _preferences.getString(key) ?? defaultValue;
      AppLogger.debug('Retrieved string value for key: $key');
      return value;
    } catch (e) {
      AppLogger.error('Error retrieving string value for key: $key', e);
      return defaultValue;
    }
  }

  /// Store a boolean value (regular storage)
  Future<void> setBool(String key, bool value) async {
    try {
      await _preferences.setBool(key, value);
      AppLogger.debug('Stored boolean value for key: $key');
    } catch (e) {
      AppLogger.error('Error storing boolean value for key: $key', e);
      rethrow;
    }
  }

  /// Get a boolean value (regular storage)
  bool getBool(String key, {bool defaultValue = false}) {
    try {
      final value = _preferences.getBool(key) ?? defaultValue;
      AppLogger.debug('Retrieved boolean value for key: $key');
      return value;
    } catch (e) {
      AppLogger.error('Error retrieving boolean value for key: $key', e);
      return defaultValue;
    }
  }

  /// Store an integer value (regular storage)
  Future<void> setInt(String key, int value) async {
    try {
      await _preferences.setInt(key, value);
      AppLogger.debug('Stored integer value for key: $key');
    } catch (e) {
      AppLogger.error('Error storing integer value for key: $key', e);
      rethrow;
    }
  }

  /// Get an integer value (regular storage)
  int getInt(String key, {int defaultValue = 0}) {
    try {
      final value = _preferences.getInt(key) ?? defaultValue;
      AppLogger.debug('Retrieved integer value for key: $key');
      return value;
    } catch (e) {
      AppLogger.error('Error retrieving integer value for key: $key', e);
      return defaultValue;
    }
  }

  /// Store a double value (regular storage)
  Future<void> setDouble(String key, double value) async {
    try {
      await _preferences.setDouble(key, value);
      AppLogger.debug('Stored double value for key: $key');
    } catch (e) {
      AppLogger.error('Error storing double value for key: $key', e);
      rethrow;
    }
  }

  /// Get a double value (regular storage)
  double? getDouble(String key, {double? defaultValue}) {
    try {
      final value = _preferences.getDouble(key) ?? defaultValue;
      AppLogger.debug('Retrieved double value for key: $key');
      return value;
    } catch (e) {
      AppLogger.error('Error retrieving double value for key: $key', e);
      return defaultValue;
    }
  }

  /// Store a secure string value (secure storage)
  Future<void> setSecureString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      AppLogger.debug('Stored secure string value for key: $key');
    } catch (e) {
      AppLogger.error('Error storing secure string value for key: $key', e);
      rethrow;
    }
  }

  /// Get a secure string value (secure storage)
  Future<String?> getSecureString(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      AppLogger.debug('Retrieved secure string value for key: $key');
      return value;
    } catch (e) {
      AppLogger.error('Error retrieving secure string value for key: $key', e);
      return null;
    }
  }

  /// Delete a secure value (secure storage)
  Future<void> deleteSecureString(String key) async {
    try {
      await _secureStorage.delete(key: key);
      AppLogger.debug('Deleted secure string value for key: $key');
    } catch (e) {
      AppLogger.error('Error deleting secure string value for key: $key', e);
    }
  }

  /// Remove a regular storage value
  Future<void> remove(String key) async {
    try {
      await _preferences.remove(key);
      AppLogger.debug('Removed value for key: $key');
    } catch (e) {
      AppLogger.error('Error removing value for key: $key', e);
    }
  }

  /// Check if a key exists in regular storage
  bool containsKey(String key) {
    try {
      return _preferences.containsKey(key);
    } catch (e) {
      AppLogger.error('Error checking if key exists: $key', e);
      return false;
    }
  }

  /// Get all keys from regular storage
  Set<String> getKeys() {
    try {
      return _preferences.getKeys();
    } catch (e) {
      AppLogger.error('Error getting all keys', e);
      return <String>{};
    }
  }

  /// Clear all regular storage data
  Future<void> clear() async {
    try {
      await _preferences.clear();
      AppLogger.info('Cleared all regular storage data');
    } catch (e) {
      AppLogger.error('Error clearing storage', e);
    }
  }

  /// Clear all secure storage data
  Future<void> clearSecure() async {
    try {
      await _secureStorage.deleteAll();
      AppLogger.info('Cleared all secure storage data');
    } catch (e) {
      AppLogger.error('Error clearing secure storage', e);
    }
  }

  /// Get storage statistics
  Map<String, dynamic> getStorageStats() {
    try {
      final keys = getKeys();
      return {
        'regular_storage_keys': keys.length,
        'total_keys': keys.toList(),
        'initialized': _prefs != null,
      };
    } catch (e) {
      AppLogger.error('Error getting storage stats', e);
      return {
        'error': e.toString(),
        'initialized': _prefs != null,
      };
    }
  }

  /// Get secure storage statistics (limited for security)
  Future<Map<String, dynamic>> getSecureStorageStats() async {
    try {
      // Note: We can't get all keys from secure storage for security reasons
      // We can only check for known keys
      final knownKeys = [_authTokenKey];
      int existingKeysCount = 0;

      for (final key in knownKeys) {
        final value = await _secureStorage.read(key: key);
        if (value != null) {
          existingKeysCount++;
        }
      }

      return {
        'known_keys_count': existingKeysCount,
        'total_known_keys': knownKeys.length,
      };
    } catch (e) {
      AppLogger.error('Error getting secure storage stats', e);
      return {
        'error': e.toString(),
      };
    }
  }

  // === MIGRATION AND ERROR HANDLING ===

  /// Migrate settings from old format to new format with GenerationSettings
  Map<String, dynamic> _migrateSettingsIfNeeded(Map<String, dynamic> settingsMap) {
    try {
      // Check if generationSettings already exists
      if (settingsMap.containsKey('generationSettings')) {
        // Settings already have generation settings, validate structure
        final generationSettings = settingsMap['generationSettings'];
        if (generationSettings is Map<String, dynamic>) {
          // Ensure all required fields exist with defaults
          final migratedGenerationSettings = _ensureGenerationSettingsDefaults(generationSettings);
          settingsMap['generationSettings'] = migratedGenerationSettings;
        } else {
          // Invalid generation settings, use defaults
          AppLogger.warning('Invalid generationSettings format, using defaults');
          settingsMap['generationSettings'] = _getDefaultGenerationSettings();
        }
      } else {
        // Old format without generation settings, add defaults
        AppLogger.info('Migrating settings to include generation settings');
        settingsMap['generationSettings'] = _getDefaultGenerationSettings();
      }

      return settingsMap;
    } catch (e) {
      AppLogger.error('Error during settings migration', e);
      // Return original settings with default generation settings
      settingsMap['generationSettings'] = _getDefaultGenerationSettings();
      return settingsMap;
    }
  }

  /// Ensure generation settings have all required fields with defaults
  Map<String, dynamic> _ensureGenerationSettingsDefaults(Map<String, dynamic> generationSettings) {
    final defaults = _getDefaultGenerationSettings();
    
    // Merge with defaults, keeping existing values where valid
    final result = Map<String, dynamic>.from(defaults);
    
    for (final entry in generationSettings.entries) {
      if (defaults.containsKey(entry.key)) {
        // Validate the value type and range
        final validatedValue = _validateGenerationSettingValue(entry.key, entry.value);
        if (validatedValue != null) {
          result[entry.key] = validatedValue;
        }
      }
    }
    
    return result;
  }

  /// Get default generation settings as Map
  Map<String, dynamic> _getDefaultGenerationSettings() {
    return {
      'temperature': 0.7,
      'topP': 0.9,
      'topK': 40,
      'repeatPenalty': 1.1,
      'maxTokens': -1,
      'numThread': 4,
    };
  }

  /// Validate individual generation setting values
  dynamic _validateGenerationSettingValue(String key, dynamic value) {
    try {
      switch (key) {
        case 'temperature':
          if (value is num) {
            final temp = value.toDouble();
            return temp >= 0.0 && temp <= 2.0 ? temp : 0.7;
          }
          break;
        case 'topP':
          if (value is num) {
            final topP = value.toDouble();
            return topP >= 0.0 && topP <= 1.0 ? topP : 0.9;
          }
          break;
        case 'topK':
          if (value is num) {
            final topK = value.toInt();
            return topK >= 1 && topK <= 100 ? topK : 40;
          }
          break;
        case 'repeatPenalty':
          if (value is num) {
            final penalty = value.toDouble();
            return penalty >= 0.5 && penalty <= 2.0 ? penalty : 1.1;
          }
          break;
        case 'maxTokens':
          if (value is num) {
            final tokens = value.toInt();
            return tokens >= -1 && tokens <= 4096 ? tokens : -1;
          }
          break;
        case 'numThread':
          if (value is num) {
            final threads = value.toInt();
            return threads >= 1 && threads <= 16 ? threads : 4;
          }
          break;
      }
    } catch (e) {
      AppLogger.error('Error validating generation setting $key', e);
    }
    return null; // Invalid value, will use default
  }

  /// Reset corrupted settings and backup the corrupted data
  Future<void> _resetCorruptedSettings() async {
    try {
      // Backup corrupted settings for debugging
      final corruptedData = _preferences.getString(_settingsKey);
      if (corruptedData != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await _preferences.setString('${_settingsKey}_corrupted_$timestamp', corruptedData);
        AppLogger.info('Backed up corrupted settings data');
      }

      // Remove corrupted settings
      await _preferences.remove(_settingsKey);
      AppLogger.info('Removed corrupted settings, will use defaults');
    } catch (e) {
      AppLogger.error('Error resetting corrupted settings', e);
    }
  }

  /// Validate settings data integrity
  Future<bool> validateSettingsIntegrity() async {
    try {
      final settingsJson = _preferences.getString(_settingsKey);
      if (settingsJson == null) return true; // No settings is valid

      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      
      // Try to create AppSettings from the data
      AppSettings.fromJson(settingsMap);
      
      return true;
    } catch (e) {
      AppLogger.error('Settings integrity validation failed', e);
      return false;
    }
  }

  /// Get settings migration status
  Map<String, dynamic> getSettingsMigrationStatus() {
    try {
      final settingsJson = _preferences.getString(_settingsKey);
      if (settingsJson == null) {
        return {
          'hasSavedSettings': false,
          'needsMigration': false,
          'hasGenerationSettings': false,
        };
      }

      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      final hasGenerationSettings = settingsMap.containsKey('generationSettings');
      
      return {
        'hasSavedSettings': true,
        'needsMigration': !hasGenerationSettings,
        'hasGenerationSettings': hasGenerationSettings,
        'settingsKeys': settingsMap.keys.toList(),
      };
    } catch (e) {
      AppLogger.error('Error getting migration status', e);
      return {
        'hasSavedSettings': false,
        'needsMigration': true,
        'hasGenerationSettings': false,
        'error': e.toString(),
      };
    }
  }
}
