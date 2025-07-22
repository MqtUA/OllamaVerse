import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/generation_settings.dart';

void main() {
  group('AppSettings', () {
    group('constructor', () {
      test('should create with default values', () {
        final settings = AppSettings();

        expect(settings.ollamaHost, '127.0.0.1');
        expect(settings.ollamaPort, 11434);
        expect(settings.fontSize, 16.0);
        expect(settings.showLiveResponse, false);
        expect(settings.contextLength, 4096);
        expect(settings.systemPrompt, '');
        expect(settings.thinkingBubbleDefaultExpanded, true);
        expect(settings.thinkingBubbleAutoCollapse, false);
        expect(settings.darkMode, false);
        expect(settings.generationSettings, equals(GenerationSettings.defaults()));
      });

      test('should create with custom values', () {
        final customGenerationSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        final settings = AppSettings(
          ollamaHost: '192.168.1.100',
          ollamaPort: 8080,
          fontSize: 18.0,
          showLiveResponse: true,
          contextLength: 8192,
          systemPrompt: 'You are a helpful assistant.',
          thinkingBubbleDefaultExpanded: false,
          thinkingBubbleAutoCollapse: true,
          darkMode: true,
          generationSettings: customGenerationSettings,
        );

        expect(settings.ollamaHost, '192.168.1.100');
        expect(settings.ollamaPort, 8080);
        expect(settings.fontSize, 18.0);
        expect(settings.showLiveResponse, true);
        expect(settings.contextLength, 8192);
        expect(settings.systemPrompt, 'You are a helpful assistant.');
        expect(settings.thinkingBubbleDefaultExpanded, false);
        expect(settings.thinkingBubbleAutoCollapse, true);
        expect(settings.darkMode, true);
        expect(settings.generationSettings, customGenerationSettings);
      });

      test('should use default generation settings when null provided', () {
        final settings = AppSettings(
          generationSettings: null,
        );

        expect(settings.generationSettings, equals(GenerationSettings.defaults()));
      });
    });

    group('ollamaUrl', () {
      test('should construct URL correctly with default values', () {
        final settings = AppSettings();
        expect(settings.ollamaUrl, 'http://127.0.0.1:11434');
      });

      test('should construct URL correctly with custom values', () {
        final settings = AppSettings(
          ollamaHost: '192.168.1.100',
          ollamaPort: 8080,
        );
        expect(settings.ollamaUrl, 'http://192.168.1.100:8080');
      });

      test('should handle localhost', () {
        final settings = AppSettings(
          ollamaHost: 'localhost',
          ollamaPort: 11434,
        );
        expect(settings.ollamaUrl, 'http://localhost:11434');
      });

      test('should handle different ports', () {
        final settings = AppSettings(
          ollamaHost: '127.0.0.1',
          ollamaPort: 3000,
        );
        expect(settings.ollamaUrl, 'http://127.0.0.1:3000');
      });
    });

    group('copyWith', () {
      late AppSettings originalSettings;

      setUp(() {
        originalSettings = AppSettings(
          ollamaHost: '127.0.0.1',
          ollamaPort: 11434,
          fontSize: 16.0,
          showLiveResponse: false,
          contextLength: 4096,
          systemPrompt: 'Original prompt',
          thinkingBubbleDefaultExpanded: true,
          thinkingBubbleAutoCollapse: false,
          darkMode: false,
          generationSettings: GenerationSettings.defaults(),
        );
      });

      test('should create copy with updated values', () {
        final newGenerationSettings = GenerationSettings.defaults().copyWith(temperature: 0.8);

        final updatedSettings = originalSettings.copyWith(
          ollamaHost: '192.168.1.100',
          fontSize: 18.0,
          darkMode: true,
          generationSettings: newGenerationSettings,
        );

        expect(updatedSettings.ollamaHost, '192.168.1.100'); // Changed
        expect(updatedSettings.ollamaPort, originalSettings.ollamaPort); // Unchanged
        expect(updatedSettings.fontSize, 18.0); // Changed
        expect(updatedSettings.showLiveResponse, originalSettings.showLiveResponse); // Unchanged
        expect(updatedSettings.contextLength, originalSettings.contextLength); // Unchanged
        expect(updatedSettings.systemPrompt, originalSettings.systemPrompt); // Unchanged
        expect(updatedSettings.thinkingBubbleDefaultExpanded, originalSettings.thinkingBubbleDefaultExpanded); // Unchanged
        expect(updatedSettings.thinkingBubbleAutoCollapse, originalSettings.thinkingBubbleAutoCollapse); // Unchanged
        expect(updatedSettings.darkMode, true); // Changed
        expect(updatedSettings.generationSettings, newGenerationSettings); // Changed
      });

      test('should create identical copy when no parameters provided', () {
        final copy = originalSettings.copyWith();

        expect(copy.ollamaHost, originalSettings.ollamaHost);
        expect(copy.ollamaPort, originalSettings.ollamaPort);
        expect(copy.fontSize, originalSettings.fontSize);
        expect(copy.showLiveResponse, originalSettings.showLiveResponse);
        expect(copy.contextLength, originalSettings.contextLength);
        expect(copy.systemPrompt, originalSettings.systemPrompt);
        expect(copy.thinkingBubbleDefaultExpanded, originalSettings.thinkingBubbleDefaultExpanded);
        expect(copy.thinkingBubbleAutoCollapse, originalSettings.thinkingBubbleAutoCollapse);
        expect(copy.darkMode, originalSettings.darkMode);
        expect(copy.generationSettings, originalSettings.generationSettings);
      });

      test('should update only generation settings', () {
        final newGenerationSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        final updatedSettings = originalSettings.copyWith(
          generationSettings: newGenerationSettings,
        );

        // All other fields should remain unchanged
        expect(updatedSettings.ollamaHost, originalSettings.ollamaHost);
        expect(updatedSettings.ollamaPort, originalSettings.ollamaPort);
        expect(updatedSettings.fontSize, originalSettings.fontSize);
        expect(updatedSettings.showLiveResponse, originalSettings.showLiveResponse);
        expect(updatedSettings.contextLength, originalSettings.contextLength);
        expect(updatedSettings.systemPrompt, originalSettings.systemPrompt);
        expect(updatedSettings.thinkingBubbleDefaultExpanded, originalSettings.thinkingBubbleDefaultExpanded);
        expect(updatedSettings.thinkingBubbleAutoCollapse, originalSettings.thinkingBubbleAutoCollapse);
        expect(updatedSettings.darkMode, originalSettings.darkMode);

        // Only generation settings should change
        expect(updatedSettings.generationSettings, newGenerationSettings);
        expect(updatedSettings.generationSettings.temperature, 0.8);
        expect(updatedSettings.generationSettings.topP, 0.95);
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        final customGenerationSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 2048,
          numThread: 8,
        );

        final settings = AppSettings(
          ollamaHost: '192.168.1.100',
          ollamaPort: 8080,
          fontSize: 18.0,
          showLiveResponse: true,
          contextLength: 8192,
          systemPrompt: 'You are a helpful assistant.',
          thinkingBubbleDefaultExpanded: false,
          thinkingBubbleAutoCollapse: true,
          darkMode: true,
          generationSettings: customGenerationSettings,
        );

        final json = settings.toJson();

        expect(json['ollamaHost'], '192.168.1.100');
        expect(json['ollamaPort'], 8080);
        expect(json['fontSize'], 18.0);
        expect(json['showLiveResponse'], true);
        expect(json['contextLength'], 8192);
        expect(json['systemPrompt'], 'You are a helpful assistant.');
        expect(json['thinkingBubbleDefaultExpanded'], false);
        expect(json['thinkingBubbleAutoCollapse'], true);
        expect(json['darkMode'], true);
        expect(json['generationSettings'], isA<Map<String, dynamic>>());
        expect(json['generationSettings']['temperature'], 0.8);
        expect(json['generationSettings']['topP'], 0.95);
      });

      test('should serialize default settings to JSON correctly', () {
        final settings = AppSettings();
        final json = settings.toJson();

        expect(json['ollamaHost'], '127.0.0.1');
        expect(json['ollamaPort'], 11434);
        expect(json['fontSize'], 16.0);
        expect(json['showLiveResponse'], false);
        expect(json['contextLength'], 4096);
        expect(json['systemPrompt'], '');
        expect(json['thinkingBubbleDefaultExpanded'], true);
        expect(json['thinkingBubbleAutoCollapse'], false);
        expect(json['darkMode'], false);
        expect(json['generationSettings'], isA<Map<String, dynamic>>());
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'ollamaHost': '192.168.1.100',
          'ollamaPort': 8080,
          'fontSize': 18.0,
          'showLiveResponse': true,
          'contextLength': 8192,
          'systemPrompt': 'You are a helpful assistant.',
          'thinkingBubbleDefaultExpanded': false,
          'thinkingBubbleAutoCollapse': true,
          'darkMode': true,
          'generationSettings': {
            'temperature': 0.8,
            'topP': 0.95,
            'topK': 50,
            'repeatPenalty': 1.2,
            'maxTokens': 2048,
            'numThread': 8,
          },
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.ollamaHost, '192.168.1.100');
        expect(settings.ollamaPort, 8080);
        expect(settings.fontSize, 18.0);
        expect(settings.showLiveResponse, true);
        expect(settings.contextLength, 8192);
        expect(settings.systemPrompt, 'You are a helpful assistant.');
        expect(settings.thinkingBubbleDefaultExpanded, false);
        expect(settings.thinkingBubbleAutoCollapse, true);
        expect(settings.darkMode, true);
        expect(settings.generationSettings.temperature, 0.8);
        expect(settings.generationSettings.topP, 0.95);
        expect(settings.generationSettings.topK, 50);
      });

      test('should deserialize from JSON with missing fields using defaults', () {
        final json = {
          'ollamaHost': '192.168.1.100',
          'ollamaPort': 8080,
          // Missing other fields
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.ollamaHost, '192.168.1.100');
        expect(settings.ollamaPort, 8080);
        expect(settings.fontSize, 16.0); // Default
        expect(settings.showLiveResponse, false); // Default
        expect(settings.contextLength, 4096); // Default
        expect(settings.systemPrompt, ''); // Default
        expect(settings.thinkingBubbleDefaultExpanded, true); // Default
        expect(settings.thinkingBubbleAutoCollapse, false); // Default
        expect(settings.darkMode, false); // Default
        expect(settings.generationSettings, equals(GenerationSettings.defaults())); // Default
      });

      test('should handle null generationSettings in JSON', () {
        final json = {
          'ollamaHost': '127.0.0.1',
          'ollamaPort': 11434,
          'fontSize': 16.0,
          'showLiveResponse': false,
          'contextLength': 4096,
          'systemPrompt': '',
          'thinkingBubbleDefaultExpanded': true,
          'thinkingBubbleAutoCollapse': false,
          'darkMode': false,
          'generationSettings': null,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.generationSettings, equals(GenerationSettings.defaults()));
      });

      test('should handle missing generationSettings in JSON', () {
        final json = {
          'ollamaHost': '127.0.0.1',
          'ollamaPort': 11434,
          'fontSize': 16.0,
          'showLiveResponse': false,
          'contextLength': 4096,
          'systemPrompt': '',
          'thinkingBubbleDefaultExpanded': true,
          'thinkingBubbleAutoCollapse': false,
          'darkMode': false,
          // generationSettings is missing
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.generationSettings, equals(GenerationSettings.defaults()));
      });

      test('should round-trip through JSON correctly', () {
        final originalSettings = AppSettings(
          ollamaHost: '192.168.1.100',
          ollamaPort: 8080,
          fontSize: 18.0,
          showLiveResponse: true,
          contextLength: 8192,
          systemPrompt: 'You are a helpful assistant.',
          thinkingBubbleDefaultExpanded: false,
          thinkingBubbleAutoCollapse: true,
          darkMode: true,
          generationSettings: const GenerationSettings(
            temperature: 0.8,
            topP: 0.95,
            topK: 50,
            repeatPenalty: 1.2,
            maxTokens: 2048,
            numThread: 8,
          ),
        );

        final json = originalSettings.toJson();
        final restoredSettings = AppSettings.fromJson(json);

        expect(restoredSettings.ollamaHost, originalSettings.ollamaHost);
        expect(restoredSettings.ollamaPort, originalSettings.ollamaPort);
        expect(restoredSettings.fontSize, originalSettings.fontSize);
        expect(restoredSettings.showLiveResponse, originalSettings.showLiveResponse);
        expect(restoredSettings.contextLength, originalSettings.contextLength);
        expect(restoredSettings.systemPrompt, originalSettings.systemPrompt);
        expect(restoredSettings.thinkingBubbleDefaultExpanded, originalSettings.thinkingBubbleDefaultExpanded);
        expect(restoredSettings.thinkingBubbleAutoCollapse, originalSettings.thinkingBubbleAutoCollapse);
        expect(restoredSettings.darkMode, originalSettings.darkMode);
        expect(restoredSettings.generationSettings, originalSettings.generationSettings);
      });
    });

    group('edge cases', () {
      test('should handle extreme port numbers', () {
        final settings = AppSettings(
          ollamaPort: 65535, // Maximum port number
        );

        expect(settings.ollamaPort, 65535);
        expect(settings.ollamaUrl, 'http://127.0.0.1:65535');

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.ollamaPort, 65535);
      });

      test('should handle very large font size', () {
        final settings = AppSettings(
          fontSize: 100.0,
        );

        expect(settings.fontSize, 100.0);

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.fontSize, 100.0);
      });

      test('should handle very large context length', () {
        final settings = AppSettings(
          contextLength: 32768,
        );

        expect(settings.contextLength, 32768);

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.contextLength, 32768);
      });

      test('should handle long system prompt', () {
        final longPrompt = 'A' * 10000;
        final settings = AppSettings(
          systemPrompt: longPrompt,
        );

        expect(settings.systemPrompt, longPrompt);

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.systemPrompt, longPrompt);
      });

      test('should handle special characters in host', () {
        final settings = AppSettings(
          ollamaHost: 'my-server.example.com',
        );

        expect(settings.ollamaHost, 'my-server.example.com');
        expect(settings.ollamaUrl, 'http://my-server.example.com:11434');

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.ollamaHost, 'my-server.example.com');
      });

      test('should handle special characters in system prompt', () {
        final promptWithSpecialChars = 'You are a helpful assistant. Use émojis 🚀 and "quotes" when appropriate.';
        final settings = AppSettings(
          systemPrompt: promptWithSpecialChars,
        );

        expect(settings.systemPrompt, promptWithSpecialChars);

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.systemPrompt, promptWithSpecialChars);
      });

      test('should handle zero values', () {
        final settings = AppSettings(
          ollamaPort: 0,
          fontSize: 0.0,
          contextLength: 0,
        );

        expect(settings.ollamaPort, 0);
        expect(settings.fontSize, 0.0);
        expect(settings.contextLength, 0);

        final json = settings.toJson();
        final restored = AppSettings.fromJson(json);
        expect(restored.ollamaPort, 0);
        expect(restored.fontSize, 0.0);
        expect(restored.contextLength, 0);
      });
    });
  });
}