import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/generation_settings_service.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/chat.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/message.dart';

/// Performance tests for generation settings system
void main() {
  group('Generation Settings Performance Tests', () {
    late AppSettings defaultAppSettings;
    late List<Chat> testChats;

    setUp(() {
      defaultAppSettings = AppSettings(
        generationSettings: GenerationSettings.defaults(),
      );

      // Create test chats with varying custom settings
      testChats = _createTestChats(1000);
    });

    group('Settings Resolution Performance', () {
      test('should resolve correct settings for different chat types', () {
        final stopwatch = Stopwatch()..start();
        
        var chatsWithCustomSettings = 0;
        var chatsWithGlobalSettings = 0;

        // Test resolution for all chats and verify correctness
        for (final chat in testChats) {
          final effectiveSettings = GenerationSettingsService.getEffectiveSettings(
            chat: chat,
            globalSettings: defaultAppSettings,
          );
          
          // Verify we got valid settings
          expect(effectiveSettings, isNotNull);
          expect(effectiveSettings.isValid(), isTrue);
          
          // Verify correct settings are returned based on chat type
          if (chat.hasCustomGenerationSettings) {
            expect(effectiveSettings, equals(chat.customGenerationSettings));
            chatsWithCustomSettings++;
          } else {
            expect(effectiveSettings, equals(defaultAppSettings.generationSettings));
            chatsWithGlobalSettings++;
          }
        }

        stopwatch.stop();

        // Verify we tested both types of chats
        expect(chatsWithCustomSettings, greaterThan(0));
        expect(chatsWithGlobalSettings, greaterThan(0));
        
        // Performance should be reasonable (not a hard threshold)
        final avgTimePerChat = stopwatch.elapsedMicroseconds / testChats.length;
        expect(avgTimePerChat, lessThan(100)); // Less than 100 microseconds per chat
        
        // ignore: avoid_print
        print('Settings resolution: ${testChats.length} chats in ${stopwatch.elapsedMilliseconds}ms (${avgTimePerChat.toStringAsFixed(1)}μs/chat)');
        // ignore: avoid_print
        print('  Custom settings: $chatsWithCustomSettings, Global settings: $chatsWithGlobalSettings');
      });

      test('should maintain consistent performance under load', () {
        final chat = testChats.first;
        final iterations = 10000;
        final timings = <int>[];
        
        // Measure individual call timings
        for (int i = 0; i < iterations; i++) {
          final stopwatch = Stopwatch()..start();
          final settings = GenerationSettingsService.getEffectiveSettings(
            chat: chat,
            globalSettings: defaultAppSettings,
          );
          stopwatch.stop();
          
          // Verify correctness on every call
          expect(settings, isNotNull);
          expect(settings.isValid(), isTrue);
          
          timings.add(stopwatch.elapsedMicroseconds);
        }

        // Analyze performance characteristics
        timings.sort();
        final avgTime = timings.fold<int>(0, (sum, time) => sum + time) / timings.length;
        final medianTime = timings[timings.length ~/ 2];
        final p95Time = timings[(timings.length * 0.95).floor()];
        final maxTime = timings.last;
        
        // Performance should be consistent (reasonable variance)
        final variance = maxTime - timings.first;
        expect(variance, lessThan(1000)); // Max variance should be < 1000 microseconds (reasonable for fast operations)
        
        // ignore: avoid_print
        print('Performance consistency over $iterations calls:');
        // ignore: avoid_print
        print('  Avg: ${avgTime.toStringAsFixed(1)}μs, Median: $medianTimeμs, P95: $p95Timeμs, Max: $maxTimeμs');
      });

      test('should demonstrate object reuse and consistency', () {
        final chatWithCustom = testChats.firstWhere((c) => c.hasCustomGenerationSettings);
        final chatWithoutCustom = testChats.firstWhere((c) => !c.hasCustomGenerationSettings);
        
        // Test that same settings objects are returned for same inputs
        final settings1a = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithCustom,
          globalSettings: defaultAppSettings,
        );
        final settings1b = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithCustom,
          globalSettings: defaultAppSettings,
        );
        
        final settings2a = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithoutCustom,
          globalSettings: defaultAppSettings,
        );
        final settings2b = GenerationSettingsService.getEffectiveSettings(
          chat: chatWithoutCustom,
          globalSettings: defaultAppSettings,
        );

        // Verify correctness
        expect(settings1a, equals(chatWithCustom.customGenerationSettings));
        expect(settings1b, equals(chatWithCustom.customGenerationSettings));
        expect(settings2a, equals(defaultAppSettings.generationSettings));
        expect(settings2b, equals(defaultAppSettings.generationSettings));
        
        // Test consistency - same inputs should return equal objects
        expect(settings1a, equals(settings1b));
        expect(settings2a, equals(settings2b));
        
        // Test difference - different inputs should return different objects
        expect(settings1a, isNot(equals(settings2a)));
        
        // ignore: avoid_print
        print('Object consistency verified: same inputs return equal objects');
      });
    });

    group('API Options Building Performance', () {
      test('should build correct API options for different settings', () {
        final settings = _createVariedSettings(1000);
        final stopwatch = Stopwatch()..start();
        
        var emptyOptionsCount = 0;
        var nonEmptyOptionsCount = 0;
        final optionsSizes = <int>[];

        for (final setting in settings) {
          final options = GenerationSettingsService.buildOllamaOptions(
            settings: setting,
            contextLength: 4096,
            isStreaming: true,
          );
          
          // Verify options are valid
          expect(options, isA<Map<String, dynamic>>());
          
          // Track statistics
          if (options.isEmpty) {
            emptyOptionsCount++;
          } else {
            nonEmptyOptionsCount++;
            optionsSizes.add(options.length);
            
            // Verify that only valid Ollama options are included
            for (final key in options.keys) {
              expect(['temperature', 'top_p', 'top_k', 'repeat_penalty', 'num_predict', 'num_thread', 'num_ctx'], contains(key));
            }
          }
        }

        stopwatch.stop();
        
        // Should have non-empty options (since we're creating varied settings)
        expect(nonEmptyOptionsCount, greaterThan(0));
        // Note: emptyOptionsCount might be 0 if all generated settings differ from defaults
        
        final avgOptionsSize = optionsSizes.isNotEmpty 
            ? optionsSizes.fold<int>(0, (sum, size) => sum + size) / optionsSizes.length
            : 0;
        
        // ignore: avoid_print
        print('API options building: ${settings.length} settings in ${stopwatch.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('  Empty options: $emptyOptionsCount, Non-empty: $nonEmptyOptionsCount, Avg size: ${avgOptionsSize.toStringAsFixed(1)}');
      });

      test('should generate empty options for default settings', () {
        final defaultSettings = GenerationSettings.defaults();
        
        // Test multiple times to ensure consistency
        for (int i = 0; i < 100; i++) {
          final options = GenerationSettingsService.buildOllamaOptions(
            settings: defaultSettings,
          );
          expect(options, isEmpty); // Default settings should always produce empty options
        }
        
        // Test with context length that matches default
        final optionsWithDefaultContext = GenerationSettingsService.buildOllamaOptions(
          settings: defaultSettings,
          contextLength: 4096, // Default context length
        );
        expect(optionsWithDefaultContext, isEmpty);
        
        // Test with non-default context length
        final optionsWithCustomContext = GenerationSettingsService.buildOllamaOptions(
          settings: defaultSettings,
          contextLength: 8192, // Non-default context length
        );
        expect(optionsWithCustomContext.length, equals(1));
        expect(optionsWithCustomContext['num_ctx'], equals(8192));
        
        // ignore: avoid_print
        print('Default settings optimization: empty options verified');
      });

      test('should optimize payload size by excluding defaults', () {
        final defaultSettings = GenerationSettings.defaults();
        final customSettings = const GenerationSettings(
          temperature: 0.8,  // Non-default
          topP: 0.9,         // Default - should be excluded
          topK: 50,          // Non-default
          repeatPenalty: 1.1, // Default - should be excluded
          maxTokens: 1000,   // Non-default
          numThread: 4,      // Default - should be excluded
        );

        final iterations = 5000;
        var totalDefaultOptionsSize = 0;
        var totalCustomOptionsSize = 0;

        final stopwatch = Stopwatch()..start();

        // Test with default settings (should produce empty options)
        for (int i = 0; i < iterations; i++) {
          final options = GenerationSettingsService.buildOllamaOptions(
            settings: defaultSettings,
          );
          totalDefaultOptionsSize += options.length;
          expect(options, isEmpty); // Should always be empty for defaults
        }

        // Test with custom settings (should only include non-defaults)
        for (int i = 0; i < iterations; i++) {
          final options = GenerationSettingsService.buildOllamaOptions(
            settings: customSettings,
          );
          totalCustomOptionsSize += options.length;
          
          // Should only include non-default values
          expect(options.containsKey('temperature'), isTrue);
          expect(options.containsKey('top_k'), isTrue);
          expect(options.containsKey('num_predict'), isTrue);
          
          // Should exclude default values
          expect(options.containsKey('top_p'), isFalse);
          expect(options.containsKey('repeat_penalty'), isFalse);
          expect(options.containsKey('num_thread'), isFalse);
          
          expect(options.length, equals(3)); // Only 3 non-default values
        }

        stopwatch.stop();

        final avgDefaultSize = totalDefaultOptionsSize / iterations;
        final avgCustomSize = totalCustomOptionsSize / iterations;
        
        expect(avgDefaultSize, equals(0.0)); // Always empty for defaults
        expect(avgCustomSize, equals(3.0)); // Always 3 for this custom setting
        
        // ignore: avoid_print
        print('Payload optimization: ${iterations * 2} builds in ${stopwatch.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('  Default settings payload: $avgDefaultSize keys, Custom settings: $avgCustomSize keys');
      });
    });

    group('Settings Validation Performance', () {
      test('should correctly validate settings with real edge cases', () {
        // Test with a few known valid settings first
        final knownValidSettings = [
          GenerationSettings.defaults(),
          const GenerationSettings(
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            repeatPenalty: 1.1,
            maxTokens: 1000,
            numThread: 4,
          ),
        ];
        
        // Verify known valid settings are actually valid
        for (final setting in knownValidSettings) {
          final isValid = GenerationSettingsService.validateSettings(setting);
          final errors = GenerationSettingsService.getValidationErrors(setting);
          expect(isValid, isTrue, reason: 'Known valid setting should be valid: $errors');
          expect(errors, isEmpty, reason: 'Known valid setting should have no errors');
        }
        
        final settings = _createVariedSettings(100); // Smaller set for debugging
        final stopwatch = Stopwatch()..start();

        var validCount = 0;
        var invalidCount = 0;
        final validationErrors = <String>[];
        final firstInvalidSetting = <GenerationSettings>[];

        for (final setting in settings) {
          final isValid = GenerationSettingsService.validateSettings(setting);
          final errors = GenerationSettingsService.getValidationErrors(setting);
          
          if (isValid) {
            validCount++;
            expect(errors, isEmpty); // Valid settings should have no errors
          } else {
            invalidCount++;
            expect(errors, isNotEmpty); // Invalid settings should have errors
            validationErrors.addAll(errors);
            if (firstInvalidSetting.isEmpty) {
              firstInvalidSetting.add(setting);
            }
          }
          
          // Verify consistency between validation methods
          expect(isValid, equals(errors.isEmpty));
        }

        stopwatch.stop();

        // Debug output
        // ignore: avoid_print
        print('Validation results: Valid=$validCount, Invalid=$invalidCount');
        if (invalidCount > 0 && firstInvalidSetting.isNotEmpty) {
          // ignore: avoid_print
          print('First invalid setting: ${firstInvalidSetting.first}');
          // ignore: avoid_print
          print('Its errors: ${GenerationSettingsService.getValidationErrors(firstInvalidSetting.first)}');
        }

        // Should have valid settings (our generator should create mostly valid settings)
        expect(validCount + invalidCount, equals(100));
        expect(validCount, greaterThan(0));
        
        final avgErrorsPerInvalid = invalidCount > 0 ? validationErrors.length / invalidCount : 0;
        
        // ignore: avoid_print
        print('Validation: 1000 settings in ${stopwatch.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('  Valid: $validCount, Invalid: $invalidCount, Avg errors: ${avgErrorsPerInvalid.toStringAsFixed(1)}');
      });

      test('should properly detect invalid settings', () {
        // Create specifically invalid settings
        final invalidSettings = [
          const GenerationSettings(temperature: -1.0, topP: 0.9, topK: 40, repeatPenalty: 1.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 3.0, topP: 0.9, topK: 40, repeatPenalty: 1.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: -0.5, topK: 40, repeatPenalty: 1.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 1.5, topK: 40, repeatPenalty: 1.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 0, repeatPenalty: 1.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 150, repeatPenalty: 1.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 0.1, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 3.0, maxTokens: -1, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 1.1, maxTokens: 0, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 1.1, maxTokens: 5000, numThread: 4),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 1.1, maxTokens: -1, numThread: 0),
          const GenerationSettings(temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 1.1, maxTokens: -1, numThread: 20),
        ];

        var invalidCount = 0;
        final allErrors = <String>[];

        for (final setting in invalidSettings) {
          final isValid = GenerationSettingsService.validateSettings(setting);
          final errors = GenerationSettingsService.getValidationErrors(setting);
          
          expect(isValid, isFalse); // All should be invalid
          expect(errors, isNotEmpty); // All should have errors
          
          invalidCount++;
          allErrors.addAll(errors);
        }

        expect(invalidCount, equals(invalidSettings.length));
        expect(allErrors.length, greaterThanOrEqualTo(invalidSettings.length)); // Should have at least one error per invalid setting
        
        // ignore: avoid_print
        print('Invalid settings test: ${invalidSettings.length} invalid settings generated ${allErrors.length} errors');
      });

      test('should handle validation errors efficiently', () {
        final invalidSettings = _createInvalidSettings(500);
        final stopwatch = Stopwatch()..start();

        for (final setting in invalidSettings) {
          final errors = GenerationSettingsService.getValidationErrors(setting);
          expect(errors, isNotEmpty);
        }

        stopwatch.stop();

        // Should process 500 invalid settings in under 50ms
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
        // ignore: avoid_print
        print('Processing 500 invalid settings: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Memory Usage Tests', () {
      test('should not leak memory with repeated operations', () {
        var totalChatsProcessed = 0;
        var totalOperations = 0;
        
        // Test for memory leaks by performing many operations
        for (int iteration = 0; iteration < 100; iteration++) {
          final chats = _createTestChats(100);
          totalChatsProcessed += chats.length;
          
          // Perform various operations
          for (final chat in chats) {
            final settings = GenerationSettingsService.getEffectiveSettings(
              chat: chat,
              globalSettings: defaultAppSettings,
            );
            totalOperations++;
            
            // Verify correctness
            expect(settings, isNotNull);
            expect(settings.isValid(), isTrue);
            
            if (chat.hasCustomGenerationSettings) {
              final options = GenerationSettingsService.buildOllamaOptions(
                settings: chat.customGenerationSettings!,
              );
              expect(options, isA<Map<String, dynamic>>());
              totalOperations++;
            }
          }
          
          // Force garbage collection hint
          chats.clear();
        }

        // Verify we actually processed a significant amount of data
        expect(totalChatsProcessed, equals(10000));
        expect(totalOperations, greaterThan(10000));
        
        // ignore: avoid_print
        print('Memory usage test: processed $totalChatsProcessed chats, $totalOperations operations');
      });

      test('should handle large numbers of custom settings efficiently', () {
        final chatsWithCustomSettings = _createTestChats(5000)
            .where((chat) => chat.hasCustomGenerationSettings)
            .toList();

        expect(chatsWithCustomSettings.length, greaterThan(1000));

        final stopwatch = Stopwatch()..start();

        // Process all chats with custom settings
        for (final chat in chatsWithCustomSettings) {
          final settings = GenerationSettingsService.getEffectiveSettings(
            chat: chat,
            globalSettings: defaultAppSettings,
          );
          
          final options = GenerationSettingsService.buildOllamaOptions(
            settings: settings,
          );
          
          final summary = GenerationSettingsService.getSettingsSummary(settings);
          
          // Verify results
          expect(settings, isNotNull);
          expect(options, isA<Map<String, dynamic>>());
          expect(summary, isA<String>());
        }

        stopwatch.stop();

        // Should handle large numbers efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
        // ignore: avoid_print
        print('Processing ${chatsWithCustomSettings.length} custom settings: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Concurrent Access Performance', () {
      test('should handle concurrent settings resolution correctly', () async {
        final futures = <Future<List<GenerationSettings>>>[];
        final expectedResults = <List<GenerationSettings>>[];

        // Pre-calculate expected results for verification
        for (int i = 0; i < 50; i++) {
          final chatSubset = testChats.sublist(i * 20, (i + 1) * 20);
          final expected = chatSubset.map((chat) => 
            GenerationSettingsService.getEffectiveSettings(
              chat: chat,
              globalSettings: defaultAppSettings,
            )
          ).toList();
          expectedResults.add(expected);
        }

        // Create 50 concurrent tasks
        for (int i = 0; i < 50; i++) {
          futures.add(_performConcurrentSettingsOperations(testChats.sublist(i * 20, (i + 1) * 20)));
        }

        final stopwatch = Stopwatch()..start();
        final results = await Future.wait(futures);
        stopwatch.stop();

        // Verify all results are correct despite concurrent access
        for (int i = 0; i < results.length; i++) {
          expect(results[i].length, equals(expectedResults[i].length));
          for (int j = 0; j < results[i].length; j++) {
            expect(results[i][j], equals(expectedResults[i][j]));
          }
        }

        // ignore: avoid_print
        print('Concurrent access: 50 tasks × 20 chats = 1000 operations in ${stopwatch.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('  All results verified correct despite concurrency');
      });
    });

    group('Settings Comparison Performance', () {
      test('should accurately detect differences between settings', () {
        final settings1 = _createVariedSettings(500);
        final settings2 = _createVariedSettingsWithSeed(500, 123); // Different seed
        
        var identicalPairs = 0;
        var differentPairs = 0;
        var totalDifferences = 0;
        
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 500; i++) {
          final differences = GenerationSettingsService.compareSettings(
            settings1[i],
            settings2[i],
          );
          
          expect(differences, isA<Map<String, dynamic>>());
          
          if (differences.isEmpty) {
            identicalPairs++;
            // Verify they are actually identical
            expect(settings1[i], equals(settings2[i]));
          } else {
            differentPairs++;
            totalDifferences += differences.length;
            
            // Verify each reported difference is actually different
            for (final key in differences.keys) {
              final diff = differences[key] as Map<String, dynamic>;
              expect(diff['from'], isNot(equals(diff['to'])));
            }
          }
        }

        stopwatch.stop();
        
        final avgDifferencesPerPair = differentPairs > 0 ? totalDifferences / differentPairs : 0;
        
        // ignore: avoid_print
        print('Settings comparison: 500 pairs in ${stopwatch.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('  Identical: $identicalPairs, Different: $differentPairs, Avg differences: ${avgDifferencesPerPair.toStringAsFixed(1)}');
      });

      test('should handle edge cases in settings comparison', () {
        final defaultSettings = GenerationSettings.defaults();
        final customSettings = const GenerationSettings(
          temperature: 1.5,
          topP: 0.8,
          topK: 20,
          repeatPenalty: 1.3,
          maxTokens: 500,
          numThread: 8,
        );
        
        // Test identical settings
        final identicalDiff = GenerationSettingsService.compareSettings(
          defaultSettings,
          defaultSettings,
        );
        expect(identicalDiff, isEmpty);
        
        // Test completely different settings
        final completeDiff = GenerationSettingsService.compareSettings(
          defaultSettings,
          customSettings,
        );
        expect(completeDiff.length, equals(6)); // All 6 properties should be different
        
        // Test partially different settings
        final partialCustom = defaultSettings.copyWith(temperature: 1.2, topK: 30);
        final partialDiff = GenerationSettingsService.compareSettings(
          defaultSettings,
          partialCustom,
        );
        expect(partialDiff.length, equals(2)); // Only temperature and topK should be different
        expect(partialDiff.containsKey('temperature'), isTrue);
        expect(partialDiff.containsKey('topK'), isTrue);
        
        // ignore: avoid_print
        print('Edge case testing: identical=${identicalDiff.length}, complete=${completeDiff.length}, partial=${partialDiff.length}');
      });
    });
  });

  group('Edge Cases and Boundary Conditions', () {
    test('should handle null and edge case inputs correctly', () {
      final defaultAppSettings = AppSettings(
        generationSettings: GenerationSettings.defaults(),
      );

      // Test with null chat
      final settingsForNull = GenerationSettingsService.getEffectiveSettings(
        chat: null,
        globalSettings: defaultAppSettings,
      );
      expect(settingsForNull, equals(defaultAppSettings.generationSettings));

      // Test with chat that has null custom settings
      final chatWithNullSettings = Chat(
        id: 'null_test',
        title: 'Null Settings Test',
        modelName: 'test-model',
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        customGenerationSettings: null,
      );

      final settingsForNullCustom = GenerationSettingsService.getEffectiveSettings(
        chat: chatWithNullSettings,
        globalSettings: defaultAppSettings,
      );
      expect(settingsForNullCustom, equals(defaultAppSettings.generationSettings));

      // Test with extreme settings values
      const extremeSettings = GenerationSettings(
        temperature: 2.0,    // Maximum
        topP: 1.0,          // Maximum
        topK: 100,          // Maximum
        repeatPenalty: 2.0, // Maximum
        maxTokens: 4096,    // Maximum
        numThread: 16,      // Maximum
      );

      final extremeOptions = GenerationSettingsService.buildOllamaOptions(
        settings: extremeSettings,
      );

      // Should include all non-default values
      expect(extremeOptions.length, equals(6));
      expect(extremeOptions['temperature'], equals(2.0));
      expect(extremeOptions['top_p'], equals(1.0));
      expect(extremeOptions['top_k'], equals(100));
      expect(extremeOptions['repeat_penalty'], equals(2.0));
      expect(extremeOptions['num_predict'], equals(4096));
      expect(extremeOptions['num_thread'], equals(16));

      // Test validation of extreme settings
      expect(GenerationSettingsService.validateSettings(extremeSettings), isTrue);

      // ignore: avoid_print
      print('Edge cases handled correctly: null inputs, extreme values');
    });

    test('should maintain data integrity under stress', () {
      final originalDefaults = GenerationSettings.defaults();
      final iterations = 10000;
      
      // Perform many operations that could potentially corrupt state
      for (int i = 0; i < iterations; i++) {
        final settings = GenerationSettings(
          temperature: (i % 20) / 10.0, // 0.0 to 1.9
          topP: (i % 10) / 10.0,        // 0.0 to 0.9
          topK: (i % 100) + 1,          // 1 to 100
          repeatPenalty: 0.5 + (i % 15) / 10.0, // 0.5 to 2.0
          maxTokens: i % 2 == 0 ? -1 : (i % 4000) + 1, // -1 or 1-4000
          numThread: (i % 16) + 1,      // 1 to 16
        );

        // Perform various operations
        GenerationSettingsService.buildOllamaOptions(settings: settings);
        GenerationSettingsService.validateSettings(settings);
        GenerationSettingsService.getSettingsSummary(settings);
        GenerationSettingsService.compareSettings(settings, originalDefaults);
      }

      // Verify defaults haven't been corrupted
      final currentDefaults = GenerationSettings.defaults();
      expect(currentDefaults, equals(originalDefaults));
      expect(currentDefaults.temperature, equals(0.7));
      expect(currentDefaults.topP, equals(0.9));
      expect(currentDefaults.topK, equals(40));
      expect(currentDefaults.repeatPenalty, equals(1.1));
      expect(currentDefaults.maxTokens, equals(-1));
      expect(currentDefaults.numThread, equals(4));

      // ignore: avoid_print
      print('Data integrity maintained through $iterations stress operations');
    });
  });
}

/// Helper function to create test chats with varied settings
List<Chat> _createTestChats(int count) {
  final chats = <Chat>[];
  final random = Random(42); // Fixed seed for reproducible tests

  for (int i = 0; i < count; i++) {
    GenerationSettings? customSettings;
    
    // 30% of chats have custom settings
    if (random.nextDouble() < 0.3) {
      customSettings = GenerationSettings(
        temperature: 0.1 + random.nextDouble() * 1.9, // 0.1 - 2.0
        topP: 0.1 + random.nextDouble() * 0.9, // 0.1 - 1.0
        topK: 1 + random.nextInt(100), // 1 - 100
        repeatPenalty: 0.5 + random.nextDouble() * 1.5, // 0.5 - 2.0
        maxTokens: random.nextBool() ? -1 : 1 + random.nextInt(4096), // -1 or 1-4096
        numThread: 1 + random.nextInt(16), // 1 - 16
      );
    }

    chats.add(Chat(
      id: 'chat_$i',
      title: 'Test Chat $i',
      modelName: 'test-model',
      messages: _createTestMessages(random.nextInt(20)), // 0-19 messages
      createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
      lastUpdatedAt: DateTime.now().subtract(Duration(hours: random.nextInt(24))),
      customGenerationSettings: customSettings,
    ));
  }

  return chats;
}

/// Helper function to create test messages
List<Message> _createTestMessages(int count) {
  final messages = <Message>[];

  for (int i = 0; i < count; i++) {
    messages.add(Message(
      id: 'msg_$i',
      content: 'Test message content $i',
      role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.now().subtract(Duration(minutes: count - i)),
    ));
  }

  return messages;
}

/// Helper function to create varied settings for testing
List<GenerationSettings> _createVariedSettings(int count) {
  return _createVariedSettingsWithSeed(count, 42);
}

/// Helper function to create varied settings with a specific seed
List<GenerationSettings> _createVariedSettingsWithSeed(int count, int seed) {
  final settings = <GenerationSettings>[];
  final random = Random(seed);

  for (int i = 0; i < count; i++) {
    settings.add(GenerationSettings(
      temperature: 0.1 + random.nextDouble() * 1.9,
      topP: 0.1 + random.nextDouble() * 0.9,
      topK: 1 + random.nextInt(100),
      repeatPenalty: 0.5 + random.nextDouble() * 1.5,
      maxTokens: random.nextBool() ? -1 : 1 + random.nextInt(4096),
      numThread: 1 + random.nextInt(16),
    ));
  }

  return settings;
}

/// Helper function to create invalid settings for testing
List<GenerationSettings> _createInvalidSettings(int count) {
  final settings = <GenerationSettings>[];

  for (int i = 0; i < count; i++) {
    // Create settings with intentionally invalid values
    settings.add(GenerationSettings(
      temperature: i % 2 == 0 ? -1.0 : 3.0, // Invalid range
      topP: i % 2 == 0 ? -0.5 : 1.5, // Invalid range
      topK: i % 2 == 0 ? 0 : 150, // Invalid range
      repeatPenalty: i % 2 == 0 ? 0.1 : 3.0, // Invalid range
      maxTokens: i % 2 == 0 ? 0 : 5000, // Invalid range
      numThread: i % 2 == 0 ? 0 : 20, // Invalid range
    ));
  }

  return settings;
}

/// Helper function to perform concurrent settings operations and return results
Future<List<GenerationSettings>> _performConcurrentSettingsOperations(List<Chat> chats) async {
  final appSettings = AppSettings(
    generationSettings: GenerationSettings.defaults(),
  );
  final results = <GenerationSettings>[];

  for (final chat in chats) {
    // Resolve effective settings
    final settings = GenerationSettingsService.getEffectiveSettings(
      chat: chat,
      globalSettings: appSettings,
    );
    results.add(settings);

    // Small delay to simulate real usage
    await Future.delayed(const Duration(microseconds: 5));
  }

  return results;
}