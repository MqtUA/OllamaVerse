import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class SettingsService {
  static const String _lastSelectedModelKey = 'last_selected_model';
  static const String _systemPromptKey = 'system_prompt';
  static const String _maxTokensKey = 'max_tokens';
  static const String _temperatureKey = 'temperature';
  static const String _topPKey = 'top_p';
  static const String _topKKey = 'top_k';

  final SharedPreferences _prefs;
  String _selectedModel = '';
  String _systemPrompt = '';
  int _maxTokens = 2048;
  double _temperature = 0.7;
  double _topP = 0.9;
  int _topK = 40;

  SettingsService(this._prefs) {
    _loadSettings();
  }

  String get selectedModel => _selectedModel;
  String get systemPrompt => _systemPrompt;
  int get maxTokens => _maxTokens;
  double get temperature => _temperature;
  double get topP => _topP;
  int get topK => _topK;

  void _loadSettings() {
    try {
      _selectedModel = _prefs.getString(_lastSelectedModelKey) ?? '';
      _systemPrompt = _prefs.getString(_systemPromptKey) ?? '';
      _maxTokens = _prefs.getInt(_maxTokensKey) ?? 2048;
      _temperature = _prefs.getDouble(_temperatureKey) ?? 0.7;
      _topP = _prefs.getDouble(_topPKey) ?? 0.9;
      _topK = _prefs.getInt(_topKKey) ?? 40;
    } catch (e) {
      AppLogger.error('Error loading settings', e);
    }
  }

  Future<void> setSelectedModel(String model) async {
    try {
      _selectedModel = model;
      await _prefs.setString(_lastSelectedModelKey, model);
    } catch (e) {
      AppLogger.error('Error saving selected model', e);
      rethrow;
    }
  }

  Future<void> setLastSelectedModel(String model) async {
    await setSelectedModel(model);
  }

  Future<String?> getLastSelectedModel() async {
    try {
      return _prefs.getString(_lastSelectedModelKey);
    } catch (e) {
      AppLogger.error('Error getting last selected model', e);
      return null;
    }
  }

  Future<void> setSystemPrompt(String prompt) async {
    try {
      _systemPrompt = prompt;
      await _prefs.setString(_systemPromptKey, prompt);
    } catch (e) {
      AppLogger.error('Error saving system prompt', e);
      rethrow;
    }
  }

  Future<void> setMaxTokens(int tokens) async {
    try {
      _maxTokens = tokens;
      await _prefs.setInt(_maxTokensKey, tokens);
    } catch (e) {
      AppLogger.error('Error saving max tokens', e);
      rethrow;
    }
  }

  Future<void> setTemperature(double temp) async {
    try {
      _temperature = temp;
      await _prefs.setDouble(_temperatureKey, temp);
    } catch (e) {
      AppLogger.error('Error saving temperature', e);
      rethrow;
    }
  }

  Future<void> setTopP(double value) async {
    try {
      _topP = value;
      await _prefs.setDouble(_topPKey, value);
    } catch (e) {
      AppLogger.error('Error saving top p', e);
      rethrow;
    }
  }

  Future<void> setTopK(int value) async {
    try {
      _topK = value;
      await _prefs.setInt(_topKKey, value);
    } catch (e) {
      AppLogger.error('Error saving top k', e);
      rethrow;
    }
  }

  Future<void> clearSettings() async {
    try {
      await _prefs.clear();
      _loadSettings();
    } catch (e) {
      AppLogger.error('Error clearing settings', e);
      rethrow;
    }
  }
}
