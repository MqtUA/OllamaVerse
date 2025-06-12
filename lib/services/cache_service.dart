import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// A service for caching frequently accessed data
class CacheService {
  static const String _prefix = 'cache_';
  static SharedPreferences? _prefs;
  static final List<StreamSubscription> _subscriptions = [];
  static bool _isInitialized = false;

  /// Initialize the cache service
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      AppLogger.info('Cache service initialized');
    } catch (e) {
      AppLogger.error('Error initializing cache service', e);
      rethrow;
    }
  }

  /// Clean up resources when the app is closed
  static Future<void> dispose() async {
    try {
      // Cancel all active subscriptions
      for (var subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      // Clear any temporary data
      await clear();

      _isInitialized = false;
      AppLogger.info('Cache service disposed');
    } catch (e) {
      AppLogger.error('Error disposing cache service', e);
    }
  }

  /// Get a value from the cache
  static Future<T?> get<T>(String key) async {
    if (!_isInitialized) {
      throw Exception('CacheService not initialized');
    }

    try {
      final value = _prefs?.getString('$_prefix$key');
      if (value == null) return null;

      return value as T;
    } catch (e) {
      AppLogger.error('Error getting value from cache', e);
      return null;
    }
  }

  /// Set a value in the cache
  static Future<void> set<T>(String key, T value) async {
    if (!_isInitialized) {
      throw Exception('CacheService not initialized');
    }

    try {
      await _prefs?.setString('$_prefix$key', value.toString());
    } catch (e) {
      AppLogger.error('Error setting value in cache', e);
    }
  }

  /// Remove a value from the cache
  static Future<void> remove(String key) async {
    if (!_isInitialized) {
      throw Exception('CacheService not initialized');
    }

    try {
      await _prefs?.remove('$_prefix$key');
    } catch (e) {
      AppLogger.error('Error removing value from cache', e);
    }
  }

  /// Clear all cached data
  static Future<void> clear() async {
    if (!_isInitialized) {
      throw Exception('CacheService not initialized');
    }

    try {
      final keys = _prefs?.getKeys() ?? {};
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          await _prefs?.remove(key);
        }
      }
    } catch (e) {
      AppLogger.error('Error clearing cache', e);
    }
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      if (_prefs == null) await init();
      int size = 0;
      final keys = _prefs!.getKeys().where((key) => key.startsWith(_prefix));
      for (final key in keys) {
        final value = _prefs!.get(key);
        if (value is String) {
          size += value.length;
        } else if (value is List) {
          size += value.length;
        }
      }
      return size;
    } catch (e) {
      AppLogger.error('Error getting cache size', e);
      return 0;
    }
  }

  /// Add a subscription to be cleaned up on dispose
  static void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }
}
