import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/chat_message.dart';
import '../services/ollama_service.dart';
import '../services/chat_history_service.dart';
import '../services/settings_service.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';

class ChatProvider with ChangeNotifier {
  final ChatHistoryService _chatHistoryService;
  final SettingsService _settingsService;
  final SettingsProvider _settingsProvider;

  List<Chat> _chats = [];
  Chat? _activeChat;
  List<String> _availableModels = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  String _lastSelectedModel = '';
  String _currentStreamingResponse = '';
  StreamSubscription? _chatStreamSubscription;
  bool _disposed = false;

  // Getters
  List<Chat> get chats => _chats;
  Chat? get activeChat => _activeChat;
  List<String> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  String get currentStreamingResponse => _currentStreamingResponse;

  ChatProvider({
    required ChatHistoryService chatHistoryService,
    required SettingsService settingsService,
    required SettingsProvider settingsProvider,
  })  : _chatHistoryService = chatHistoryService,
        _settingsService = settingsService,
        _settingsProvider = settingsProvider {
    _initialize();
  }

  @override
  void dispose() {
    _disposed = true;
    _chatStreamSubscription?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      _safeNotifyListeners();

      // Listen to chat updates
      _chatStreamSubscription = _chatHistoryService.chatStream.listen(
        (chats) {
          _chats = chats;
          _safeNotifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load chats: $error';
          _isLoading = false;
          _safeNotifyListeners();
          AppLogger.error('Error in chat stream', error);
        },
      );

      // Load initial data
      await Future.wait([
        _loadModels(),
        _loadLastSelectedModel(),
      ]);

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: ${e.toString()}';
      _isLoading = false;
      _safeNotifyListeners();
      AppLogger.error('Error initializing chat provider', e);
    }
  }

  Future<void> _loadModels() async {
    try {
      final ollamaService = _settingsProvider.getOllamaService();
      _availableModels = await ollamaService.getModels();
    } on OllamaConnectionException catch (e) {
      _error =
          'Cannot connect to Ollama server. Please check your connection settings.';
      AppLogger.error('Connection error loading models', e);
      rethrow;
    } on OllamaApiException catch (e) {
      _error = 'Error communicating with Ollama: ${e.message}';
      AppLogger.error('API error loading models', e);
      rethrow;
    } catch (e) {
      _error = 'Unexpected error loading models: ${e.toString()}';
      AppLogger.error('Error loading models', e);
      rethrow;
    }
  }

  Future<void> _loadLastSelectedModel() async {
    try {
      final lastModel = await _settingsService.getLastSelectedModel();
      if (lastModel != null) {
        _lastSelectedModel = lastModel;
      }
    } catch (e) {
      AppLogger.error('Error loading last selected model', e);
    }
  }

  void cancelGeneration() {
    _isGenerating = false;
    _currentStreamingResponse = '';
    _safeNotifyListeners();
  }

  List<ChatMessage> get displayableMessages {
    if (_activeChat == null) return [];
    return _activeChat!.toChatMessages();
  }

  Future<void> _updateChatInList(Chat updatedChat) async {
    try {
      final index = _chats.indexWhere((c) => c.id == updatedChat.id);
      if (index >= 0) {
        _chats[index] = updatedChat;
      }
      await _chatHistoryService.saveChat(updatedChat);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to update chat: ${e.toString()}';
      AppLogger.error('Error updating chat in list', e);
      _safeNotifyListeners();
    }
  }

  Future<void> createNewChat([String? modelName]) async {
    try {
      final selectedModel = modelName ??
          (_lastSelectedModel.isNotEmpty
              ? _lastSelectedModel
              : (_availableModels.isNotEmpty
                  ? _availableModels.first
                  : 'unknown'));

      _lastSelectedModel = selectedModel;
      await _settingsService.setLastSelectedModel(selectedModel);

      final newChat = Chat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New chat with $selectedModel',
        modelName: selectedModel,
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      );

      // Add system prompt if available
      final systemPrompt = _settingsService.systemPrompt;
      if (systemPrompt.isNotEmpty) {
        final systemMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: systemPrompt,
          role: MessageRole.system,
          timestamp: DateTime.now(),
        );
        newChat.messages.add(systemMessage);
      }

      _chats.insert(0, newChat);
      _activeChat = newChat;
      await _chatHistoryService.saveChat(newChat);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to create new chat: ${e.toString()}';
      AppLogger.error('Error creating new chat', e);
      _safeNotifyListeners();
    }
  }

  void setActiveChat(String chatId) {
    try {
      final chat = _chats.firstWhere((c) => c.id == chatId);
      _activeChat = chat;
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to set active chat: ${e.toString()}';
      AppLogger.error('Error setting active chat', e);
      _safeNotifyListeners();
    }
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    try {
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index >= 0) {
        final updatedChat = _chats[index].copyWith(
          title: newTitle,
          lastUpdatedAt: DateTime.now(),
        );
        _chats[index] = updatedChat;

        if (_activeChat?.id == chatId) {
          _activeChat = updatedChat;
        }

        await _chatHistoryService.saveChat(updatedChat);
        _safeNotifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update chat title: ${e.toString()}';
      AppLogger.error('Error updating chat title', e);
      _safeNotifyListeners();
    }
  }

  Future<void> updateChatModel(String chatId, String newModelName) async {
    try {
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index >= 0) {
        bool isDefaultTitle = _chats[index].messages.isEmpty &&
            (_chats[index].title == 'New Chat' ||
                _chats[index].title.startsWith('New chat with'));

        _lastSelectedModel = newModelName;
        await _settingsService.setLastSelectedModel(newModelName);

        final updatedChat = _chats[index].copyWith(
          modelName: newModelName,
          title: isDefaultTitle
              ? 'New chat with $newModelName'
              : _chats[index].title,
          lastUpdatedAt: DateTime.now(),
        );

        _chats[index] = updatedChat;

        if (_activeChat?.id == chatId) {
          _activeChat = updatedChat;
        }

        await _chatHistoryService.saveChat(updatedChat);
        _safeNotifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update chat model: ${e.toString()}';
      AppLogger.error('Error updating chat model', e);
      _safeNotifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      _chats.removeWhere((c) => c.id == chatId);

      if (_activeChat?.id == chatId) {
        _activeChat = _chats.isNotEmpty ? _chats.first : null;
      }

      await _chatHistoryService.deleteChat(chatId);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to delete chat: ${e.toString()}';
      AppLogger.error('Error deleting chat', e);
      _safeNotifyListeners();
    }
  }

  Future<void> sendMessage(String content,
      {List<String>? attachedFiles}) async {
    if (_activeChat == null) {
      _error = 'No active chat';
      _safeNotifyListeners();
      return;
    }
    if (_isGenerating) {
      _error = 'Already generating a response';
      _safeNotifyListeners();
      return;
    }

    try {
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      );

      final updatedMessages = [..._activeChat!.messages, userMessage];
      final updatedChat = _activeChat!.copyWith(
        messages: updatedMessages,
        lastUpdatedAt: DateTime.now(),
      );

      _activeChat = updatedChat;
      await _updateChatInList(updatedChat);

      _isGenerating = true;
      _currentStreamingResponse = '';
      _safeNotifyListeners();

      final model = _activeChat!.modelName;

      // Check if live response is enabled in settings
      final showLiveResponse = _settingsProvider.settings.showLiveResponse;

      String finalResponse = '';

      if (showLiveResponse) {
        // Use streaming response for live updates
        await for (final chunk
            in _settingsProvider.getOllamaService().generateStreamingResponse(
                  content,
                  model: model,
                )) {
          _currentStreamingResponse += chunk;
          _safeNotifyListeners(); // Update UI with each chunk
        }
        finalResponse = _currentStreamingResponse;
      } else {
        // Use non-streaming response for faster completion
        finalResponse =
            await _settingsProvider.getOllamaService().generateResponse(
                  content,
                  model: model,
                );
      }

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: finalResponse,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );

      final updatedWithAiMessages = [...updatedMessages, aiMessage];
      final updatedWithAiChat = _activeChat!.copyWith(
        messages: updatedWithAiMessages,
        lastUpdatedAt: DateTime.now(),
      );

      _activeChat = updatedWithAiChat;
      await _updateChatInList(updatedWithAiChat);
    } on OllamaConnectionException catch (e) {
      _error = 'Cannot connect to Ollama server. Please check your connection.';
      AppLogger.error('Connection error sending message', e);
    } on OllamaApiException catch (e) {
      _error = 'Error from Ollama: ${e.message}';
      AppLogger.error('API error sending message', e);
    } catch (e) {
      _error = 'Failed to generate response: ${e.toString()}';
      AppLogger.error('Error sending message', e);
    } finally {
      _isGenerating = false;
      _currentStreamingResponse = '';
      _safeNotifyListeners();
    }
  }

  Future<void> sendMessageWithOptionalChatCreation(
    String message, {
    List<String>? attachedFiles,
  }) async {
    if (message.isEmpty) return;

    if (_activeChat == null) {
      if (_availableModels.isEmpty) {
        _error = 'No models available. Please check Ollama server connection.';
        _safeNotifyListeners();
        return;
      }
      // Use last selected model if available, otherwise use first available model
      final modelToUse = _lastSelectedModel.isNotEmpty &&
              _availableModels.contains(_lastSelectedModel)
          ? _lastSelectedModel
          : _availableModels.first;
      await createNewChat(modelToUse);
    }
    await sendMessage(message, attachedFiles: attachedFiles);
  }

  Future<void> refreshModels() async {
    try {
      _error = null;
      await _loadModels();
      _safeNotifyListeners();
    } on OllamaConnectionException catch (e) {
      _error =
          'Cannot connect to Ollama server. Please check your connection settings.';
      AppLogger.error('Connection error refreshing models', e);
      _safeNotifyListeners();
    } on OllamaApiException catch (e) {
      _error = 'Error communicating with Ollama: ${e.message}';
      AppLogger.error('API error refreshing models', e);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to refresh models: ${e.toString()}';
      AppLogger.error('Error refreshing models', e);
      _safeNotifyListeners();
    }
  }
}
