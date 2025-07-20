import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/storage_service.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/generation_settings.dart';

void main() {
  group('StorageService Generation Settings Tests', () {
    late StorageService storageService;

    setUp(() async {
      // Initialize SharedPreferences with empty values
      SharedPreferences.setMockInitialValues({});
      await StorageService.initialize();
      storageService = StorageService();
    });

    test('should load default settings when no saved settings exist', () async {
      final settings = await storageService.loadSettings();
      
      expect(settings.generationSettings.temperature, 0.7);
      expect(settings.generationSettings.topP, 0.9);
      expect(settings.generationSettings.topK, 40);
      expect(settings.generationSettings.repeatPenalty, 1.1);
      expect(settings.generationSettings.maxTokens, -1);
      expect(settings.generationSettings.numThread, 4);
    });

    test('should save and load generation settings correctly', () async {
      final customGenerationSettings = GenerationSettings(
        temperature: 0.8,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.2,
        maxTokens: 2048,
        numThread: 8,
      );

      final settings = AppSettings(
        generationSettings: customGenerationSettings,
      );

      await storageService.saveSettings(settings);
      final loadedSettings = await storageService.loadSettings();

      expect(loadedSettings.generationSettings.temperature, 0.8);
      expect(loadedSettings.generationSettings.topP, 0.95);
      expect(loadedSettings.generationSettings.topK, 50);
      expect(loadedSettings.generationSettings.repeatPenalty, 1.2);
      expect(loadedSettings.generationSettings.maxTokens, 2048);
      expect(loadedSettings.generationSettings.numThread, 8);
    });

    test('should handle migration from old settings format', () async {
      // Simulate old settings without generationSettings
      final oldSettingsJson = '''
      {
        "ollamaHost": "127.0.0.1",
        "ollamaPort": 11434,
        "fontSize": 16.0,
        "showLiveResponse": false,
        "contextLength": 4096,
        "systemPrompt": "",
        "darkMode": false,
        "thinkingBubbleDefaultExpanded": true,
        "thinkingBubbleAutoCollapse": false
      }
      ''';

      // Manually set the old format in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_settings', oldSettingsJson);

      final settings = await storageService.loadSettings();

      // Should have default generation settings after migration
      expect(settings.generationSettings.temperature, 0.7);
      expect(settings.generationSettings.topP, 0.9);
      expect(settings.generationSettings.topK, 40);
    });

    test('should validate settings integrity', () async {
      final settings = AppSettings();
      await storageService.saveSettings(settings);
      
      final isValid = await storageService.validateSettingsIntegrity();
      expect(isValid, true);
    });

    test('should get migration status correctly', () async {
      final status = storageService.getSettingsMigrationStatus();
      
      expect(status['hasSavedSettings'], false);
      expect(status['needsMigration'], false);
      expect(status['hasGenerationSettings'], false);
    });
  });
}