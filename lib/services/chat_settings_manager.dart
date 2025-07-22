import '../models/chat.dart';
import '../models/generation_settings.dart';
import '../services/chat_history_service.dart';
import '../services/chat_state_manager.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';

/// Service responsible for managing per-chat generation settings
/// 
/// Handles custom generation settings for individual chats,
/// validation, and coordination between global and chat-specific settings.
class ChatSettingsManager {
  final ChatHistoryService _chatHistoryService;
  final ChatStateManager _chatStateManager;
  final SettingsProvider _settingsProvider;

  ChatSettingsManager({
    required ChatHistoryService chatHistoryService,
    required ChatStateManager chatStateManager,
    required SettingsProvider settingsProvider,
  })  : _chatHistoryService = chatHistoryService,
        _chatStateManager = chatStateManager,
        _settingsProvider = settingsProvider;

  /// Check if a chat has custom generation settings
  bool chatHasCustomSettings(String chatId) {
    final chat = _chatHistoryService.chats.where((c) => c.id == chatId).firstOrNull;
    return chat?.hasCustomGenerationSettings ?? false;
  }

  /// Get generation settings for a chat (either custom or global)
  GenerationSettings getEffectiveSettingsForChat(String chatId) {
    final chat = _chatHistoryService.chats.where((c) => c.id == chatId).firstOrNull;
    if (chat == null) {
      return _settingsProvider.settings.generationSettings;
    }
    
    return chat.hasCustomGenerationSettings
        ? chat.customGenerationSettings!
        : _settingsProvider.settings.generationSettings;
  }

  /// Update generation settings for a specific chat
  Future<void> updateChatGenerationSettings(String chatId, GenerationSettings? customSettings) async {
    try {
      final chat = _chatHistoryService.chats.where((c) => c.id == chatId).firstOrNull;
      if (chat == null) {
        throw Exception('Chat not found');
      }
      
      // Validate settings before applying them
      if (customSettings != null && !customSettings.isValid()) {
        final errors = customSettings.getValidationErrors();
        final errorMessage = 'Invalid generation settings: ${errors.join(', ')}';
        throw Exception(errorMessage);
      }

      final updatedChat = chat.copyWith(customGenerationSettings: customSettings);
      await _chatStateManager.updateChat(updatedChat);
      
      // If this is the active chat, ensure the UI reflects the change
      if (_chatStateManager.activeChat?.id == chatId) {
        await _chatStateManager.refreshActiveChat();
      }
    } catch (e) {
      AppLogger.error('Failed to update chat generation settings', e);
      rethrow;
    }
  }

  /// Remove custom settings from a chat (revert to global settings)
  Future<void> removeChatCustomSettings(String chatId) async {
    await updateChatGenerationSettings(chatId, null);
  }

  /// Apply global settings to a specific chat as custom settings
  Future<void> applyChatCustomSettingsFromGlobal(String chatId) async {
    final globalSettings = _settingsProvider.settings.generationSettings;
    await updateChatGenerationSettings(chatId, globalSettings);
  }

  /// Get all chats that have custom settings
  List<Chat> getChatsWithCustomSettings() {
    return _chatHistoryService.chats
        .where((chat) => chat.hasCustomGenerationSettings)
        .toList();
  }

  /// Validate settings for a specific chat
  Map<String, dynamic> validateChatSettings(String chatId) {
    try {
      final chat = _chatHistoryService.chats.where((c) => c.id == chatId).firstOrNull;
      if (chat == null) {
        return {
          'isValid': false,
          'error': 'Chat not found',
          'chatId': chatId,
        };
      }

      final effectiveSettings = getEffectiveSettingsForChat(chatId);
      final isValid = effectiveSettings.isValid();
      final errors = isValid ? <String>[] : effectiveSettings.getValidationErrors();

      return {
        'isValid': isValid,
        'chatId': chatId,
        'hasCustomSettings': chat.hasCustomGenerationSettings,
        'errors': errors,
        'settings': {
          'temperature': effectiveSettings.temperature,
          'topK': effectiveSettings.topK,
          'topP': effectiveSettings.topP,
          'repeatPenalty': effectiveSettings.repeatPenalty,
          'maxTokens': effectiveSettings.maxTokens,
          'numThread': effectiveSettings.numThread,
        },
      };
    } catch (e) {
      AppLogger.error('Error validating chat settings', e);
      return {
        'isValid': false,
        'error': e.toString(),
        'chatId': chatId,
      };
    }
  }

  /// Get settings comparison between chat and global settings
  Map<String, dynamic> compareWithGlobalSettings(String chatId) {
    try {
      final chatSettings = getEffectiveSettingsForChat(chatId);
      final globalSettings = _settingsProvider.settings.generationSettings;
      final hasCustomSettings = chatHasCustomSettings(chatId);

      return {
        'chatId': chatId,
        'hasCustomSettings': hasCustomSettings,
        'differences': _findSettingsDifferences(chatSettings, globalSettings),
        'chatSettings': _settingsToMap(chatSettings),
        'globalSettings': _settingsToMap(globalSettings),
        'isIdenticalToGlobal': _areSettingsIdentical(chatSettings, globalSettings),
      };
    } catch (e) {
      AppLogger.error('Error comparing settings', e);
      return {
        'chatId': chatId,
        'error': e.toString(),
      };
    }
  }

  /// Handle global generation settings changes
  /// 
  /// This method is called when the global generation settings are updated
  /// to ensure that any chats using global settings are properly updated.
  void handleGlobalSettingsChange() {
    try {
      // Notify that global settings have changed
      // Chats using global settings will automatically use the new values
      AppLogger.info('Global generation settings changed');
    } catch (e) {
      AppLogger.error('Error handling global settings change', e);
    }
  }

  /// Find differences between two generation settings
  Map<String, dynamic> _findSettingsDifferences(
    GenerationSettings settings1, 
    GenerationSettings settings2
  ) {
    final differences = <String, dynamic>{};

    if (settings1.temperature != settings2.temperature) {
      differences['temperature'] = {
        'chat': settings1.temperature,
        'global': settings2.temperature,
      };
    }

    if (settings1.topK != settings2.topK) {
      differences['topK'] = {
        'chat': settings1.topK,
        'global': settings2.topK,
      };
    }

    if (settings1.topP != settings2.topP) {
      differences['topP'] = {
        'chat': settings1.topP,
        'global': settings2.topP,
      };
    }

    if (settings1.repeatPenalty != settings2.repeatPenalty) {
      differences['repeatPenalty'] = {
        'chat': settings1.repeatPenalty,
        'global': settings2.repeatPenalty,
      };
    }

    if (settings1.maxTokens != settings2.maxTokens) {
      differences['maxTokens'] = {
        'chat': settings1.maxTokens,
        'global': settings2.maxTokens,
      };
    }

    if (settings1.numThread != settings2.numThread) {
      differences['numThread'] = {
        'chat': settings1.numThread,
        'global': settings2.numThread,
      };
    }

    return differences;
  }

  /// Convert generation settings to map for comparison
  Map<String, dynamic> _settingsToMap(GenerationSettings settings) {
    return {
      'temperature': settings.temperature,
      'topK': settings.topK,
      'topP': settings.topP,
      'repeatPenalty': settings.repeatPenalty,
      'maxTokens': settings.maxTokens,
      'numThread': settings.numThread,
    };
  }

  /// Check if two generation settings are identical
  bool _areSettingsIdentical(GenerationSettings settings1, GenerationSettings settings2) {
    return settings1.temperature == settings2.temperature &&
           settings1.topK == settings2.topK &&
           settings1.topP == settings2.topP &&
           settings1.repeatPenalty == settings2.repeatPenalty &&
           settings1.maxTokens == settings2.maxTokens &&
           settings1.numThread == settings2.numThread;
  }
}