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
        AppLogger.debug('Loaded settings from storage');
        return AppSettings.fromJson(settingsMap);
      }
    } catch (e) {
      AppLogger.error('Error loading settings', e);
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
}
