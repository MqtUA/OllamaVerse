import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Simple theme state manager
/// Handles only theme switching with immediate persistence
class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isLoading = true;

  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;

  ThemeNotifier() {
    _loadTheme();
  }

  /// Toggle between light and dark theme
  Future<void> toggleTheme() async {
    developer.log(
        '🎨 Toggling theme: ${_isDarkMode ? 'Dark' : 'Light'} → ${_isDarkMode ? 'Light' : 'Dark'}',
        name: 'ThemeNotifier');

    _isDarkMode = !_isDarkMode;
    notifyListeners(); // Immediate UI update

    await _saveTheme(); // Persist the change

    developer.log('🎨 Theme toggled successfully', name: 'ThemeNotifier');
  }

  /// Set theme directly (useful for initialization)
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return; // No change needed

    developer.log('🎨 Setting theme to: ${isDark ? 'Dark' : 'Light'}',
        name: 'ThemeNotifier');

    _isDarkMode = isDark;
    notifyListeners();

    await _saveTheme();
  }

  /// Load theme preference from storage
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;

      developer.log('🎨 Theme loaded: ${_isDarkMode ? 'Dark' : 'Light'}',
          name: 'ThemeNotifier');
    } catch (e) {
      developer.log('🎨 Error loading theme, using default light theme: $e',
          name: 'ThemeNotifier');
      _isDarkMode = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save theme preference to storage
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);

      developer.log('🎨 Theme saved: ${_isDarkMode ? 'Dark' : 'Light'}',
          name: 'ThemeNotifier');
    } catch (e) {
      developer.log('🎨 Error saving theme: $e', name: 'ThemeNotifier');
    }
  }
}
