import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/generation_settings.dart';
import '../services/storage_service.dart';
import '../services/ollama_service.dart';
import '../services/model_manager.dart';
import '../services/settings_validation_service.dart';
import '../utils/logger.dart';

class SettingsProvider extends ChangeNotifier implements ISettingsProvider {
  AppSettings _settings = AppSettings();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  String? _authToken;
  bool _disposed = false;

  SettingsProvider() {
    _loadSettings();
  }

  AppSettings get settings => _settings;
  @override
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
    GenerationSettings? generationSettings,
    bool validateSettings = true,
  }) async {
    final oldSettings = _settings;
    
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
      generationSettings: generationSettings,
    );

    // Validate settings if requested
    if (validateSettings) {
      final validation = SettingsValidationService.validateAllSettings(_settings);
      if (!(validation['isValid'] as bool)) {
        final errors = validation['errors'] as List<String>;
        AppLogger.warning('Settings validation failed: ${errors.join(', ')}');
        
        // Auto-fix critical issues
        _settings = SettingsValidationService.autoFixSettings(_settings);
        AppLogger.info('Applied auto-fixes to settings');
      }
      
      // Log migration recommendations
      final recommendations = SettingsValidationService.getMigrationRecommendations(oldSettings, _settings);
      if (recommendations.isNotEmpty) {
        AppLogger.info('Settings migration recommendations: ${recommendations.join(', ')}');
      }
    }

    if (authToken != null) {
      _authToken = authToken;
      await _storageService.saveAuthToken(authToken);
    }

    // Save settings and notify listeners
    await _storageService.saveSettings(_settings);
    _safeNotifyListeners();
  }

  // Get a configured OllamaService instance based on current settings
  @override
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
  @override
  Future<String> getLastSelectedModel() async {
    return await _storageService.loadLastSelectedModel();
  }

  /// Save the last selected model to storage
  @override
  Future<void> setLastSelectedModel(String modelName) async {
    await _storageService.saveLastSelectedModel(modelName);
  }

  /// Refresh settings and notify listeners
  /// This method provides a clean way to trigger UI updates when needed
  void refreshSettings() {
    _safeNotifyListeners();
  }

  /// Get settings validation results
  Map<String, dynamic> validateCurrentSettings() {
    return SettingsValidationService.validateAllSettings(_settings);
  }

  /// Get settings health score (0-100)
  int getSettingsHealthScore() {
    return SettingsValidationService.getSettingsHealthScore(_settings);
  }

  /// Get settings status string
  String getSettingsStatus() {
    return SettingsValidationService.getSettingsStatus(_settings);
  }

  /// Auto-fix settings issues
  Future<void> autoFixSettings() async {
    final oldSettings = _settings;
    _settings = SettingsValidationService.autoFixSettings(_settings);
    
    if (_settings != oldSettings) {
      await _storageService.saveSettings(_settings);
      _safeNotifyListeners();
      AppLogger.info('Settings auto-fixed and saved');
    }
  }

  /// Check if existing chats should be updated with new settings
  bool shouldUpdateExistingChats(AppSettings oldSettings) {
    return SettingsValidationService.shouldUpdateExistingChats(oldSettings, _settings);
  }
}
