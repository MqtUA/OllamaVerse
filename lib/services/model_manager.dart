import 'dart:async';
import '../providers/settings_provider.dart';
import '../services/ollama_service.dart';
import '../utils/logger.dart';

/// Interface for settings provider to allow for testing
abstract class ISettingsProvider {
  bool get isLoading;
  OllamaService getOllamaService();
  Future<String> getLastSelectedModel();
  Future<void> setLastSelectedModel(String modelName);
}

/// Service responsible for managing AI models including loading, selection, and persistence
class ModelManager {
  final ISettingsProvider _settingsProvider;
  
  List<String> _availableModels = [];
  String _lastSelectedModel = '';
  bool _isLoading = false;
  String? _lastError;
  
  // Connection retry configuration
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _settingsTimeout = Duration(seconds: 10);

  ModelManager({required ISettingsProvider settingsProvider})
      : _settingsProvider = settingsProvider;

  /// Get the list of available models
  List<String> get availableModels => List.unmodifiable(_availableModels);

  /// Get the last selected model
  String get lastSelectedModel => _lastSelectedModel;

  /// Check if models are currently being loaded
  bool get isLoading => _isLoading;

  /// Get the last error that occurred during model operations
  String? get lastError => _lastError;

  /// Check if any models are available
  bool get hasModels => _availableModels.isNotEmpty;

  /// Initialize the ModelManager by loading persisted model selection
  Future<void> initialize() async {
    try {
      await _loadLastSelectedModel();
      AppLogger.info('ModelManager initialized with last selected model: $_lastSelectedModel');
    } catch (e) {
      AppLogger.error('Error initializing ModelManager', e);
      _lastError = 'Failed to initialize: ${e.toString()}';
    }
  }

  /// Load available models from Ollama service with retry mechanism
  Future<bool> loadModels() async {
    if (_isLoading) {
      AppLogger.warning('Model loading already in progress');
      return false;
    }

    _isLoading = true;
    _lastError = null;

    try {
      // Wait for settings to be ready before loading models
      await _waitForSettings();

      final ollamaService = _settingsProvider.getOllamaService();
      
      // Attempt to load models with retry mechanism
      for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
        try {
          _availableModels = await ollamaService.getModels();
          AppLogger.info('Successfully loaded ${_availableModels.length} models on attempt $attempt');
          _isLoading = false;
          return true;
        } on OllamaConnectionException catch (e) {
          AppLogger.warning('Connection error on attempt $attempt: ${e.message}');
          _lastError = 'Cannot connect to Ollama server. Please check your connection settings.';
          
          if (attempt < _maxRetryAttempts) {
            AppLogger.info('Retrying in ${_retryDelay.inSeconds} seconds...');
            await Future.delayed(_retryDelay);
          }
        } on OllamaApiException catch (e) {
          AppLogger.error('API error loading models on attempt $attempt', e);
          _lastError = 'Error communicating with Ollama: ${e.message}';
          
          if (attempt < _maxRetryAttempts) {
            await Future.delayed(_retryDelay);
          }
        }
      }

      // All retry attempts failed
      _availableModels = [];
      _isLoading = false;
      return false;

    } catch (e) {
      _lastError = 'Unexpected error loading models: ${e.toString()}';
      AppLogger.error('Unexpected error loading models', e);
      _availableModels = [];
      _isLoading = false;
      return false;
    }
  }

  /// Test connection to Ollama service
  Future<bool> testConnection() async {
    try {
      await _waitForSettings();
      final ollamaService = _settingsProvider.getOllamaService();
      final isConnected = await ollamaService.testConnection();
      
      if (!isConnected) {
        _lastError = 'Failed to connect to Ollama server';
      } else {
        _lastError = null;
      }
      
      return isConnected;
    } catch (e) {
      _lastError = 'Connection test failed: ${e.toString()}';
      AppLogger.error('Error testing connection', e);
      return false;
    }
  }

  /// Refresh models by reloading from Ollama service
  Future<bool> refreshModels() async {
    AppLogger.info('Refreshing models...');
    return await loadModels();
  }

  /// Set the selected model and persist it
  Future<void> setSelectedModel(String modelName) async {
    if (modelName.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }

    try {
      _lastSelectedModel = modelName;
      await _settingsProvider.setLastSelectedModel(modelName);
      AppLogger.info('Selected model set to: $modelName');
    } catch (e) {
      AppLogger.error('Error setting selected model', e);
      throw Exception('Failed to save selected model: ${e.toString()}');
    }
  }

  /// Get the best model to use based on availability and last selection
  String getBestAvailableModel() {
    if (_availableModels.isEmpty) {
      return 'unknown';
    }

    // Use last selected model if it's still available
    if (_lastSelectedModel.isNotEmpty && _availableModels.contains(_lastSelectedModel)) {
      return _lastSelectedModel;
    }

    // Otherwise use the first available model
    return _availableModels.first;
  }

  /// Check if a specific model is available
  bool isModelAvailable(String modelName) {
    return _availableModels.contains(modelName);
  }

  /// Get model selection for new chat creation
  String getModelForNewChat([String? preferredModel]) {
    if (preferredModel != null && isModelAvailable(preferredModel)) {
      return preferredModel;
    }
    
    return getBestAvailableModel();
  }

  /// Load the last selected model from persistent storage
  Future<void> _loadLastSelectedModel() async {
    try {
      final lastModel = await _settingsProvider.getLastSelectedModel();
      if (lastModel.isNotEmpty) {
        _lastSelectedModel = lastModel;
      }
    } catch (e) {
      AppLogger.error('Error loading last selected model', e);
      // Don't throw - this is not critical for app functionality
    }
  }

  /// Wait for settings to be ready with timeout
  Future<void> _waitForSettings() async {
    final stopwatch = Stopwatch()..start();
    
    while (_settingsProvider.isLoading && stopwatch.elapsed < _settingsTimeout) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_settingsProvider.isLoading) {
      AppLogger.warning('Settings still loading after ${_settingsTimeout.inSeconds}s timeout');
      throw TimeoutException('Settings loading timeout', _settingsTimeout);
    }
  }

  /// Clear any cached error state
  void clearError() {
    _lastError = null;
  }

  /// Get connection status information
  Map<String, dynamic> getConnectionStatus() {
    return {
      'hasModels': hasModels,
      'modelCount': _availableModels.length,
      'isLoading': _isLoading,
      'lastError': _lastError,
      'lastSelectedModel': _lastSelectedModel,
      'availableModels': availableModels,
    };
  }
}