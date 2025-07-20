import 'package:flutter_test/flutter_test.dart';
import 'package:ollamaverse/models/generation_settings.dart';

void main() {
  group('GenerationSettings', () {
    group('defaults', () {
      test('should create with correct default values', () {
        final settings = GenerationSettings.defaults();
        
        expect(settings.temperature, 0.7);
        expect(settings.topP, 0.9);
        expect(settings.topK, 40);
        expect(settings.repeatPenalty, 1.1);
        expect(settings.maxTokens, -1);
        expect(settings.numThread, 4);
      });
    });

    group('fromJson', () {
      test('should parse valid JSON correctly', () {
        final json = {
          'temperature': 0.8,
          'topP': 0.95,
          'topK': 50,
          'repeatPenalty': 1.2,
          'maxTokens': 1000,
          'numThread': 8,
        };
        
        final settings = GenerationSettings.fromJson(json);
        
        expect(settings.temperature, 0.8);
        expect(settings.topP, 0.95);
        expect(settings.topK, 50);
        expect(settings.repeatPenalty, 1.2);
        expect(settings.maxTokens, 1000);
        expect(settings.numThread, 8);
      });

      test('should handle missing values with defaults', () {
        final json = {
          'temperature': 0.8,
          // Missing other values
        };
        
        final settings = GenerationSettings.fromJson(json);
        final defaults = GenerationSettings.defaults();
        
        expect(settings.temperature, 0.8);
        expect(settings.topP, defaults.topP);
        expect(settings.topK, defaults.topK);
        expect(settings.repeatPenalty, defaults.repeatPenalty);
        expect(settings.maxTokens, defaults.maxTokens);
        expect(settings.numThread, defaults.numThread);
      });

      test('should handle null values with defaults', () {
        final json = {
          'temperature': null,
          'topP': 0.95,
          'topK': null,
        };
        
        final settings = GenerationSettings.fromJson(json);
        final defaults = GenerationSettings.defaults();
        
        expect(settings.temperature, defaults.temperature);
        expect(settings.topP, 0.95);
        expect(settings.topK, defaults.topK);
      });

      test('should handle string numbers', () {
        final json = {
          'temperature': '0.8',
          'topK': '50',
          'maxTokens': '1000',
        };
        
        final settings = GenerationSettings.fromJson(json);
        
        expect(settings.temperature, 0.8);
        expect(settings.topK, 50);
        expect(settings.maxTokens, 1000);
      });

      test('should handle invalid string values with defaults', () {
        final json = {
          'temperature': 'invalid',
          'topK': 'not_a_number',
        };
        
        final settings = GenerationSettings.fromJson(json);
        final defaults = GenerationSettings.defaults();
        
        expect(settings.temperature, defaults.temperature);
        expect(settings.topK, defaults.topK);
      });

      test('should handle mixed number types', () {
        final json = {
          'temperature': 0.8, // double
          'topP': 1, // int
          'topK': 50.0, // double that should be int
        };
        
        final settings = GenerationSettings.fromJson(json);
        
        expect(settings.temperature, 0.8);
        expect(settings.topP, 1.0);
        expect(settings.topK, 50);
      });
    });

    group('toJson', () {
      test('should serialize to JSON correctly', () {
        final settings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 8,
        );
        
        final json = settings.toJson();
        
        expect(json['temperature'], 0.8);
        expect(json['topP'], 0.95);
        expect(json['topK'], 50);
        expect(json['repeatPenalty'], 1.2);
        expect(json['maxTokens'], 1000);
        expect(json['numThread'], 8);
      });

      test('should round-trip through JSON correctly', () {
        final original = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 8,
        );
        
        final json = original.toJson();
        final restored = GenerationSettings.fromJson(json);
        
        expect(restored, equals(original));
      });
    });

    group('copyWith', () {
      test('should create copy with updated values', () {
        final original = GenerationSettings.defaults();
        final updated = original.copyWith(
          temperature: 0.8,
          topK: 50,
        );
        
        expect(updated.temperature, 0.8);
        expect(updated.topK, 50);
        expect(updated.topP, original.topP); // Unchanged
        expect(updated.repeatPenalty, original.repeatPenalty); // Unchanged
      });

      test('should create identical copy when no parameters provided', () {
        final original = GenerationSettings.defaults();
        final copy = original.copyWith();
        
        expect(copy, equals(original));
      });
    });

    group('validation', () {
      test('should validate correct default settings', () {
        final settings = GenerationSettings.defaults();
        
        expect(settings.isValid(), isTrue);
        expect(settings.getValidationErrors(), isEmpty);
      });

      test('should detect invalid temperature', () {
        final settings = const GenerationSettings(
          temperature: 3.0, // Invalid: > 2.0
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        expect(settings.isValid(), isFalse);
        expect(settings.getValidationErrors(), contains('Temperature must be between 0.0 and 2.0'));
      });

      test('should detect invalid topP', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 1.5, // Invalid: > 1.0
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        expect(settings.isValid(), isFalse);
        expect(settings.getValidationErrors(), contains('Top P must be between 0.0 and 1.0'));
      });

      test('should detect invalid topK', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 0, // Invalid: < 1
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        expect(settings.isValid(), isFalse);
        expect(settings.getValidationErrors(), contains('Top K must be between 1 and 100'));
      });

      test('should detect invalid repeatPenalty', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 0.3, // Invalid: < 0.5
          maxTokens: -1,
          numThread: 4,
        );
        
        expect(settings.isValid(), isFalse);
        expect(settings.getValidationErrors(), contains('Repeat Penalty must be between 0.5 and 2.0'));
      });

      test('should detect invalid maxTokens', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: 5000, // Invalid: > 4096
          numThread: 4,
        );
        
        expect(settings.isValid(), isFalse);
        expect(settings.getValidationErrors(), contains('Max Tokens must be -1 (unlimited) or between 1 and 4096'));
      });

      test('should detect invalid numThread', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 20, // Invalid: > 16
        );
        
        expect(settings.isValid(), isFalse);
        expect(settings.getValidationErrors(), contains('Number of threads must be between 1 and 16'));
      });

      test('should detect multiple validation errors', () {
        final settings = const GenerationSettings(
          temperature: -0.5, // Invalid
          topP: 1.5, // Invalid
          topK: 0, // Invalid
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        expect(settings.isValid(), isFalse);
        final errors = settings.getValidationErrors();
        expect(errors.length, 3);
        expect(errors, contains('Temperature must be between 0.0 and 2.0'));
        expect(errors, contains('Top P must be between 0.0 and 1.0'));
        expect(errors, contains('Top K must be between 1 and 100'));
      });

      test('should allow -1 for unlimited maxTokens', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1, // Valid: unlimited
          numThread: 4,
        );
        
        expect(settings.isValid(), isTrue);
        expect(settings.getValidationErrors(), isEmpty);
      });
    });

    group('warnings', () {
      test('should warn about high temperature', () {
        final settings = const GenerationSettings(
          temperature: 1.8,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('High temperature')));
      });

      test('should warn about very low temperature', () {
        final settings = const GenerationSettings(
          temperature: 0.05,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('Very low temperature')));
      });

      test('should warn about very low topP', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.05,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('Very low Top P')));
      });

      test('should warn about very low topK', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 3,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 4,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('Very low Top K')));
      });

      test('should warn about high repeat penalty', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.8,
          maxTokens: -1,
          numThread: 4,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('High repeat penalty')));
      });

      test('should warn about very low max tokens', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: 20,
          numThread: 4,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('Very low max tokens')));
      });

      test('should warn about high thread count', () {
        final settings = const GenerationSettings(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
          maxTokens: -1,
          numThread: 12,
        );
        
        final warnings = settings.getWarnings();
        expect(warnings, contains(contains('High thread count')));
      });

      test('should return no warnings for default settings', () {
        final settings = GenerationSettings.defaults();
        
        expect(settings.getWarnings(), isEmpty);
      });
    });

    group('toOllamaOptions', () {
      test('should return empty map for default settings', () {
        final settings = GenerationSettings.defaults();
        final options = settings.toOllamaOptions();
        
        expect(options, isEmpty);
      });

      test('should include only non-default values', () {
        final settings = GenerationSettings.defaults().copyWith(
          temperature: 0.8,
          topK: 50,
        );
        
        final options = settings.toOllamaOptions();
        
        expect(options['temperature'], 0.8);
        expect(options['top_k'], 50);
        expect(options.containsKey('top_p'), isFalse); // Default value
        expect(options.containsKey('repeat_penalty'), isFalse); // Default value
      });

      test('should map field names correctly', () {
        final settings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 8,
        );
        
        final options = settings.toOllamaOptions();
        
        expect(options['temperature'], 0.8);
        expect(options['top_p'], 0.95);
        expect(options['top_k'], 50);
        expect(options['repeat_penalty'], 1.2);
        expect(options['num_predict'], 1000);
        expect(options['num_thread'], 8);
      });

      test('should not include maxTokens when -1 (unlimited)', () {
        final settings = GenerationSettings.defaults().copyWith(
          temperature: 0.8,
          maxTokens: -1,
        );
        
        final options = settings.toOllamaOptions();
        
        expect(options['temperature'], 0.8);
        expect(options.containsKey('num_predict'), isFalse);
      });

      test('should not include maxTokens when 0 or negative', () {
        final settings = GenerationSettings.defaults().copyWith(
          temperature: 0.8,
          maxTokens: 0,
        );
        
        final options = settings.toOllamaOptions();
        
        expect(options['temperature'], 0.8);
        expect(options.containsKey('num_predict'), isFalse);
      });
    });

    group('validated factory', () {
      test('should clamp values to valid ranges', () {
        final settings = GenerationSettings.validated(
          temperature: 3.0, // Will be clamped to 2.0
          topP: 1.5, // Will be clamped to 1.0
          topK: 0, // Will be clamped to 1
          repeatPenalty: 0.3, // Will be clamped to 0.5
          maxTokens: 5000, // Will be clamped to 4096
          numThread: 20, // Will be clamped to 16
        );
        
        expect(settings.temperature, 2.0);
        expect(settings.topP, 1.0);
        expect(settings.topK, 1);
        expect(settings.repeatPenalty, 0.5);
        expect(settings.maxTokens, 4096);
        expect(settings.numThread, 16);
        expect(settings.isValid(), isTrue);
      });

      test('should preserve -1 for unlimited maxTokens', () {
        final settings = GenerationSettings.validated(
          maxTokens: -1,
        );
        
        expect(settings.maxTokens, -1);
        expect(settings.isValid(), isTrue);
      });

      test('should use defaults for null values', () {
        final settings = GenerationSettings.validated();
        final defaults = GenerationSettings.defaults();
        
        expect(settings, equals(defaults));
      });
    });

    group('equality and hashCode', () {
      test('should be equal when all fields match', () {
        final settings1 = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 8,
        );
        
        final settings2 = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 8,
        );
        
        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      });

      test('should not be equal when fields differ', () {
        final settings1 = GenerationSettings.defaults();
        final settings2 = settings1.copyWith(temperature: 0.8);
        
        expect(settings1, isNot(equals(settings2)));
        expect(settings1.hashCode, isNot(equals(settings2.hashCode)));
      });
    });

    group('toString', () {
      test('should include all field values', () {
        final settings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 8,
        );
        
        final str = settings.toString();
        
        expect(str, contains('0.8'));
        expect(str, contains('0.95'));
        expect(str, contains('50'));
        expect(str, contains('1.2'));
        expect(str, contains('1000'));
        expect(str, contains('8'));
      });
    });

    group('edge cases', () {
      test('should handle boundary values correctly', () {
        final settings = const GenerationSettings(
          temperature: 0.0, // Minimum
          topP: 1.0, // Maximum
          topK: 1, // Minimum
          repeatPenalty: 2.0, // Maximum
          maxTokens: 4096, // Maximum
          numThread: 16, // Maximum
        );
        
        expect(settings.isValid(), isTrue);
        expect(settings.getValidationErrors(), isEmpty);
      });

      test('should handle precision for double values', () {
        final settings = const GenerationSettings(
          temperature: 0.123456789,
          topP: 0.987654321,
          topK: 40,
          repeatPenalty: 1.111111111,
          maxTokens: -1,
          numThread: 4,
        );
        
        expect(settings.isValid(), isTrue);
        
        final json = settings.toJson();
        final restored = GenerationSettings.fromJson(json);
        
        expect(restored.temperature, closeTo(0.123456789, 0.000000001));
        expect(restored.topP, closeTo(0.987654321, 0.000000001));
        expect(restored.repeatPenalty, closeTo(1.111111111, 0.000000001));
      });
    });
  });
}