import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/secure_storage_service.dart';
import '../services/ollama_service.dart';
import '../services/performance_monitor.dart';
import '../theme/material_light_theme.dart';
import '../theme/dracula_theme.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  final StorageService _storageService = StorageService();
  final SecureStorageService _secureStorageService = SecureStorageService();
  bool _isLoading = true;
  String? _authToken;
  bool _disposed = false;

  // Theme caching for performance
  ThemeData? _cachedLightTheme;
  ThemeData? _cachedDarkTheme;
  ThemeMode? _cachedThemeMode;

  // Debouncing for theme changes
  Timer? _themeUpdateTimer;

  SettingsProvider() {
    _loadSettings();
  }

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get authToken => _authToken;

  @override
  void dispose() {
    _disposed = true;
    _themeUpdateTimer?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    _isLoading = true;
    _safeNotifyListeners();

    _settings = await _storageService.loadSettings();
    _authToken = await _secureStorageService.getAuthToken();

    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> updateSettings({
    String? ollamaHost,
    int? ollamaPort,
    String? authToken,
    double? fontSize,
    bool? darkMode,
    bool? showLiveResponse,
    int? contextLength,
    String? systemPrompt,
  }) async {
    final previousDarkMode = _settings.darkMode;

    _settings = _settings.copyWith(
      ollamaHost: ollamaHost,
      ollamaPort: ollamaPort,
      fontSize: fontSize,
      darkMode: darkMode,
      showLiveResponse: showLiveResponse,
      contextLength: contextLength,
      systemPrompt: systemPrompt,
    );

    if (authToken != null) {
      _authToken = authToken;
      await _secureStorageService.saveAuthToken(authToken);
    }

    // Clear theme cache if dark mode changed
    if (darkMode != null && darkMode != previousDarkMode) {
      // Performance monitoring: mark theme change start
      PerformanceMonitor.instance.markThemeChangeStart();

      _cachedThemeMode = null;
      _debouncedThemeUpdate();
    }

    await _storageService.saveSettings(_settings);
    _safeNotifyListeners();
  }

  // Debounced theme update to prevent excessive rebuilds
  void _debouncedThemeUpdate() {
    _themeUpdateTimer?.cancel();
    _themeUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) {
        _safeNotifyListeners();

        // Performance monitoring: mark theme change end after UI update
        Future.delayed(const Duration(milliseconds: 50), () {
          PerformanceMonitor.instance.markThemeChangeEnd();
        });
      }
    });
  }

  ThemeMode get themeMode {
    return _cachedThemeMode ??=
        _settings.darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Cached theme getters for performance
  ThemeData get lightTheme {
    return _cachedLightTheme ??= materialLightTheme();
  }

  ThemeData get darkTheme {
    return _cachedDarkTheme ??= draculaDarkTheme();
  }

  // Clear theme cache (useful for theme updates)
  void clearThemeCache() {
    _cachedLightTheme = null;
    _cachedDarkTheme = null;
    _cachedThemeMode = null;
  }

  // Get a configured OllamaService instance based on current settings
  OllamaService getOllamaService() {
    return OllamaService(
      settings: _settings,
      authToken: _authToken,
    );
  }
}
