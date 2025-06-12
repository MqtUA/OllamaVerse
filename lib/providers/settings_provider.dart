import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/secure_storage_service.dart';
import '../services/ollama_service.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  final StorageService _storageService = StorageService();
  final SecureStorageService _secureStorageService = SecureStorageService();
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
    _authToken = await _secureStorageService.getAuthToken();

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
  }) async {
    _settings = _settings.copyWith(
      ollamaHost: ollamaHost,
      ollamaPort: ollamaPort,
      fontSize: fontSize,
      showLiveResponse: showLiveResponse,
      contextLength: contextLength,
      systemPrompt: systemPrompt,
    );

    if (authToken != null) {
      _authToken = authToken;
      await _secureStorageService.saveAuthToken(authToken);
    }

    // Save settings and notify listeners
    await _storageService.saveSettings(_settings);
    _safeNotifyListeners();
  }

  // Get a configured OllamaService instance based on current settings
  OllamaService getOllamaService() {
    return OllamaService(
      settings: _settings,
      authToken: _authToken,
    );
  }
}
