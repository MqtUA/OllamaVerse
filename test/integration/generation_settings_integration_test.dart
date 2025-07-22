import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/chat.dart';
import '../../lib/services/generation_settings_service.dart';
import '../../lib/services/storage_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Integration tests for generation settings end-to-end functionality
/// 
/// Requirements covered:
/// - Complete settings flow from UI to API
/// - Per-chat settings override behavior  
/// - Migration and backward compatibility
/// - Settings persistence and retrieval
/// - API integration with custom settings
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Generation Settings Integration Tests', () {
    late StorageService storageService;

    setUp(() async {
      // Initialize SharedPreferences with empty values for each test
      SharedPreferences.setMockInitialValues({});
      await StorageService.initialize();
      storageService = StorageService();
    });

    group('Settings Persistence Flow', () {
      test('should persist and retrieve global generation settings', () async {
        // Create custom generation settings
        final customSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        // Create app settings with custom generation settings
        final appSettings = AppSettings(
          generationSettings: customSettings,
          ollamaHost: '192.168.1.100',
          ollamaPort: 8080,
        );

        // Save settings
        await storageService.saveSettings(appSettings);

        // Load settings back
        final loadedSettings = await storageService.loadSettings();

        // Verify all generation settings were persisted correctly
        expect(loadedSettings.generationSettings.temperature, 0.8);
        expect(loadedSettings.generationSettings.topP, 0.95);
        expect(loadedSettings.generationSettings.topK, 50);
        expect(loadedSettings.generationSettings.repeatPenalty, 1.2);
        expect(loadedSettings.generationSettings.maxTokens, 2048);
        expect(loadedSettings.generationSettings.numThread, 8);

        // Verify other settings were also preserved
        expect(loadedSettings.ollamaHost, '192.168.1.100');
        expect(loadedSettings.ollamaPort, 8080);
      });

      test('should handle migration from old settings format', () async {
        // Simulate old settings format without generationSettings
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

        // Load settings - should migrate to new format with default generation settings
        final migratedSettings = await storageService.loadSettings();

        // Verify migration applied default generation settings
        expect(migratedSettings.generationSettings.temperature, 0.7);
        expect(migratedSettings.generationSettings.topP, 0.9);
        expect(migratedSettings.generationSettings.topK, 40);
        expect(migratedSettings.generationSettings.repeatPenalty, 1.1);
        expect(migratedSettings.generationSettings.maxTokens, -1);
        expect(migratedSettings.generationSettings.numThread, 4);

        // Verify old settings were preserved
        expect(migratedSettings.ollamaHost, '127.0.0.1');
        expect(migratedSettings.ollamaPort, 11434);
        expect(migratedSettings.fontSize, 16.0);
      });
    });

    group('Per-Chat Settings JSON Serialization', () {
      test('should serialize and deserialize per-chat generation settings', () async {
        final testDateTime = DateTime.now();
        final customSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 6,
        );

        // Create chat with custom generation settings
        final chat = Chat(
          id: 'test-chat-custom',
          title: 'Test Chat with Custom Settings',
          modelName: 'llama2',
          messages: [],
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          customGenerationSettings: customSettings,
        );

        // Serialize to JSON
        final json = chat.toJson();

        // Deserialize from JSON
        final restoredChat = Chat.fromJson(json);

        // Verify custom generation settings were preserved
        expect(restoredChat.hasCustomGenerationSettings, true);
        expect(restoredChat.customGenerationSettings!.temperature, 0.8);
        expect(restoredChat.customGenerationSettings!.topP, 0.95);
        expect(restoredChat.customGenerationSettings!.topK, 50);
        expect(restoredChat.customGenerationSettings!.repeatPenalty, 1.2);
        expect(restoredChat.customGenerationSettings!.maxTokens, 1000);
        expect(restoredChat.customGenerationSettings!.numThread, 6);
      });

      test('should handle chat without custom settings in JSON', () async {
        final testDateTime = DateTime.now();

        // Create chat without custom generation settings
        final chat = Chat(
          id: 'test-chat-no-custom',
          title: 'Test Chat without Custom Settings',
          modelName: 'llama2',
          messages: [],
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        // Serialize to JSON
        final json = chat.toJson();

        // Deserialize from JSON
        final restoredChat = Chat.fromJson(json);

        // Verify no custom generation settings
        expect(restoredChat.hasCustomGenerationSettings, false);
        expect(restoredChat.customGenerationSettings, isNull);
      });
    });

    group('Settings Resolution Logic', () {
      test('should resolve effective settings correctly', () async {
        final globalSettings = AppSettings(
          generationSettings: const GenerationSettings(
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            repeatPenalty: 1.1,
            maxTokens: -1,
            numThread: 4,
          ),
        );

        final customSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        final testDateTime = DateTime.now();

        // Test chat without custom settings
        final chatWithoutCustom = Chat(
          id: 'chat-no-custom',
          title: 'Chat without custom',
          modelName: 'llama2',
          messages: [],
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        // Test chat with custom settings
        final chatWithCustom = Chat(
          id: 'chat-with-custom',
          title: 'Chat with custom',
          modelName: 'llama2',
          messages: [],
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          customGenerationSettings: customSettings,
        );

        // Test resolution for chat without custom settings
        final effectiveSettingsNoCustom = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithoutCustom,
          globalSettings: globalSettings,
        );

        expect(effectiveSettingsNoCustom, equals(globalSettings.generationSettings));
        expect(effectiveSettingsNoCustom.temperature, 0.7);

        // Test resolution for chat with custom settings
        final effectiveSettingsWithCustom = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithCustom,
          globalSettings: globalSettings,
        );

        expect(effectiveSettingsWithCustom, equals(customSettings));
        expect(effectiveSettingsWithCustom.temperature, 0.8);

        // Test resolution for null chat
        final effectiveSettingsNullChat = GenerationSettingsService.getEffectiveSettings(
          chat: null,
          globalSettings: globalSettings,
        );

        expect(effectiveSettingsNullChat, equals(globalSettings.generationSettings));
      });
    });

    group('API Options Building', () {
      test('should build correct Ollama API options', () async {
        final defaultSettings = GenerationSettings.defaults();
        final customSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        // Test with default settings - should return empty options
        final defaultOptions = GenerationSettingsService.buildOllamaOptions(
          settings: defaultSettings,
        );
        expect(defaultOptions, isEmpty);

        // Test with custom settings - should include only non-default values
        final customOptions = GenerationSettingsService.buildOllamaOptions(
          settings: customSettings,
        );

        expect(customOptions['temperature'], 0.8);
        expect(customOptions['top_p'], 0.95);
        expect(customOptions['top_k'], 50);
        expect(customOptions['repeat_penalty'], 1.2);
        expect(customOptions['num_predict'], 2048);
        expect(customOptions['num_thread'], 8);

        // Test with context length
        final optionsWithContext = GenerationSettingsService.buildOllamaOptions(
          settings: customSettings,
          contextLength: 8192,
        );

        expect(optionsWithContext['num_ctx'], 8192);
        expect(optionsWithContext['temperature'], 0.8);

        // Test with unlimited tokens
        final unlimitedTokenSettings = customSettings.copyWith(maxTokens: -1);
        final unlimitedOptions = GenerationSettingsService.buildOllamaOptions(
          settings: unlimitedTokenSettings,
        );

        expect(unlimitedOptions.containsKey('num_predict'), false);
        expect(unlimitedOptions['temperature'], 0.8);
      });
    });

    group('Settings Validation Integration', () {
      test('should validate settings end-to-end', () async {
        // Test valid settings
        final validSettings = GenerationSettings.defaults();
        expect(GenerationSettingsService.validateSettings(validSettings), true);
        expect(GenerationSettingsService.getValidationErrors(validSettings), isEmpty);

        // Test invalid settings
        const invalidSettings = GenerationSettings(
          temperature: 3.0, // Invalid
          topP: 1.5, // Invalid
          topK: 0, // Invalid
          repeatPenalty: 0.1, // Invalid
          maxTokens: 5000, // Invalid
          numThread: 20, // Invalid
        );

        expect(GenerationSettingsService.validateSettings(invalidSettings), false);
        final errors = GenerationSettingsService.getValidationErrors(invalidSettings);
        expect(errors.length, 6); // All fields are invalid

        // Test safe settings creation
        final safeSettings = GenerationSettingsService.createSafeSettings(invalidSettings);
        expect(GenerationSettingsService.validateSettings(safeSettings), true);
        expect(safeSettings.temperature, 2.0); // Clamped to max
        expect(safeSettings.topP, 1.0); // Clamped to max
        expect(safeSettings.topK, 1); // Clamped to min
        expect(safeSettings.repeatPenalty, 0.5); // Clamped to min
        expect(safeSettings.maxTokens, 4096); // Clamped to max
        expect(safeSettings.numThread, 16); // Clamped to max
      });

      test('should provide helpful recommendations', () async {
        // Test good settings
        final goodSettings = GenerationSettings.defaults();
        final goodRecommendations = GenerationSettingsService.getRecommendations(goodSettings);
        expect(goodRecommendations.any((rec) => rec.contains('Settings look good!')), true);

        // Test extreme settings
        const extremeSettings = GenerationSettings(
          temperature: 1.8, // High
          topP: 0.98, // High
          topK: 3, // Low
          repeatPenalty: 1.1,
          maxTokens: 30, // Very low
          numThread: 12, // High
        );

        final extremeRecommendations = GenerationSettingsService.getRecommendations(extremeSettings);
        expect(extremeRecommendations.any((rec) => rec.startsWith('WARNING:')), true);
        expect(extremeRecommendations.any((rec) => rec.contains('unpredictable')), true);
        expect(extremeRecommendations.any((rec) => rec.contains('repetitive')), true);
      });
    });

    group('Settings Comparison and Summary', () {
      test('should compare settings correctly', () async {
        final settings1 = GenerationSettings.defaults();
        final settings2 = settings1.copyWith(
          temperature: 0.8,
          topK: 50,
        );

        final differences = GenerationSettingsService.compareSettings(settings1, settings2);

        expect(differences.keys, contains('temperature'));
        expect(differences.keys, contains('topK'));
        expect(differences.keys, hasLength(2));

        expect(differences['temperature']['from'], 0.7);
        expect(differences['temperature']['to'], 0.8);
        expect(differences['topK']['from'], 40);
        expect(differences['topK']['to'], 50);

        // Test identical settings
        final noDifferences = GenerationSettingsService.compareSettings(settings1, settings1);
        expect(noDifferences, isEmpty);
      });

      test('should generate settings summary', () async {
        final settings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        final summary = GenerationSettingsService.getSettingsSummary(settings);

        expect(summary, contains('Temp: 0.8'));
        expect(summary, contains('Top-P: 0.95'));
        expect(summary, contains('Top-K: 50'));
        expect(summary, contains('Repeat: 1.2'));
        expect(summary, contains('Tokens: 2048'));
        expect(summary, contains('Threads: 8'));

        // Test unlimited tokens
        final unlimitedSettings = settings.copyWith(maxTokens: -1);
        final unlimitedSummary = GenerationSettingsService.getSettingsSummary(unlimitedSettings);
        expect(unlimitedSummary, contains('Tokens: Unlimited'));
      });

      test('should detect extreme settings', () async {
        final normalSettings = GenerationSettings.defaults();
        expect(GenerationSettingsService.areSettingsExtreme(normalSettings), false);

        const extremeSettings = GenerationSettings(
          temperature: 1.8, // High
          topP: 0.05, // Low
          topK: 3, // Low
          repeatPenalty: 1.8, // High
          maxTokens: 30, // Low
          numThread: 12, // High
        );

        expect(GenerationSettingsService.areSettingsExtreme(extremeSettings), true);
      });
    });

    group('Backward Compatibility', () {
      test('should maintain compatibility with existing chat data', () async {
        // Test loading chat data that was saved before generation settings were added
        final legacyChatJson = {
          'id': 'legacy-chat',
          'title': 'Legacy Chat',
          'modelName': 'llama2',
          'messages': [],
          'createdAt': DateTime.now().toIso8601String(),
          'lastUpdatedAt': DateTime.now().toIso8601String(),
          // No customGenerationSettings field
        };

        final legacyChat = Chat.fromJson(legacyChatJson);

        expect(legacyChat.hasCustomGenerationSettings, false);
        expect(legacyChat.customGenerationSettings, isNull);

        // Should work with settings resolution
        final globalSettings = AppSettings();
        final effectiveSettings = GenerationSettingsService.getEffectiveSettings(
          chat: legacyChat,
          globalSettings: globalSettings,
        );

        expect(effectiveSettings, equals(globalSettings.generationSettings));
      });

      test('should handle null and missing fields gracefully', () async {
        // Test with explicit null
        final chatWithNullSettings = Chat(
          id: 'null-settings-chat',
          title: 'Chat with null settings',
          modelName: 'llama2',
          messages: [],
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
          customGenerationSettings: null,
        );

        expect(chatWithNullSettings.hasCustomGenerationSettings, false);

        // Test JSON round-trip with null
        final json = chatWithNullSettings.toJson();
        final restored = Chat.fromJson(json);
        expect(restored.hasCustomGenerationSettings, false);
        expect(restored.customGenerationSettings, isNull);
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle corrupted settings data gracefully', () async {
        // Test with corrupted JSON
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_settings', 'invalid json');

        // Should fall back to defaults
        final settings = await storageService.loadSettings();
        expect(settings.generationSettings, equals(GenerationSettings.defaults()));
      });

      test('should handle invalid generation settings in JSON', () async {
        final invalidSettingsJson = '''
        {
          "ollamaHost": "127.0.0.1",
          "ollamaPort": 11434,
          "generationSettings": {
            "temperature": "invalid",
            "topP": null,
            "topK": -5,
            "repeatPenalty": "not a number",
            "maxTokens": "unlimited",
            "numThread": 0
          }
        }
        ''';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_settings', invalidSettingsJson);

        // Should fall back to defaults for invalid values
        final settings = await storageService.loadSettings();
        expect(settings.generationSettings.temperature, 0.7); // Default
        expect(settings.generationSettings.topP, 0.9); // Default
        expect(settings.generationSettings.topK, 40); // Default
      });

      test('should validate settings before API calls', () async {
        const invalidSettings = GenerationSettings(
          temperature: 3.0, // Invalid
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );

        // Should not build API options for invalid settings
        expect(GenerationSettingsService.validateSettings(invalidSettings), false);

        // Should create safe settings for API use
        final safeSettings = GenerationSettingsService.createSafeSettings(invalidSettings);
        expect(GenerationSettingsService.validateSettings(safeSettings), true);

        final apiOptions = GenerationSettingsService.buildOllamaOptions(settings: safeSettings);
        expect(apiOptions['temperature'], 2.0); // Clamped value
      });
    });
  });
}