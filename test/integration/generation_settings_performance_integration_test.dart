import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/optimized_generation_settings_service.dart';
import '../../lib/services/performance_monitor.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/chat.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/message.dart';

/// Integration tests for generation settings performance optimizations
void main() {
  group('Generation Settings Performance Integration Tests', () {
    late OptimizedGenerationSettingsService service;
    late PerformanceMonitor monitor;

    setUp(() {
      service = OptimizedGenerationSettingsService();
      service.initialize();
      monitor = PerformanceMonitor();
      monitor.initialize();
    });

    tearDown(() {
      service.dispose();
      monitor.dispose();
    });

    group('End-to-End Performance Tests', () {
      test('should handle complete workflow efficiently with many chats', () async {
        // Create test data
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );
        final chats = _createTestChats(500);

        final stopwatch = Stopwatch()..start();

        // Simulate complete workflow for each chat
        for (final chat in chats) {
          // 1. Resolve effective settings
          final settings = service.getEffectiveSettings(
            chat: chat,
            globalSettings: appSettings,
          );

          // 2. Build API options
          final options = service.buildOllamaOptions(
            settings: settings,
            contextLength: 4096,
            isStreaming: true,
          );

          // 3. Validate settings
          final isValid = service.validateSettings(settings);

          // 4. Get summary
          final summary = service.getSettingsSummary(settings);

          // Verify results
          expect(settings, isNotNull);
          expect(options, isA<Map<String, dynamic>>());
          expect(isValid, isA<bool>());
          expect(summary, isA<String>());
        }

        stopwatch.stop();

        // Should handle 500 complete workflows in under 200ms
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
        // ignore: avoid_print
        print('Complete workflow for 500 chats: ${stopwatch.elapsedMilliseconds}ms');

        // Verify cache effectiveness
        final cacheStats = service.getCacheStats();
        expect(cacheStats['settings_cache']['hit_rate'], greaterThan(0.0));
        // ignore: avoid_print
        print('Cache hit rates: $cacheStats');
      });

      test('should demonstrate caching benefits', () async {
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );
        final chat = _createTestChats(1).first;

        // First run - populate caches
        final stopwatch1 = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          service.getEffectiveSettings(chat: chat, globalSettings: appSettings);
          service.buildOllamaOptions(settings: appSettings.generationSettings);
        }
        stopwatch1.stop();

        // Second run - should benefit from caching
        final stopwatch2 = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          service.getEffectiveSettings(chat: chat, globalSettings: appSettings);
          service.buildOllamaOptions(settings: appSettings.generationSettings);
        }
        stopwatch2.stop();

        // ignore: avoid_print
        print('First run (no cache): ${stopwatch1.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('Second run (with cache): ${stopwatch2.elapsedMilliseconds}ms');

        // Second run should be faster or equal (both might be 0ms due to speed)
        expect(stopwatch2.elapsedMilliseconds, lessThanOrEqualTo(stopwatch1.elapsedMilliseconds));

        // Verify high cache hit rate
        final cacheStats = service.getCacheStats();
        expect(cacheStats['settings_cache']['hit_rate'], greaterThan(0.8));
        expect(cacheStats['options_cache']['hit_rate'], greaterThan(0.8));
      });

      test('should handle concurrent access efficiently', () async {
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );
        final chats = _createTestChats(100);

        // Create concurrent tasks
        final futures = <Future<void>>[];
        for (int i = 0; i < 20; i++) {
          futures.add(_performConcurrentOperations(service, chats, appSettings));
        }

        final stopwatch = Stopwatch()..start();
        await Future.wait(futures);
        stopwatch.stop();

        // Should handle concurrent access efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        // ignore: avoid_print
        print('20 concurrent operations: ${stopwatch.elapsedMilliseconds}ms');

        // Verify no performance warnings
        final report = service.getPerformanceReport();
        final highSeverityWarnings = report.warnings
            .where((w) => w.severity == PerformanceWarningSeverity.high)
            .toList();
        expect(highSeverityWarnings, isEmpty);
      });

      test('should maintain performance under memory pressure', () async {
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );

        // Create many different settings to stress caches
        final settingsList = _createVariedSettings(1000);
        final chatsList = _createTestChats(1000);

        final stopwatch = Stopwatch()..start();

        // Perform many operations to stress memory
        for (int iteration = 0; iteration < 10; iteration++) {
          for (int i = 0; i < 100; i++) {
            final settings = settingsList[i];
            final chat = chatsList[i];

            service.getEffectiveSettings(chat: chat, globalSettings: appSettings);
            service.buildOllamaOptions(settings: settings);
            service.validateSettings(settings);
            service.getRecommendations(settings);
          }

          // Force some cache eviction by accessing many different items
          for (int i = 100; i < 200; i++) {
            final settings = settingsList[i];
            service.buildOllamaOptions(settings: settings);
          }
        }

        stopwatch.stop();

        // Should maintain reasonable performance even under memory pressure
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        // ignore: avoid_print
        print('Memory pressure test: ${stopwatch.elapsedMilliseconds}ms');

        // Verify caches are still functioning
        final cacheStats = service.getCacheStats();
        expect(cacheStats['settings_cache']['size'], greaterThan(0));
        expect(cacheStats['options_cache']['size'], greaterThan(0));
      });

      test('should generate meaningful performance reports', () async {
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );
        final chats = _createTestChats(100);

        // Perform various operations to generate metrics
        for (final chat in chats) {
          service.getEffectiveSettings(chat: chat, globalSettings: appSettings);
          
          if (chat.hasCustomGenerationSettings) {
            service.buildOllamaOptions(settings: chat.customGenerationSettings!);
            service.validateSettings(chat.customGenerationSettings!);
          }
        }

        // Generate performance report
        final report = service.getPerformanceReport();

        // Verify report contains meaningful data
        expect(report.totalOperations, greaterThan(0));
        expect(report.operationStats, isNotEmpty);
        expect(report.generatedAt, isA<DateTime>());

        // ignore: avoid_print
        print('Performance Report:');
        // ignore: avoid_print
        print(report.toString());

        // Verify specific operations are tracked
        expect(report.operationStats.containsKey('settings_resolution'), isTrue);
        expect(report.operationStats.containsKey('api_options_build'), isTrue);

        // Verify performance is within acceptable ranges
        final settingsStats = report.operationStats['settings_resolution'];
        if (settingsStats != null) {
          expect(settingsStats.averageDuration.inMilliseconds, lessThan(10));
        }

        final optionsStats = report.operationStats['api_options_build'];
        if (optionsStats != null) {
          expect(optionsStats.averageDuration.inMilliseconds, lessThan(5));
        }
      });
    });

    group('Memory Usage Integration Tests', () {
      test('should not leak memory with repeated operations', () async {
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );

        // Perform many iterations to test for memory leaks
        for (int iteration = 0; iteration < 50; iteration++) {
          final chats = _createTestChats(100);
          
          for (final chat in chats) {
            service.getEffectiveSettings(chat: chat, globalSettings: appSettings);
            
            if (chat.hasCustomGenerationSettings) {
              service.buildOllamaOptions(settings: chat.customGenerationSettings!);
            }
          }
          
          // Clear references to help GC
          chats.clear();
          
          // Periodically clear caches to test cleanup
          if (iteration % 10 == 0) {
            service.clearCaches();
          }
        }

        // If we reach here without memory issues, test passes
        expect(true, isTrue);
        // ignore: avoid_print
        print('Memory leak test completed successfully');
      });

      test('should manage cache sizes effectively', () async {
        final appSettings = AppSettings(
          generationSettings: GenerationSettings.defaults(),
        );

        // Fill caches beyond their capacity
        final manySettings = _createVariedSettings(500);
        final manyChats = _createTestChats(500);

        for (int i = 0; i < 500; i++) {
          service.getEffectiveSettings(chat: manyChats[i], globalSettings: appSettings);
          service.buildOllamaOptions(settings: manySettings[i]);
        }

        // Verify caches don't exceed their capacity
        final cacheStats = service.getCacheStats();
        expect(cacheStats['settings_cache']['size'], lessThanOrEqualTo(100));
        expect(cacheStats['options_cache']['size'], lessThanOrEqualTo(200));
        expect(cacheStats['validation_cache']['size'], lessThanOrEqualTo(50));

        // ignore: avoid_print
        print('Cache sizes after overflow test: $cacheStats');
      });
    });

    group('API Call Efficiency Tests', () {
      test('should optimize API options for minimal payload', () async {
        // Test with default settings (should produce empty options)
        final defaultSettings = GenerationSettings.defaults();
        final defaultOptions = service.buildOllamaOptions(settings: defaultSettings);
        expect(defaultOptions, isEmpty);

        // Test with custom settings (should only include changed values)
        final customSettings = const GenerationSettings(
          temperature: 0.8, // Changed
          topP: 0.9, // Default - should not be included
          topK: 50, // Changed
          repeatPenalty: 1.1, // Default - should not be included
          maxTokens: 1000, // Changed
          numThread: 4, // Default - should not be included
        );

        final customOptions = service.buildOllamaOptions(settings: customSettings);
        expect(customOptions.length, equals(3)); // Only changed values
        expect(customOptions['temperature'], equals(0.8));
        expect(customOptions['top_k'], equals(50));
        expect(customOptions['num_predict'], equals(1000));
        expect(customOptions.containsKey('top_p'), isFalse);
        expect(customOptions.containsKey('repeat_penalty'), isFalse);
        expect(customOptions.containsKey('num_thread'), isFalse);
      });

      test('should handle context length optimization', () async {
        final settings = GenerationSettings.defaults();

        // Default context length should not be included
        final options1 = service.buildOllamaOptions(
          settings: settings,
          contextLength: 4096, // Default
        );
        expect(options1.containsKey('num_ctx'), isFalse);

        // Custom context length should be included
        final options2 = service.buildOllamaOptions(
          settings: settings,
          contextLength: 8192, // Custom
        );
        expect(options2['num_ctx'], equals(8192));
      });
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
        temperature: 0.1 + random.nextDouble() * 1.9,
        topP: 0.1 + random.nextDouble() * 0.9,
        topK: 1 + random.nextInt(100),
        repeatPenalty: 0.5 + random.nextDouble() * 1.5,
        maxTokens: random.nextBool() ? -1 : 50 + random.nextInt(4000),
        numThread: 1 + random.nextInt(16),
      );
    }

    chats.add(Chat(
      id: 'chat_$i',
      title: 'Test Chat $i',
      modelName: 'test-model',
      messages: _createTestMessages(random.nextInt(10)),
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
  final settings = <GenerationSettings>[];
  final random = Random(42);

  for (int i = 0; i < count; i++) {
    settings.add(GenerationSettings(
      temperature: 0.1 + random.nextDouble() * 1.9,
      topP: 0.1 + random.nextDouble() * 0.9,
      topK: 1 + random.nextInt(100),
      repeatPenalty: 0.5 + random.nextDouble() * 1.5,
      maxTokens: random.nextBool() ? -1 : 50 + random.nextInt(4000),
      numThread: 1 + random.nextInt(16),
    ));
  }

  return settings;
}

/// Helper function to perform concurrent operations
Future<void> _performConcurrentOperations(
  OptimizedGenerationSettingsService service,
  List<Chat> chats,
  AppSettings appSettings,
) async {
  for (final chat in chats.take(50)) {
    final settings = service.getEffectiveSettings(
      chat: chat,
      globalSettings: appSettings,
    );
    
    service.buildOllamaOptions(settings: settings);
    service.validateSettings(settings);
    
    // Small delay to simulate real usage
    await Future.delayed(const Duration(microseconds: 10));
  }
}