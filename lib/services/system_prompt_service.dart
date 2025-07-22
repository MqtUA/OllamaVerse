import '../models/message.dart';
import '../services/chat_history_service.dart';
import '../services/chat_state_manager.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';

/// Service responsible for managing system prompts across chats
///
/// Handles system prompt updates, validation, and strategy management
/// for different models and chat configurations.
class SystemPromptService {
  final ChatHistoryService _chatHistoryService;
  final ChatStateManager _chatStateManager;
  final SettingsProvider _settingsProvider;

  SystemPromptService({
    required ChatHistoryService chatHistoryService,
    required ChatStateManager chatStateManager,
    required SettingsProvider settingsProvider,
  })  : _chatHistoryService = chatHistoryService,
        _chatStateManager = chatStateManager,
        _settingsProvider = settingsProvider;

  /// Update system prompt for a specific chat
  Future<void> updateChatSystemPrompt(String chatId) async {
    try {
      final currentChats = _chatHistoryService.chats;
      final chatIndex = currentChats.indexWhere((c) => c.id == chatId);

      if (chatIndex >= 0) {
        final currentChat = currentChats[chatIndex];
        final currentSystemPrompt = _settingsProvider.settings.systemPrompt;

        // Create updated messages list
        List<Message> updatedMessages = currentChat.messages
            .where((message) => message.role != MessageRole.system)
            .toList();

        // Add new system prompt if it exists
        if (currentSystemPrompt.isNotEmpty) {
          final systemMessage = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: currentSystemPrompt,
            role: MessageRole.system,
            timestamp: DateTime.now(),
          );
          updatedMessages.insert(0, systemMessage);
        }

        final updatedChat = currentChat.copyWith(
          messages: updatedMessages,
          lastUpdatedAt: DateTime.now(),
        );

        // Update active chat if this is the active one
        if (_chatStateManager.activeChat?.id == chatId) {
          await _chatStateManager.updateChat(updatedChat);
        }

        await _chatHistoryService.saveChat(updatedChat);
      }
    } catch (e) {
      AppLogger.error('Failed to update chat system prompt', e);
      rethrow;
    }
  }

  /// Update system prompt for all existing chats
  Future<void> updateAllChatsSystemPrompt() async {
    try {
      final currentChats = _chatHistoryService.chats;
      final currentSystemPrompt = _settingsProvider.settings.systemPrompt;

      for (final chat in currentChats) {
        // Create updated messages list
        List<Message> updatedMessages = chat.messages
            .where((message) => message.role != MessageRole.system)
            .toList();

        // Add new system prompt if it exists
        if (currentSystemPrompt.isNotEmpty) {
          final systemMessage = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: currentSystemPrompt,
            role: MessageRole.system,
            timestamp: DateTime.now(),
          );
          updatedMessages.insert(0, systemMessage);
        }

        final updatedChat = chat.copyWith(
          messages: updatedMessages,
          lastUpdatedAt: DateTime.now(),
        );

        // Update active chat if this is the active one
        if (_chatStateManager.activeChat?.id == chat.id) {
          await _chatStateManager.updateChat(updatedChat);
        }

        await _chatHistoryService.saveChat(updatedChat);
      }
    } catch (e) {
      AppLogger.error('Failed to update system prompt for all chats', e);
      rethrow;
    }
  }

  /// Validate system prompt support for a specific model
  Future<Map<String, dynamic>> validateSystemPromptSupport(
      String modelName) async {
    if (modelName.isEmpty) {
      return {
        'supported': true,
        'modelName': 'unknown',
        'fallbackMethod': 'native',
        'recommendation':
            'No model selected. System prompt support cannot be determined.',
      };
    }

    try {
      // Wait for settings to be ready before validation
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final validation =
          await ollamaService.validateSystemPromptSupport(modelName);
      return validation;
    } catch (e) {
      AppLogger.error('Error validating system prompt support', e);
      return {
        'supported': true, // Default to supported
        'modelName': modelName,
        'fallbackMethod': 'native',
        'recommendation':
            'Unable to validate system prompt support. Assuming native support.',
        'error': e.toString(),
      };
    }
  }

  /// Get system prompt handling strategy for a specific model
  String getSystemPromptStrategy(String modelName) {
    if (modelName.isEmpty) return 'native';

    try {
      if (_settingsProvider.isLoading) {
        AppLogger.warning('Settings still loading, using default strategy');
        return 'native';
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final strategy = ollamaService.getSystemPromptStrategy(modelName);
      return strategy;
    } catch (e) {
      AppLogger.error('Error getting system prompt strategy', e);
      return 'native'; // Default fallback
    }
  }
}
