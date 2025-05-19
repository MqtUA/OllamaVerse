import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/ollama_service.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;

  SettingsProvider() {
    _loadSettings();
  }

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();
    
    _settings = await _storageService.loadSettings();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSettings({
    String? ollamaHost,
    int? ollamaPort,
    String? authToken,
    double? fontSize,
    bool? darkMode,
    bool? showLiveResponse,
    int? contextLength,
  }) async {
    _settings = _settings.copyWith(
      ollamaHost: ollamaHost,
      ollamaPort: ollamaPort,
      authToken: authToken,
      fontSize: fontSize,
      darkMode: darkMode,
      showLiveResponse: showLiveResponse,
      contextLength: contextLength,
    );
    
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  ThemeMode get themeMode => _settings.darkMode ? ThemeMode.dark : ThemeMode.light;
  
  // Get an instance of OllamaService with current settings
  OllamaService getOllamaService() {
    return OllamaService(settings: _settings);
  }
}
