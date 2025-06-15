import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/ollama_service.dart';
import '../utils/logger.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  String? _authToken;
  bool _disposed = false;

  SettingsProvider() {
    _loadSettings();
  }

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get authToken => _authToken;

  @override
  void dispose() {
    _disposed = true;
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
    _authToken = await _storageService.getAuthToken();

    // Log the loaded settings for debugging
    AppLogger.info('Settings loaded - Ollama URL: ${_settings.ollamaUrl}');
    AppLogger.debug('Auth token ${_authToken != null ? 'present' : 'not set'}');

    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> updateSettings({
    String? ollamaHost,
    int? ollamaPort,
    String? authToken,
    double? fontSize,
    bool? showLiveResponse,
    int? contextLength,
    String? systemPrompt,
    bool? thinkingBubbleDefaultExpanded,
    bool? thinkingBubbleAutoCollapse,
    bool? darkMode,
  }) async {
    _settings = _settings.copyWith(
      ollamaHost: ollamaHost,
      ollamaPort: ollamaPort,
      fontSize: fontSize,
      showLiveResponse: showLiveResponse,
      contextLength: contextLength,
      systemPrompt: systemPrompt,
      thinkingBubbleDefaultExpanded: thinkingBubbleDefaultExpanded,
      thinkingBubbleAutoCollapse: thinkingBubbleAutoCollapse,
      darkMode: darkMode,
    );

    if (authToken != null) {
      _authToken = authToken;
      await _storageService.saveAuthToken(authToken);
    }

    // Save settings and notify listeners
    await _storageService.saveSettings(_settings);
    _safeNotifyListeners();
  }

  // Get a configured OllamaService instance based on current settings
  OllamaService getOllamaService() {
    // Log the current settings being used for debugging
    final ollamaUrl = _settings.ollamaUrl;
    AppLogger.debug('Creating OllamaService with URL: $ollamaUrl');

    return OllamaService(
      settings: _settings,
      authToken: _authToken,
    );
  }

  // === LAST SELECTED MODEL METHODS ===

  /// Load the last selected model from storage
  Future<String> getLastSelectedModel() async {
    return await _storageService.loadLastSelectedModel();
  }

  /// Save the last selected model to storage
  Future<void> setLastSelectedModel(String modelName) async {
    await _storageService.saveLastSelectedModel(modelName);
  }
}
