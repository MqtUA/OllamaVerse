import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/chat.dart';
import '../../lib/models/message.dart';
import '../../lib/models/generation_settings.dart';

void main() {
  group('Chat', () {
    late DateTime testDateTime;
    late List<Message> testMessages;

    setUp(() {
      testDateTime = DateTime.now();
      testMessages = [
        Message(
          id: 'msg1',
          content: 'Hello',
          role: MessageRole.user,
          timestamp: testDateTime,
        ),
        Message(
          id: 'msg2',
          content: 'Hi there!',
          role: MessageRole.assistant,
          timestamp: testDateTime.add(const Duration(seconds: 1)),
        ),
      ];
    });

    group('constructor', () {
      test('should create chat with required fields', () {
        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        expect(chat.id, 'chat1');
        expect(chat.title, 'Test Chat');
        expect(chat.modelName, 'llama2');
        expect(chat.messages, testMessages);
        expect(chat.createdAt, testDateTime);
        expect(chat.lastUpdatedAt, testDateTime);
        expect(chat.context, isNull);
        expect(chat.customGenerationSettings, isNull);
      });

      test('should create chat with optional fields', () {
        final customSettings = GenerationSettings.defaults().copyWith(temperature: 0.8);
        final context = [1, 2, 3, 4, 5];

        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          context: context,
          customGenerationSettings: customSettings,
        );

        expect(chat.context, context);
        expect(chat.customGenerationSettings, customSettings);
      });
    });

    group('hasCustomGenerationSettings', () {
      test('should return false when customGenerationSettings is null', () {
        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        expect(chat.hasCustomGenerationSettings, isFalse);
      });

      test('should return true when customGenerationSettings is not null', () {
        final customSettings = GenerationSettings.defaults().copyWith(temperature: 0.8);
        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          customGenerationSettings: customSettings,
        );

        expect(chat.hasCustomGenerationSettings, isTrue);
      });
    });

    group('copyWith', () {
      late Chat originalChat;

      setUp(() {
        originalChat = Chat(
          id: 'chat1',
          title: 'Original Title',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          context: [1, 2, 3],
          customGenerationSettings: GenerationSettings.defaults(),
        );
      });

      test('should create copy with updated fields', () {
        final newDateTime = testDateTime.add(const Duration(hours: 1));
        final newSettings = GenerationSettings.defaults().copyWith(temperature: 0.8);

        final updatedChat = originalChat.copyWith(
          title: 'Updated Title',
          lastUpdatedAt: newDateTime,
          customGenerationSettings: newSettings,
        );

        expect(updatedChat.id, originalChat.id); // Unchanged
        expect(updatedChat.title, 'Updated Title'); // Changed
        expect(updatedChat.modelName, originalChat.modelName); // Unchanged
        expect(updatedChat.messages, originalChat.messages); // Unchanged
        expect(updatedChat.createdAt, originalChat.createdAt); // Unchanged
        expect(updatedChat.lastUpdatedAt, newDateTime); // Changed
        expect(updatedChat.context, originalChat.context); // Unchanged
        expect(updatedChat.customGenerationSettings, newSettings); // Changed
      });

      test('should create identical copy when no parameters provided', () {
        final copy = originalChat.copyWith();

        expect(copy.id, originalChat.id);
        expect(copy.title, originalChat.title);
        expect(copy.modelName, originalChat.modelName);
        expect(copy.messages, originalChat.messages);
        expect(copy.createdAt, originalChat.createdAt);
        expect(copy.lastUpdatedAt, originalChat.lastUpdatedAt);
        expect(copy.context, originalChat.context);
        expect(copy.customGenerationSettings, originalChat.customGenerationSettings);
      });

      test('should preserve existing customGenerationSettings when null passed', () {
        final chatWithoutSettings = originalChat.copyWith(
          customGenerationSettings: null,
        );

        // copyWith with null should preserve the existing value
        expect(chatWithoutSettings.customGenerationSettings, originalChat.customGenerationSettings);
        expect(chatWithoutSettings.hasCustomGenerationSettings, isTrue);
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        final customSettings = const GenerationSettings(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
          repeatPenalty: 1.2,
          maxTokens: 1000,
          numThread: 6,
        );

        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          context: [1, 2, 3, 4, 5],
          customGenerationSettings: customSettings,
        );

        final json = chat.toJson();

        expect(json['id'], 'chat1');
        expect(json['title'], 'Test Chat');
        expect(json['modelName'], 'llama2');
        expect(json['messages'], isA<List>());
        expect(json['createdAt'], testDateTime.toIso8601String());
        expect(json['lastUpdatedAt'], testDateTime.toIso8601String());
        expect(json['context'], [1, 2, 3, 4, 5]);
        expect(json['customGenerationSettings'], isA<Map<String, dynamic>>());
        expect(json['customGenerationSettings']['temperature'], 0.8);
      });

      test('should serialize to JSON with null optional fields', () {
        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        final json = chat.toJson();

        expect(json['context'], isNull);
        expect(json['customGenerationSettings'], isNull);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'chat1',
          'title': 'Test Chat',
          'modelName': 'llama2',
          'messages': testMessages.map((m) => m.toJson()).toList(),
          'createdAt': testDateTime.toIso8601String(),
          'lastUpdatedAt': testDateTime.toIso8601String(),
          'context': [1, 2, 3, 4, 5],
          'customGenerationSettings': {
            'temperature': 0.8,
            'topP': 0.95,
            'topK': 50,
            'repeatPenalty': 1.2,
            'maxTokens': 1000,
            'numThread': 6,
          },
        };

        final chat = Chat.fromJson(json);

        expect(chat.id, 'chat1');
        expect(chat.title, 'Test Chat');
        expect(chat.modelName, 'llama2');
        expect(chat.messages.length, testMessages.length);
        expect(chat.createdAt, testDateTime);
        expect(chat.lastUpdatedAt, testDateTime);
        expect(chat.context, [1, 2, 3, 4, 5]);
        expect(chat.customGenerationSettings, isNotNull);
        expect(chat.customGenerationSettings!.temperature, 0.8);
        expect(chat.customGenerationSettings!.topP, 0.95);
        expect(chat.customGenerationSettings!.topK, 50);
      });

      test('should deserialize from JSON with null optional fields', () {
        final json = {
          'id': 'chat1',
          'title': 'Test Chat',
          'modelName': 'llama2',
          'messages': testMessages.map((m) => m.toJson()).toList(),
          'createdAt': testDateTime.toIso8601String(),
          'lastUpdatedAt': testDateTime.toIso8601String(),
          'context': null,
          'customGenerationSettings': null,
        };

        final chat = Chat.fromJson(json);

        expect(chat.context, isNull);
        expect(chat.customGenerationSettings, isNull);
        expect(chat.hasCustomGenerationSettings, isFalse);
      });

      test('should handle missing optional fields in JSON', () {
        final json = {
          'id': 'chat1',
          'title': 'Test Chat',
          'modelName': 'llama2',
          'messages': testMessages.map((m) => m.toJson()).toList(),
          'createdAt': testDateTime.toIso8601String(),
          'lastUpdatedAt': testDateTime.toIso8601String(),
          // context and customGenerationSettings are missing
        };

        final chat = Chat.fromJson(json);

        expect(chat.context, isNull);
        expect(chat.customGenerationSettings, isNull);
        expect(chat.hasCustomGenerationSettings, isFalse);
      });

      test('should handle legacy JSON without modelName', () {
        final json = {
          'id': 'chat1',
          'title': 'Test Chat',
          // modelName is missing (legacy format)
          'messages': testMessages.map((m) => m.toJson()).toList(),
          'createdAt': testDateTime.toIso8601String(),
          'lastUpdatedAt': testDateTime.toIso8601String(),
        };

        final chat = Chat.fromJson(json);

        expect(chat.modelName, ''); // Default empty string
      });

      test('should round-trip through JSON correctly', () {
        final originalChat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          context: [1, 2, 3, 4, 5],
          customGenerationSettings: const GenerationSettings(
            temperature: 0.8,
            topP: 0.95,
            topK: 50,
            repeatPenalty: 1.2,
            maxTokens: 1000,
            numThread: 6,
          ),
        );

        final json = originalChat.toJson();
        final restoredChat = Chat.fromJson(json);

        expect(restoredChat.id, originalChat.id);
        expect(restoredChat.title, originalChat.title);
        expect(restoredChat.modelName, originalChat.modelName);
        expect(restoredChat.messages.length, originalChat.messages.length);
        expect(restoredChat.createdAt, originalChat.createdAt);
        expect(restoredChat.lastUpdatedAt, originalChat.lastUpdatedAt);
        expect(restoredChat.context, originalChat.context);
        expect(restoredChat.customGenerationSettings, originalChat.customGenerationSettings);
        expect(restoredChat.hasCustomGenerationSettings, originalChat.hasCustomGenerationSettings);
      });
    });

    group('edge cases', () {
      test('should handle empty messages list', () {
        final chat = Chat(
          id: 'chat1',
          title: 'Empty Chat',
          modelName: 'llama2',
          messages: [],
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        expect(chat.messages, isEmpty);

        final json = chat.toJson();
        final restoredChat = Chat.fromJson(json);
        expect(restoredChat.messages, isEmpty);
      });

      test('should handle empty context list', () {
        final chat = Chat(
          id: 'chat1',
          title: 'Test Chat',
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
          context: [],
        );

        expect(chat.context, isEmpty);

        final json = chat.toJson();
        final restoredChat = Chat.fromJson(json);
        expect(restoredChat.context, isEmpty);
      });

      test('should handle very long title', () {
        final longTitle = 'A' * 1000;
        final chat = Chat(
          id: 'chat1',
          title: longTitle,
          modelName: 'llama2',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        expect(chat.title, longTitle);

        final json = chat.toJson();
        final restoredChat = Chat.fromJson(json);
        expect(restoredChat.title, longTitle);
      });

      test('should handle special characters in fields', () {
        final chat = Chat(
          id: 'chat-1_test',
          title: 'Test Chat with émojis 🚀 and "quotes"',
          modelName: 'llama2:7b-chat',
          messages: testMessages,
          createdAt: testDateTime,
          lastUpdatedAt: testDateTime,
        );

        final json = chat.toJson();
        final restoredChat = Chat.fromJson(json);

        expect(restoredChat.id, chat.id);
        expect(restoredChat.title, chat.title);
        expect(restoredChat.modelName, chat.modelName);
      });
    });
  });
}