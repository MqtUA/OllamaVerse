import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/chat_history_service.dart';
import '../../lib/models/chat.dart';
import '../../lib/models/message.dart';
import '../../lib/models/generation_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ChatHistoryService Generation Settings Tests', () {
    late ChatHistoryService chatHistoryService;

    setUp(() {
      chatHistoryService = ChatHistoryService();
    });

    tearDown(() async {
      await chatHistoryService.dispose();
    });

    test('should save and load chat with custom generation settings', () async {
      final customSettings = GenerationSettings(
        temperature: 0.8,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.2,
        maxTokens: 2048,
        numThread: 8,
      );

      final chat = Chat(
        id: 'test_chat_1',
        title: 'Test Chat',
        modelName: 'llama2',
        messages: [
          Message(
            id: 'msg_1',
            content: 'Hello',
            role: MessageRole.user,
            timestamp: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        customGenerationSettings: customSettings,
      );

      await chatHistoryService.saveChat(chat);
      final loadedChat = await chatHistoryService.loadChat('test_chat_1');

      expect(loadedChat, isNotNull);
      expect(loadedChat!.hasCustomGenerationSettings, true);
      expect(loadedChat.customGenerationSettings!.temperature, 0.8);
      expect(loadedChat.customGenerationSettings!.topP, 0.95);
      expect(loadedChat.customGenerationSettings!.topK, 50);
    });

    test('should save and load chat without custom generation settings', () async {
      final chat = Chat(
        id: 'test_chat_2',
        title: 'Test Chat 2',
        modelName: 'llama2',
        messages: [
          Message(
            id: 'msg_1',
            content: 'Hello',
            role: MessageRole.user,
            timestamp: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        customGenerationSettings: null,
      );

      await chatHistoryService.saveChat(chat);
      final loadedChat = await chatHistoryService.loadChat('test_chat_2');

      expect(loadedChat, isNotNull);
      expect(loadedChat!.hasCustomGenerationSettings, false);
      expect(loadedChat.customGenerationSettings, isNull);
    });

    test('should get custom settings statistics', () async {
      // Add chat with custom settings
      final chatWithSettings = Chat(
        id: 'chat_with_settings',
        title: 'Chat With Settings',
        modelName: 'llama2',
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        customGenerationSettings: GenerationSettings.defaults(),
      );

      // Add chat without custom settings
      final chatWithoutSettings = Chat(
        id: 'chat_without_settings',
        title: 'Chat Without Settings',
        modelName: 'llama2',
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        customGenerationSettings: null,
      );

      await chatHistoryService.saveChat(chatWithSettings);
      await chatHistoryService.saveChat(chatWithoutSettings);

      final stats = chatHistoryService.getCustomSettingsStats();

      expect(stats['totalChats'], 2);
      expect(stats['chatsWithCustomSettings'], 1);
      expect(stats['percentageWithCustomSettings'], '50.0');
    });
  });
}