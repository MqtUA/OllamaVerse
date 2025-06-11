import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// A service for caching frequently accessed data
class CacheService {
  static SharedPreferences? _prefs;
  static const String _prefix = 'cache_';
  static const String _expiryPrefix = 'expiry_';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get cached data
  Future<T?> get<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (_prefs == null) await init();

    final expiryKey = _expiryPrefix + key;
    final expiryTime = _prefs!.getInt(expiryKey);

    if (expiryTime != null &&
        DateTime.now().millisecondsSinceEpoch > expiryTime) {
      await remove(key);
      return null;
    }

    final data = _prefs!.getString(_prefix + key);
    if (data == null) return null;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      AppLogger.error('Error getting cached data', e);
      return null;
    }
  }

  /// Set data in cache
  Future<void> set<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson, {
    Duration? expiration,
  }) async {
    if (_prefs == null) await init();

    final json = toJson(data);
    await _prefs!.setString(_prefix + key, jsonEncode(json));

    if (expiration != null) {
      final expiryTime = DateTime.now().add(expiration).millisecondsSinceEpoch;
      await _prefs!.setInt(_expiryPrefix + key, expiryTime);
    }
  }

  /// Remove data from cache
  Future<void> remove(String key) async {
    if (_prefs == null) await init();

    await _prefs!.remove(_prefix + key);
    await _prefs!.remove(_expiryPrefix + key);
  }

  /// Clear all cached data
  Future<void> clear() async {
    if (_prefs == null) await init();

    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_prefix) || key.startsWith(_expiryPrefix)) {
        await _prefs!.remove(key);
      }
    }
  }
}
