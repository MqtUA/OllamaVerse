import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/generation_settings_service.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/chat.dart';
import '../../lib/models/app_settings.dart';

void main() {
  group('GenerationSettingsService', () {
    late AppSettings defaultAppSettings;
    late GenerationSettings customSettings;
    late Chat chatWithCustomSettings;
    late Chat chatWithoutCustomSettings;

    setUp(() {
      // Set up default app settings
      defaultAppSettings = AppSettings(
        generationSettings: GenerationSettings.defaults(),
      );

      // Set up custom generation settings
      customSettings = const GenerationSettings(
        temperature: 0.8,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.2,
        maxTokens: 1000,
        numThread: 6,
      );

      // Set up chat with custom settings
      chatWithCustomSettings = Chat(
        id: 'chat1',
        title: 'Test Chat with Custom Settings',
        modelName: 'llama2',
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        customGenerationSettings: customSettings,
      );

      // Set up chat without custom settings
      chatWithoutCustomSettings = Chat(
        id: 'chat2',
        title: 'Test Chat without Custom Settings',
        modelName: 'llama2',
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      );
    });

    group('getEffectiveSettings', () {
      test('returns per-chat settings when chat has custom settings', () {
        final result = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithCustomSettings,
          globalSettings: defaultAppSettings,
        );

        expect(result, equals(customSettings));
        expect(result.temperature, equals(0.8));
        expect(result.topP, equals(0.95));
      });

      test('returns global settings when chat has no custom settings', () {
        final result = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithoutCustomSettings,
          globalSettings: defaultAppSettings,
        );

        expect(result, equals(defaultAppSettings.generationSettings));
        expect(result.temperature, equals(0.7)); // Default value
        expect(result.topP, equals(0.9)); // Default value
      });

      test('returns global settings when chat is null', () {
        final result = GenerationSettingsService.getEffectiveSettings(
          chat: null,
          globalSettings: defaultAppSettings,
        );

        expect(result, equals(defaultAppSettings.generationSettings));
      });

      test('handles chat with null custom settings', () {
        final chatWithNullSettings = Chat(
          id: 'chat3',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: [],
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
          customGenerationSettings: null,
        );

        final result = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithNullSettings,
          globalSettings: defaultAppSettings,
        );

        expect(result, equals(defaultAppSettings.generationSettings));
      });
    });

    group('buildOllamaOptions', () {
      test('builds options with only non-default values', () {
        final settings = GenerationSettings.defaults();
        final result = GenerationSettingsService.buildOllamaOptions(
          settings: settings,
        );

        // Should be empty since all values are defaults
        expect(result, isEmpty);
      });

      test('includes non-default values in options', () {
        final result = GenerationSettingsService.buildOllamaOptions(
          settings: customSettings,
        );

        expect(result['temperature'], equals(0.8));
        expect(result['top_p'], equals(0.95));
        expect(result['top_k'], equals(50));
        expect(result['repeat_penalty'], equals(1.2));
        expect(result['num_predict'], equals(1000));
        expect(result['num_thread'], equals(6));
      });

      test('includes context length when provided and non-default', () {
        final result = GenerationSettingsService.buildOllamaOptions(
          settings: GenerationSettings.defaults(),
          contextLength: 8192,
        );

        expect(result['num_ctx'], equals(8192));
      });

      test('excludes context length when it matches default', () {
        final result = GenerationSettingsService.buildOllamaOptions(
          settings: GenerationSettings.defaults(),
          contextLength: 4096, // Default value
        );

        expect(result.containsKey('num_ctx'), isFalse);
      });

      test('handles unlimited max tokens correctly', () {
        final settingsWithUnlimitedTokens = customSettings.copyWith(
          maxTokens: -1,
        );

        final result = GenerationSettingsService.buildOllamaOptions(
          settings: settingsWithUnlimitedTokens,
        );

        // Should not include num_predict for unlimited tokens
        expect(result.containsKey('num_predict'), isFalse);
      });

      test('handles streaming flag', () {
        final result = GenerationSettingsService.buildOllamaOptions(
          settings: customSettings,
          isStreaming: true,
        );

        // Should still include all the custom settings
        expect(result['temperature'], equals(0.8));
        expect(result['top_p'], equals(0.95));
      });
    });

    group('validateSettings', () {
      test('returns true for valid settings', () {
        final validSettings = GenerationSettings.defaults();
        final result = GenerationSettingsService.validateSettings(validSettings);

        expect(result, isTrue);
      });

      test('returns false for invalid settings', () {
        const invalidSettings = GenerationSettings(
          temperature: 3.0, // Invalid: > 2.0
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );

        final result = GenerationSettingsService.validateSettings(invalidSettings);

        expect(result, isFalse);
      });
    });

    group('getValidationErrors', () {
      test('returns empty list for valid settings', () {
        final validSettings = GenerationSettings.defaults();
        final result = GenerationSettingsService.getValidationErrors(validSettings);

        expect(result, isEmpty);
      });

      test('returns error messages for invalid settings', () {
        const invalidSettings = GenerationSettings(
          temperature: 3.0, // Invalid
          topP: 1.5, // Invalid
          topK: 0, // Invalid
          repeatPenalty: 0.1, // Invalid
          maxTokens: 5000, // Invalid
          numThread: 20, // Invalid
        );

        final result = GenerationSettingsService.getValidationErrors(invalidSettings);

        expect(result, isNotEmpty);
        expect(result.any((error) => error.contains('Temperature')), isTrue);
        expect(result.any((error) => error.contains('Top P')), isTrue);
        expect(result.any((error) => error.contains('Top K')), isTrue);
        expect(result.any((error) => error.contains('Repeat Penalty')), isTrue);
        expect(result.any((error) => error.contains('Max Tokens')), isTrue);
        expect(result.any((error) => error.contains('threads')), isTrue);
      });
    });

    group('getRecommendations', () {
      test('returns positive message for good settings', () {
        final goodSettings = GenerationSettings.defaults();
        final result = GenerationSettingsService.getRecommendations(goodSettings);

        expect(result.any((rec) => rec.contains('Settings look good!')), isTrue);
      });

      test('includes validation errors with ERROR prefix', () {
        const invalidSettings = GenerationSettings(
          temperature: 3.0, // Invalid
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );

        final result = GenerationSettingsService.getRecommendations(invalidSettings);

        expect(result.any((rec) => rec.startsWith('ERROR:')), isTrue);
      });

      test('includes performance warnings with WARNING prefix', () {
        const extremeSettings = GenerationSettings(
          temperature: 1.8, // Will trigger warning
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );

        final result = GenerationSettingsService.getRecommendations(extremeSettings);

        expect(result.any((rec) => rec.startsWith('WARNING:')), isTrue);
      });

      test('includes suggestions for problematic combinations', () {
        const problematicSettings = GenerationSettings(
          temperature: 1.2, // High
          topP: 0.98, // High
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );

        final result = GenerationSettingsService.getRecommendations(problematicSettings);

        expect(result.any((rec) => rec.contains('SUGGESTION:')), isTrue);
        expect(result.any((rec) => rec.contains('unpredictable')), isTrue);
      });

      test('suggests improvements for conservative settings', () {
        const conservativeSettings = GenerationSettings(
          temperature: 0.2, // Low
          topP: 0.9,
          topK: 5, // Low
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );

        final result = GenerationSettingsService.getRecommendations(conservativeSettings);

        expect(result.any((rec) => rec.contains('repetitive')), isTrue);
      });
    });

    group('createSafeSettings', () {
      test('returns valid settings unchanged', () {
        final validSettings = GenerationSettings.defaults();
        final result = GenerationSettingsService.createSafeSettings(validSettings);

        expect(result, equals(validSettings));
      });

      test('clamps invalid values to safe ranges', () {
        const invalidSettings = GenerationSettings(
          temperature: 3.0, // Will be clamped to 2.0
          topP: 1.5, // Will be clamped to 1.0
          topK: 0, // Will be clamped to 1
          repeatPenalty: 0.1, // Will be clamped to 0.5
          maxTokens: 5000, // Will be clamped to 4096
          numThread: 20, // Will be clamped to 16
        );

        final result = GenerationSettingsService.createSafeSettings(invalidSettings);

        expect(result.temperature, equals(2.0));
        expect(result.topP, equals(1.0));
        expect(result.topK, equals(1));
        expect(result.repeatPenalty, equals(0.5));
        expect(result.maxTokens, equals(4096));
        expect(result.numThread, equals(16));
      });
    });

    group('compareSettings', () {
      test('returns empty map for identical settings', () {
        final settings1 = GenerationSettings.defaults();
        final settings2 = GenerationSettings.defaults();

        final result = GenerationSettingsService.compareSettings(settings1, settings2);

        expect(result, isEmpty);
      });

      test('returns differences between settings', () {
        final settings1 = GenerationSettings.defaults();
        final settings2 = customSettings;

        final result = GenerationSettingsService.compareSettings(settings1, settings2);

        expect(result['temperature']['from'], equals(0.7));
        expect(result['temperature']['to'], equals(0.8));
        expect(result['topP']['from'], equals(0.9));
        expect(result['topP']['to'], equals(0.95));
        expect(result['topK']['from'], equals(40));
        expect(result['topK']['to'], equals(50));
      });

      test('only includes changed values', () {
        final settings1 = GenerationSettings.defaults();
        final settings2 = settings1.copyWith(temperature: 0.8);

        final result = GenerationSettingsService.compareSettings(settings1, settings2);

        expect(result.keys, contains('temperature'));
        expect(result.keys, hasLength(1));
      });
    });

    group('getSettingsSummary', () {
      test('returns formatted summary string', () {
        final settings = GenerationSettings.defaults();
        final result = GenerationSettingsService.getSettingsSummary(settings);

        expect(result, contains('Temp: 0.7'));
        expect(result, contains('Top-P: 0.90'));
        expect(result, contains('Top-K: 40'));
        expect(result, contains('Repeat: 1.1'));
        expect(result, contains('Tokens: Unlimited'));
        expect(result, contains('Threads: 4'));
      });

      test('shows limited tokens when maxTokens is not -1', () {
        final settings = customSettings;
        final result = GenerationSettingsService.getSettingsSummary(settings);

        expect(result, contains('Tokens: 1000'));
        expect(result, isNot(contains('Unlimited')));
      });
    });

    group('areSettingsExtreme', () {
      test('returns false for normal settings', () {
        final normalSettings = GenerationSettings.defaults();
        final result = GenerationSettingsService.areSettingsExtreme(normalSettings);

        expect(result, isFalse);
      });

      test('returns true for extreme temperature values', () {
        final extremeHot = GenerationSettings.defaults().copyWith(temperature: 1.8);
        final extremeCold = GenerationSettings.defaults().copyWith(temperature: 0.05);

        expect(GenerationSettingsService.areSettingsExtreme(extremeHot), isTrue);
        expect(GenerationSettingsService.areSettingsExtreme(extremeCold), isTrue);
      });

      test('returns true for extreme topP values', () {
        final extremeTopP = GenerationSettings.defaults().copyWith(topP: 0.05);

        expect(GenerationSettingsService.areSettingsExtreme(extremeTopP), isTrue);
      });

      test('returns true for extreme topK values', () {
        final extremeTopK = GenerationSettings.defaults().copyWith(topK: 3);

        expect(GenerationSettingsService.areSettingsExtreme(extremeTopK), isTrue);
      });

      test('returns true for extreme repeat penalty', () {
        final extremeRepeat = GenerationSettings.defaults().copyWith(repeatPenalty: 1.8);

        expect(GenerationSettingsService.areSettingsExtreme(extremeRepeat), isTrue);
      });

      test('returns true for very low max tokens', () {
        final lowTokens = GenerationSettings.defaults().copyWith(maxTokens: 30);

        expect(GenerationSettingsService.areSettingsExtreme(lowTokens), isTrue);
      });

      test('returns true for high thread count', () {
        final highThreads = GenerationSettings.defaults().copyWith(numThread: 12);

        expect(GenerationSettingsService.areSettingsExtreme(highThreads), isTrue);
      });
    });

    group('getDefaultSettings', () {
      test('returns default generation settings', () {
        final result = GenerationSettingsService.getDefaultSettings();
        final expected = GenerationSettings.defaults();

        expect(result, equals(expected));
      });
    });
  });
}