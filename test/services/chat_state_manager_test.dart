import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ollamaverse/models/chat.dart';
import 'package:ollamaverse/models/message.dart';
import 'package:ollamaverse/services/chat_state_manager.dart';
import 'package:ollamaverse/services/chat_history_service.dart';

import 'chat_state_manager_test.mocks.dart';

@GenerateMocks([ChatHistoryService])
void main() {
  group('ChatStateManager', () {
    late MockChatHistoryService mockChatHistoryService;
    late ChatStateManager chatStateManager;
    late StreamController<List<Chat>> chatStreamController;

    setUp(() {
      mockChatHistoryService = MockChatHistoryService();
      chatStreamController = StreamController<List<Chat>>.broadcast();
      
      // Setup mock behavior
      when(mockChatHistoryService.chatStream)
          .thenAnswer((_) => chatStreamController.stream);
      when(mockChatHistoryService.isInitialized).thenReturn(true);
      when(mockChatHistoryService.chats).thenReturn([]);
      
      chatStateManager = ChatStateManager(
        chatHistoryService: mockChatHistoryService,
      );
    });

    tearDown(() {
      chatStateManager.dispose();
      chatStreamController.close();
    });

    group('Initialization', () {
      test('should initialize with empty state', () {
        expect(chatStateManager.chats, isEmpty);
        expect(chatStateManager.activeChat, isNull);
        expect(chatStateManager.shouldScrollToBottomOnChatSwitch, isFalse);
      });

      test('should listen to chat stream updates', () async {
        final testChats = [_createTestChat('1', 'Test Chat 1')];
        
        // Emit chats through the stream
        chatStreamController.add(testChats);
        
        // Wait for stream processing
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(chatStateManager.chats, hasLength(1));
        expect(chatStateManager.chats.first.title, 'Test Chat 1');
      });

      test('should set active chat to most recent when chats are loaded', () async {
        final chat1 = _createTestChat('1', 'Chat 1', 
            lastUpdated: DateTime.now().subtract(const Duration(hours: 1)));
        final chat2 = _createTestChat('2', 'Chat 2', 
            lastUpdated: DateTime.now());
        
        chatStreamController.add([chat1, chat2]);
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(chatStateManager.activeChat?.id, '2');
        expect(chatStateManager.activeChat?.title, 'Chat 2');
      });
    });

    group('Chat Creation', () {
      test('should create new chat successfully', () async {
        when(mockChatHistoryService.saveChat(any))
            .thenAnswer((_) async {});
        
        final newChat = await chatStateManager.createNewChat(
          modelName: 'test-model',
          title: 'Test Chat',
        );
        
        expect(newChat.title, 'Test Chat');
        expect(newChat.modelName, 'test-model');
        expect(newChat.messages, isEmpty);
        expect(chatStateManager.activeChat?.id, newChat.id);
        
        verify(mockChatHistoryService.saveChat(any)).called(1);
      });

      test('should create new chat with system prompt', () async {
        when(mockChatHistoryService.saveChat(any))
            .thenAnswer((_) async {});
        
        final newChat = await chatStateManager.createNewChat(
          modelName: 'test-model',
          systemPrompt: 'You are a helpful assistant',
        );
        
        expect(newChat.messages, hasLength(1));
        expect(newChat.messages.first.role, MessageRole.system);
        expect(newChat.messages.first.content, 'You are a helpful assistant');
      });

      test('should use default title when none provided', () async {
        when(mockChatHistoryService.saveChat(any))
            .thenAnswer((_) async {});
        
        final newChat = await chatStateManager.createNewChat(
          modelName: 'test-model',
        );
        
        expect(newChat.title, 'New chat with test-model');
      });

      test('should throw error when disposed', () async {
        chatStateManager.dispose();
        
        expect(
          () => chatStateManager.createNewChat(modelName: 'test-model'),
          throwsStateError,
        );
      });
    });

    group('Active Chat Management', () {
      test('should set active chat by ID', () async {
        final testChats = [
          _createTestChat('1', 'Chat 1'),
          _createTestChat('2', 'Chat 2'),
        ];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        chatStateManager.setActiveChat('1');
        
        expect(chatStateManager.activeChat?.id, '1');
        expect(chatStateManager.activeChat?.title, 'Chat 1');
      });

      test('should throw error when setting non-existent chat as active', () {
        expect(
          () => chatStateManager.setActiveChat('non-existent'),
          throwsArgumentError,
        );
      });

      test('should trigger scroll flag when switching to chat with messages', () async {
        final chatWithMessages = _createTestChat('1', 'Chat 1');
        chatWithMessages.messages.add(_createTestMessage('msg1', 'Hello'));
        final emptyChat = _createTestChat('2', 'Chat 2');
        
        final testChats = [chatWithMessages, emptyChat];
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Set active chat to empty chat first
        chatStateManager.setActiveChat('2');
        chatStateManager.resetScrollToBottomFlag();
        
        // Switch to chat with messages
        chatStateManager.setActiveChat('1');
        
        expect(chatStateManager.shouldScrollToBottomOnChatSwitch, isTrue);
      });

      test('should not trigger scroll flag when switching to empty chat', () async {
        final emptyChat = _createTestChat('1', 'Empty Chat');
        
        final testChats = [emptyChat];
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        chatStateManager.setActiveChat('1');
        
        expect(chatStateManager.shouldScrollToBottomOnChatSwitch, isFalse);
      });

      test('should reset scroll flag', () async {
        final testChats = [_createTestChat('1', 'Chat 1')];
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        chatStateManager.setActiveChat('1');
        chatStateManager.resetScrollToBottomFlag();
        
        expect(chatStateManager.shouldScrollToBottomOnChatSwitch, isFalse);
      });
    });

    group('Chat Updates', () {
      test('should update chat title', () async {
        final testChat = _createTestChat('1', 'Old Title');
        final testChats = [testChat];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        when(mockChatHistoryService.saveChat(any))
            .thenAnswer((_) async {});
        
        await chatStateManager.updateChatTitle('1', 'New Title');
        
        verify(mockChatHistoryService.saveChat(any)).called(1);
      });

      test('should update chat model', () async {
        final testChat = _createTestChat('1', 'Test Chat');
        testChat.messages.clear(); // Make it a new chat
        final testChats = [testChat];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        when(mockChatHistoryService.saveChat(any))
            .thenAnswer((_) async {});
        
        await chatStateManager.updateChatModel('1', 'new-model');
        
        verify(mockChatHistoryService.saveChat(any)).called(1);
      });

      test('should update chat with new messages', () async {
        final testChat = _createTestChat('1', 'Test Chat');
        final testChats = [testChat];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        when(mockChatHistoryService.saveChat(any))
            .thenAnswer((_) async {});
        
        final updatedChat = testChat.copyWith(
          messages: [_createTestMessage('msg1', 'Hello')],
        );
        
        await chatStateManager.updateChat(updatedChat);
        
        verify(mockChatHistoryService.saveChat(updatedChat)).called(1);
      });

      test('should throw error when updating non-existent chat', () async {
        final nonExistentChat = _createTestChat('999', 'Non-existent');
        
        expect(
          () => chatStateManager.updateChat(nonExistentChat),
          throwsArgumentError,
        );
      });
    });

    group('Chat Deletion', () {
      test('should delete chat successfully', () async {
        final testChats = [
          _createTestChat('1', 'Chat 1'),
          _createTestChat('2', 'Chat 2'),
        ];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        when(mockChatHistoryService.deleteChat('1'))
            .thenAnswer((_) async {});
        
        await chatStateManager.deleteChat('1');
        
        verify(mockChatHistoryService.deleteChat('1')).called(1);
      });

      test('should set new active chat when deleting active chat', () async {
        final testChats = [
          _createTestChat('1', 'Chat 1'),
          _createTestChat('2', 'Chat 2'),
        ];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        chatStateManager.setActiveChat('1');
        
        when(mockChatHistoryService.deleteChat('1'))
            .thenAnswer((_) async {});
        
        await chatStateManager.deleteChat('1');
        
        expect(chatStateManager.activeChat?.id, '2');
      });

      test('should set active chat to null when deleting last chat', () async {
        final testChats = [_createTestChat('1', 'Only Chat')];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        chatStateManager.setActiveChat('1');
        
        when(mockChatHistoryService.deleteChat('1'))
            .thenAnswer((_) async {});
        
        await chatStateManager.deleteChat('1');
        
        expect(chatStateManager.activeChat, isNull);
      });

      test('should throw error when deleting non-existent chat', () async {
        expect(
          () => chatStateManager.deleteChat('non-existent'),
          throwsArgumentError,
        );
      });
    });

    group('Chat Queries', () {
      test('should get chat by ID', () async {
        final testChats = [
          _createTestChat('1', 'Chat 1'),
          _createTestChat('2', 'Chat 2'),
        ];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        final chat = chatStateManager.getChatById('1');
        
        expect(chat?.id, '1');
        expect(chat?.title, 'Chat 1');
      });

      test('should return null for non-existent chat ID', () async {
        final chat = chatStateManager.getChatById('non-existent');
        expect(chat, isNull);
      });

      test('should check if chat exists', () async {
        final testChats = [_createTestChat('1', 'Chat 1')];
        
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(chatStateManager.chatExists('1'), isTrue);
        expect(chatStateManager.chatExists('non-existent'), isFalse);
      });

      test('should get displayable messages for active chat', () async {
        final testChat = _createTestChat('1', 'Test Chat');
        testChat.messages.addAll([
          _createTestMessage('sys1', 'System message', MessageRole.system),
          _createTestMessage('msg1', 'User message', MessageRole.user),
          _createTestMessage('msg2', 'Assistant message', MessageRole.assistant),
        ]);
        
        final testChats = [testChat];
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        chatStateManager.setActiveChat('1');
        
        final displayableMessages = chatStateManager.displayableMessages;
        
        expect(displayableMessages, hasLength(2));
        expect(displayableMessages[0].role, MessageRole.user);
        expect(displayableMessages[1].role, MessageRole.assistant);
      });

      test('should return empty list when no active chat', () {
        final displayableMessages = chatStateManager.displayableMessages;
        expect(displayableMessages, isEmpty);
      });
    });

    group('State Management', () {
      test('should emit state changes through stream', () async {
        final stateChanges = <ChatStateManagerState>[];
        final subscription = chatStateManager.stateStream.listen(
          (state) => stateChanges.add(state),
        );
        
        final testChats = [_createTestChat('1', 'Test Chat')];
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(stateChanges, isNotEmpty);
        expect(stateChanges.last.chats, hasLength(1));
        
        await subscription.cancel();
      });

      test('should provide current state snapshot', () async {
        final testChats = [_createTestChat('1', 'Test Chat')];
        chatStreamController.add(testChats);
        await Future.delayed(const Duration(milliseconds: 10));
        
        final state = chatStateManager.currentState;
        
        expect(state.chats, hasLength(1));
        expect(state.activeChat?.id, '1');
        expect(state.shouldScrollToBottomOnChatSwitch, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle chat stream errors gracefully', () async {
        // The ChatStateManager should handle stream errors internally
        // and not propagate them to the state stream
        chatStreamController.addError('Test error');
        
        // Wait a bit to ensure error is processed
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Should not throw, manager should continue working
        expect(chatStateManager.chats, isEmpty);
      });

      test('should validate state correctly', () {
        final testChat = _createTestChat('1', 'Chat 1');
        final validState = ChatStateManagerState(
          chats: [testChat],
          activeChat: testChat,
          shouldScrollToBottomOnChatSwitch: false,
        );
        
        expect(validState.isValid, isTrue);
        
        final invalidState = ChatStateManagerState(
          chats: [],
          activeChat: _createTestChat('1', 'Chat 1'),
          shouldScrollToBottomOnChatSwitch: false,
        );
        
        expect(invalidState.isValid, isFalse);
      });
    });

    group('Disposal', () {
      test('should dispose resources properly', () {
        expect(() => chatStateManager.dispose(), returnsNormally);
      });

      test('should throw error when using disposed manager', () {
        chatStateManager.dispose();
        
        expect(
          () => chatStateManager.setActiveChat('1'),
          throwsStateError,
        );
      });
    });
  });

  group('ChatStateManagerState', () {
    test('should create initial state', () {
      final state = ChatStateManagerState.initial();
      
      expect(state.chats, isEmpty);
      expect(state.activeChat, isNull);
      expect(state.shouldScrollToBottomOnChatSwitch, isFalse);
    });

    test('should copy with updated fields', () {
      final originalState = ChatStateManagerState.initial();
      final testChat = _createTestChat('1', 'Test Chat');
      
      final updatedState = originalState.copyWith(
        chats: [testChat],
        activeChat: testChat,
        shouldScrollToBottomOnChatSwitch: true,
      );
      
      expect(updatedState.chats, hasLength(1));
      expect(updatedState.activeChat?.id, '1');
      expect(updatedState.shouldScrollToBottomOnChatSwitch, isTrue);
    });

    test('should clear active chat when specified', () {
      final testChat = _createTestChat('1', 'Test Chat');
      final state = ChatStateManagerState(
        chats: [testChat],
        activeChat: testChat,
        shouldScrollToBottomOnChatSwitch: false,
      );
      
      final clearedState = state.copyWith(clearActiveChat: true);
      
      expect(clearedState.activeChat, isNull);
      expect(clearedState.chats, hasLength(1));
    });

    test('should implement equality correctly', () {
      final chat1 = _createTestChat('1', 'Chat 1');
      final chat2 = _createTestChat('2', 'Chat 2');
      
      final state1 = ChatStateManagerState(
        chats: [chat1],
        activeChat: chat1,
        shouldScrollToBottomOnChatSwitch: false,
      );
      
      final state2 = ChatStateManagerState(
        chats: [chat1],
        activeChat: chat1,
        shouldScrollToBottomOnChatSwitch: false,
      );
      
      final state3 = ChatStateManagerState(
        chats: [chat2],
        activeChat: chat2,
        shouldScrollToBottomOnChatSwitch: false,
      );
      
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should have consistent hashCode', () {
      final chat = _createTestChat('1', 'Chat 1');
      final state1 = ChatStateManagerState(
        chats: [chat],
        activeChat: chat,
        shouldScrollToBottomOnChatSwitch: false,
      );
      
      final state2 = ChatStateManagerState(
        chats: [chat],
        activeChat: chat,
        shouldScrollToBottomOnChatSwitch: false,
      );
      
      expect(state1.hashCode, equals(state2.hashCode));
    });

    test('should have meaningful toString', () {
      final chat = _createTestChat('1', 'Test Chat');
      final state = ChatStateManagerState(
        chats: [chat],
        activeChat: chat,
        shouldScrollToBottomOnChatSwitch: true,
      );
      
      final string = state.toString();
      
      expect(string, contains('chats: 1'));
      expect(string, contains('activeChat: 1'));
      expect(string, contains('shouldScrollToBottomOnChatSwitch: true'));
    });
  });
}

// Helper functions for creating test data
Chat _createTestChat(String id, String title, {DateTime? lastUpdated}) {
  return Chat(
    id: id,
    title: title,
    modelName: 'test-model',
    messages: [],
    createdAt: DateTime.now(),
    lastUpdatedAt: lastUpdated ?? DateTime.now(),
  );
}

Message _createTestMessage(String id, String content, [MessageRole role = MessageRole.user]) {
  return Message(
    id: id,
    content: content,
    role: role,
    timestamp: DateTime.now(),
  );
}