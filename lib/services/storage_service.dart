import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../utils/logger.dart';

class StorageService {
  // Constants
  static const String settingsKey = 'app_settings';
  static const String lastSelectedModelKey = 'last_selected_model';

  // Save app settings
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  // Load app settings
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(settingsKey);

    if (settingsJson != null) {
      try {
        return AppSettings.fromJson(jsonDecode(settingsJson));
      } catch (e) {
        AppLogger.error('Error loading settings', e);
        return AppSettings();
      }
    }

    return AppSettings(); // Return default settings
  }

  // Save last selected model
  Future<void> saveLastSelectedModel(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastSelectedModelKey, modelName);
  }

  // Load last selected model
  Future<String> loadLastSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastSelectedModelKey) ?? '';
  }
}
