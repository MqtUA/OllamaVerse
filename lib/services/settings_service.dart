import '../services/storage_service.dart';
import '../utils/logger.dart';

/// Legacy SettingsService - now delegates to StorageService for consistency
/// This maintains backward compatibility while using the unified storage approach
@Deprecated('Use StorageService directly for new code')
class SettingsService {
  final StorageService _storageService = StorageService();

  // Legacy keys for backward compatibility
  static const String _lastSelectedModelKey = 'last_selected_model';
  static const String _systemPromptKey = 'system_prompt';
  static const String _maxTokensKey = 'max_tokens';
  static const String _temperatureKey = 'temperature';
  static const String _topPKey = 'top_p';
  static const String _topKKey = 'top_k';

  String get selectedModel => _storageService.getString(_lastSelectedModelKey) ?? '';
  String get systemPrompt => _storageService.getString(_systemPromptKey) ?? '';
  int get maxTokens => _storageService.getInt(_maxTokensKey, defaultValue: 2048);
  double get temperature => _storageService.getDouble(_temperatureKey) ?? 0.7;
  double get topP => _storageService.getDouble(_topPKey) ?? 0.9;
  int get topK => _storageService.getInt(_topKKey, defaultValue: 40);

  Future<void> setSelectedModel(String model) async {
    await _storageService.setString(_lastSelectedModelKey, model);
  }

  Future<void> setLastSelectedModel(String model) async {
    await setSelectedModel(model);
  }

  Future<String?> getLastSelectedModel() async {
    return _storageService.getString(_lastSelectedModelKey);
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _storageService.setString(_systemPromptKey, prompt);
  }

  Future<void> setMaxTokens(int tokens) async {
    await _storageService.setInt(_maxTokensKey, tokens);
  }

  Future<void> setTemperature(double temp) async {
    await _storageService.setDouble(_temperatureKey, temp);
  }

  Future<void> setTopP(double value) async {
    await _storageService.setDouble(_topPKey, value);
  }

  Future<void> setTopK(int value) async {
    await _storageService.setInt(_topKKey, value);
  }

  Future<void> clearSettings() async {
    await _storageService.clear();
  }
}
