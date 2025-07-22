import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/generation_settings_service.dart';
import '../../lib/services/optimized_generation_settings_service.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/chat.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/message.dart';

/// Benchmark comparing original vs optimized generation settings service
void main() {
  group('Generation Settings Benchmark', () {
    late AppSettings appSettings;
    late List<Chat> testChats;
    late List<GenerationSettings> testSettings;

    setUpAll(() {
      appSettings = AppSettings(
        generationSettings: GenerationSettings.defaults(),
      );
      testChats = _createTestChats(1000);
      testSettings = _createVariedSettings(1000);
    });

    test('Benchmark: Settings Resolution', () {
      // Original service
      final stopwatch1 = Stopwatch()..start();
      for (final chat in testChats) {
        GenerationSettingsService.getEffectiveSettings(
          chat: chat,
          globalSettings: appSettings,
        );
      }
      stopwatch1.stop();

      // Optimized service
      final optimizedService = OptimizedGenerationSettingsService();
      optimizedService.initialize();
      
      final stopwatch2 = Stopwatch()..start();
      for (final chat in testChats) {
        optimizedService.getEffectiveSettings(
          chat: chat,
          globalSettings: appSettings,
        );
      }
      stopwatch2.stop();

      // Results
      // ignore: avoid_print
      print('Settings Resolution Benchmark (1000 chats):');
      // ignore: avoid_print
      print('  Original: ${stopwatch1.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Optimized: ${stopwatch2.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Improvement: ${((stopwatch1.elapsedMilliseconds - stopwatch2.elapsedMilliseconds) / stopwatch1.elapsedMilliseconds * 100).toStringAsFixed(1)}%');

      optimizedService.dispose();
    });

    test('Benchmark: API Options Building', () {
      // Original service
      final stopwatch1 = Stopwatch()..start();
      for (final settings in testSettings) {
        GenerationSettingsService.buildOllamaOptions(
          settings: settings,
          contextLength: 4096,
          isStreaming: true,
        );
      }
      stopwatch1.stop();

      // Optimized service
      final optimizedService = OptimizedGenerationSettingsService();
      optimizedService.initialize();
      
      final stopwatch2 = Stopwatch()..start();
      for (final settings in testSettings) {
        optimizedService.buildOllamaOptions(
          settings: settings,
          contextLength: 4096,
          isStreaming: true,
        );
      }
      stopwatch2.stop();

      // Results
      // ignore: avoid_print
      print('API Options Building Benchmark (1000 settings):');
      // ignore: avoid_print
      print('  Original: ${stopwatch1.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Optimized: ${stopwatch2.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Improvement: ${((stopwatch1.elapsedMilliseconds - stopwatch2.elapsedMilliseconds) / stopwatch1.elapsedMilliseconds * 100).toStringAsFixed(1)}%');

      optimizedService.dispose();
    });

    test('Benchmark: Settings Validation', () {
      // Original service
      final stopwatch1 = Stopwatch()..start();
      for (final settings in testSettings) {
        GenerationSettingsService.validateSettings(settings);
      }
      stopwatch1.stop();

      // Optimized service
      final optimizedService = OptimizedGenerationSettingsService();
      optimizedService.initialize();
      
      final stopwatch2 = Stopwatch()..start();
      for (final settings in testSettings) {
        optimizedService.validateSettings(settings);
      }
      stopwatch2.stop();

      // Results
      // ignore: avoid_print
      print('Settings Validation Benchmark (1000 settings):');
      // ignore: avoid_print
      print('  Original: ${stopwatch1.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Optimized: ${stopwatch2.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Improvement: ${((stopwatch1.elapsedMilliseconds - stopwatch2.elapsedMilliseconds) / stopwatch1.elapsedMilliseconds * 100).toStringAsFixed(1)}%');

      optimizedService.dispose();
    });

    test('Benchmark: Complete Workflow', () {
      // Original service workflow
      final stopwatch1 = Stopwatch()..start();
      for (final chat in testChats.take(500)) {
        final settings = GenerationSettingsService.getEffectiveSettings(
          chat: chat,
          globalSettings: appSettings,
        );
        GenerationSettingsService.buildOllamaOptions(settings: settings);
        GenerationSettingsService.validateSettings(settings);
        GenerationSettingsService.getSettingsSummary(settings);
      }
      stopwatch1.stop();

      // Optimized service workflow
      final optimizedService = OptimizedGenerationSettingsService();
      optimizedService.initialize();
      
      final stopwatch2 = Stopwatch()..start();
      for (final chat in testChats.take(500)) {
        final settings = optimizedService.getEffectiveSettings(
          chat: chat,
          globalSettings: appSettings,
        );
        optimizedService.buildOllamaOptions(settings: settings);
        optimizedService.validateSettings(settings);
        optimizedService.getSettingsSummary(settings);
      }
      stopwatch2.stop();

      // Results
      // ignore: avoid_print
      print('Complete Workflow Benchmark (500 chats):');
      // ignore: avoid_print
      print('  Original: ${stopwatch1.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Optimized: ${stopwatch2.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Improvement: ${((stopwatch1.elapsedMilliseconds - stopwatch2.elapsedMilliseconds) / stopwatch1.elapsedMilliseconds * 100).toStringAsFixed(1)}%');

      // Show cache statistics
      final cacheStats = optimizedService.getCacheStats();
      // ignore: avoid_print
      print('  Cache Hit Rates:');
      // ignore: avoid_print
      print('    Settings: ${(cacheStats['settings_cache']['hit_rate'] * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('    Options: ${(cacheStats['options_cache']['hit_rate'] * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('    Validation: ${(cacheStats['validation_cache']['hit_rate'] * 100).toStringAsFixed(1)}%');

      optimizedService.dispose();
    });

    test('Benchmark: Memory Usage', () {
      // Test memory efficiency with repeated operations
      final optimizedService = OptimizedGenerationSettingsService();
      optimizedService.initialize();

      // Perform many operations
      final stopwatch = Stopwatch()..start();
      for (int iteration = 0; iteration < 10; iteration++) {
        for (final chat in testChats.take(100)) {
          final settings = optimizedService.getEffectiveSettings(
            chat: chat,
            globalSettings: appSettings,
          );
          optimizedService.buildOllamaOptions(settings: settings);
        }
      }
      stopwatch.stop();

      final cacheStats = optimizedService.getCacheStats();
      
      // ignore: avoid_print
      print('Memory Usage Benchmark (10 iterations × 100 chats):');
      // ignore: avoid_print
      print('  Total time: ${stopwatch.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('  Cache sizes:');
      // ignore: avoid_print
      print('    Settings: ${cacheStats['settings_cache']['size']}/${cacheStats['settings_cache']['capacity']}');
      // ignore: avoid_print
      print('    Options: ${cacheStats['options_cache']['size']}/${cacheStats['options_cache']['capacity']}');
      // ignore: avoid_print
      print('    Validation: ${cacheStats['validation_cache']['size']}/${cacheStats['validation_cache']['capacity']}');

      optimizedService.dispose();
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