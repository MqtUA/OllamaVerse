import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/processed_file.dart';
import '../services/ollama_service.dart';
import '../services/chat_history_service.dart';
import '../services/settings_service.dart';
import '../services/file_content_processor.dart';
import '../services/thinking_model_detection_service.dart';
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
  String _currentDisplayResponse = '';
  String _currentThinkingContent = ''; // Live thinking content being streamed
  bool _isInsideThinkingBlock =
      false; // Track if we're currently inside a thinking block
  bool _hasActiveThinkingBubble =
      false; // Track if there's an active thinking bubble
  StreamSubscription? _chatStreamSubscription;
  bool _disposed = false;

  // Thinking-related state
  final Map<String, bool> _expandedThinkingBubbles = {};
  bool _isThinkingPhase = false;

  // Getters
  List<Chat> get chats => _chats;
  Chat? get activeChat => _activeChat;
  List<String> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  String get currentStreamingResponse => _currentStreamingResponse;
  String get currentDisplayResponse => _currentDisplayResponse;
  String get currentThinkingContent => _currentThinkingContent;
  bool get hasActiveThinkingBubble => _hasActiveThinkingBubble;
  bool get isThinkingPhase => _isThinkingPhase;
  bool get isInsideThinkingBlock => _isInsideThinkingBlock;
  SettingsProvider get settingsProvider => _settingsProvider;

  /// Check if a thinking bubble is expanded
  bool isThinkingBubbleExpanded(String messageId) {
    return _expandedThinkingBubbles[messageId] ?? false;
  }

  /// Toggle thinking bubble expansion
  void toggleThinkingBubble(String messageId) {
    _expandedThinkingBubbles[messageId] =
        !(_expandedThinkingBubbles[messageId] ?? false);
    _safeNotifyListeners();
  }

  /// Filter thinking content from streaming response for real-time display
  /// Also extracts live thinking content for the thinking bubble
  String _filterThinkingFromStream(String fullResponse) {
    if (fullResponse.isEmpty) return fullResponse;

    // Reset thinking content
    _currentThinkingContent = '';
    _hasActiveThinkingBubble = false;

    // Check for thinking markers
    final thinkingMarkers = [
      {'open': '<think>', 'close': '</think>'},
      {'open': '<thinking>', 'close': '</thinking>'},
      {'open': '<reasoning>', 'close': '</reasoning>'},
      {'open': '<analysis>', 'close': '</analysis>'},
      {'open': '<reflection>', 'close': '</reflection>'},
    ];

    String result = fullResponse;

    // Process each type of thinking marker
    for (final markerPair in thinkingMarkers) {
      final openMarker = markerPair['open']!;
      final closeMarker = markerPair['close']!;

      // Keep processing until no more markers of this type
      while (true) {
        final openIndex =
            result.toLowerCase().indexOf(openMarker.toLowerCase());
        if (openIndex == -1) break;

        final closeIndex = result
            .toLowerCase()
            .indexOf(closeMarker.toLowerCase(), openIndex + openMarker.length);

        if (closeIndex == -1) {
          // Opening marker found but no closing marker yet
          // Extract thinking content and hide from main display
          final thinkingStart = openIndex + openMarker.length;
          _currentThinkingContent =
              fullResponse.substring(thinkingStart).trim();
          _hasActiveThinkingBubble = true;
          _isInsideThinkingBlock = true;

          // Hide everything from the opening marker onwards
          result = result.substring(0, openIndex).trim();
          break;
        } else {
          // Complete thinking block found
          final thinkingStart = openIndex + openMarker.length;
          _currentThinkingContent =
              fullResponse.substring(thinkingStart, closeIndex).trim();
          _hasActiveThinkingBubble = _currentThinkingContent.isNotEmpty;
          _isInsideThinkingBlock = false;

          // Remove the complete thinking block from display
          final beforeThinking = result.substring(0, openIndex);
          final afterThinking =
              result.substring(closeIndex + closeMarker.length);
          result = (beforeThinking + afterThinking).trim();
        }
      }
    }

    // Clean up any extra whitespace
    result = result.replaceAll(
        RegExp(r'\n\s*\n\s*\n'), '\n\n'); // Remove excessive newlines

    return result;
  }

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

      // Wait for settings to load before attempting any network operations
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Listen to chat updates
      _chatStreamSubscription = _chatHistoryService.chatStream.listen(
        (chats) {
          _chats = chats;
          // Set active chat to most recent if no active chat is set
          _setActiveToMostRecentIfNeeded();
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
        _loadExistingChats(), // Load existing chats on startup
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
      AppLogger.info('Successfully loaded ${_availableModels.length} models');
    } on OllamaConnectionException catch (e) {
      _error =
          'Cannot connect to Ollama server. Please check your connection settings.';
      AppLogger.error('Connection error loading models', e);
      // Don't rethrow - allow app to continue with empty model list
      _availableModels = [];
    } on OllamaApiException catch (e) {
      _error = 'Error communicating with Ollama: ${e.message}';
      AppLogger.error('API error loading models', e);
      // Don't rethrow - allow app to continue with empty model list
      _availableModels = [];
    } catch (e) {
      _error = 'Unexpected error loading models: ${e.toString()}';
      AppLogger.error('Error loading models', e);
      // Don't rethrow - allow app to continue with empty model list
      _availableModels = [];
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

  /// Load existing chats on app startup
  Future<void> _loadExistingChats() async {
    try {
      AppLogger.info('Loading existing chats on startup');

      // Wait for chat history service to finish initializing
      int attempts = 0;
      const maxAttempts = 50; // 5 seconds max wait

      while (attempts < maxAttempts && !_chatHistoryService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!_chatHistoryService.isInitialized) {
        AppLogger.warning(
            'ChatHistoryService initialization timed out after 5 seconds');
      }

      // Force an initial update with current chats
      _chats = _chatHistoryService.chats;
      _setActiveToMostRecentIfNeeded();

      AppLogger.info('Successfully loaded ${_chats.length} existing chats');
    } catch (e) {
      AppLogger.error('Error loading existing chats', e);
    }
  }

  /// Set active chat to most recent if no active chat is currently set
  void _setActiveToMostRecentIfNeeded() {
    // Only set active chat if none is currently active and chats exist
    if (_activeChat == null && _chats.isNotEmpty) {
      // Sort chats by last updated time to find most recent
      final sortedChats = List<Chat>.from(_chats);
      sortedChats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

      _activeChat = sortedChats.first;
      AppLogger.info('Set active chat to most recent: ${_activeChat?.title}');
    }
  }

  void cancelGeneration() {
    _isGenerating = false;
    _currentStreamingResponse = '';
    _safeNotifyListeners();
  }

  List<Message> get displayableMessages {
    if (_activeChat == null) return [];
    return _activeChat!.messages.where((msg) => !msg.isSystem).toList();
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
      // Process attached files if any
      List<ProcessedFile> processedFiles = [];
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        AppLogger.info('Processing ${attachedFiles.length} attached files');
        try {
          processedFiles =
              await FileContentProcessor.processFiles(attachedFiles);
          AppLogger.info(
              'Successfully processed ${processedFiles.length} files');
        } catch (e) {
          AppLogger.error('Error processing files', e);
          _error = 'Failed to process attached files: $e';
          _safeNotifyListeners();
          return;
        }
      }

      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        processedFiles: processedFiles,
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
      _currentDisplayResponse = '';
      _isInsideThinkingBlock = false;
      _safeNotifyListeners();

      final model = _activeChat!.modelName;

      // Initially assume any model might have thinking capability
      // We'll detect it from the actual response content
      _isThinkingPhase = true; // Start in thinking phase for all models

      // Check if live response is enabled in settings
      final showLiveResponse = _settingsProvider.settings.showLiveResponse;

      String finalResponse = '';
      List<int>? newContext;

      if (showLiveResponse) {
        // Use streaming response for live updates with file support and context
        await for (final streamResponse in _settingsProvider
            .getOllamaService()
            .generateStreamingResponseWithContext(
              content,
              model: model,
              processedFiles: processedFiles.isNotEmpty ? processedFiles : null,
              context: _activeChat!.context,
              conversationHistory: _activeChat!.messages,
            )) {
          if (streamResponse.response.isNotEmpty) {
            _currentStreamingResponse += streamResponse.response;

            // Filter thinking content for display
            _currentDisplayResponse =
                _filterThinkingFromStream(_currentStreamingResponse);

            // Update thinking phase based on content
            if (_isThinkingPhase &&
                _currentDisplayResponse.isNotEmpty &&
                !_isInsideThinkingBlock) {
              // We have visible content and we're not inside a thinking block
              // This means the model has moved on to the actual answer
              _isThinkingPhase = false;
            }

            _safeNotifyListeners(); // Update UI with filtered content
          }
          // Capture the final context when streaming is done
          if (streamResponse.done && streamResponse.context != null) {
            newContext = streamResponse.context;
          }
        }
        finalResponse = _currentStreamingResponse;
      } else {
        // Use non-streaming response for faster completion with file support and context
        final ollamaResponse = await _settingsProvider
            .getOllamaService()
            .generateResponseWithContext(
              content,
              model: model,
              processedFiles: processedFiles.isNotEmpty ? processedFiles : null,
              context: _activeChat!.context,
              conversationHistory: _activeChat!.messages,
            );
        finalResponse = ollamaResponse.response;
        newContext = ollamaResponse.context;
      }

      // Create AI message and detect thinking content from the actual response
      var aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: finalResponse,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );

      // Check if this response contains thinking content
      final hasThinkingContent =
          ThinkingModelDetectionService.hasThinkingContent(finalResponse);

      if (hasThinkingContent && finalResponse.isNotEmpty) {
        AppLogger.info(
            'Detected thinking content in response from model: $model');
        AppLogger.info('Response length: ${finalResponse.length}');
        AppLogger.info(
            'Response preview: ${finalResponse.substring(0, 200.clamp(0, finalResponse.length))}');

        // Extract thinking content and get the filtered final answer
        final thinkingContent =
            ThinkingModelDetectionService.extractThinkingContent(finalResponse);

        // Create message with thinking content and filtered content
        aiMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: thinkingContent.finalAnswer,
          role: MessageRole.assistant,
          timestamp: DateTime.now(),
          thinkingContent: thinkingContent,
        );

        AppLogger.info('Thinking extraction result:');
        AppLogger.info('  hasThinking: ${aiMessage.hasThinking}');
        AppLogger.info(
            '  thinkingText length: ${aiMessage.thinkingText?.length ?? 0}');
        AppLogger.info('  finalAnswer length: ${aiMessage.finalAnswer.length}');
        AppLogger.info('  message content length: ${aiMessage.content.length}');
      } else {
        AppLogger.info(
            'No thinking content detected in response from model: $model');
      }

      final updatedWithAiMessages = [...updatedMessages, aiMessage];
      final updatedWithAiChat = _activeChat!.copyWith(
        messages: updatedWithAiMessages,
        lastUpdatedAt: DateTime.now(),
        context: newContext, // Store the context for future requests
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
      _isThinkingPhase = false;
      _currentStreamingResponse = '';
      _currentDisplayResponse = '';
      _currentThinkingContent = '';
      _hasActiveThinkingBubble = false;
      _isInsideThinkingBlock = false;
      _safeNotifyListeners();
    }
  }

  Future<void> sendMessageWithOptionalChatCreation(
    String message, {
    List<String>? attachedFiles,
  }) async {
    if (message.isEmpty) return;

    // Only create new chat if no active chat exists
    if (_activeChat == null) {
      if (_availableModels.isEmpty) {
        _error = 'No models available. Please check Ollama server connection.';
        _safeNotifyListeners();
        return;
      }

      // Use last selected model if available and valid, otherwise use first available model
      final modelToUse = _lastSelectedModel.isNotEmpty &&
              _availableModels.contains(_lastSelectedModel)
          ? _lastSelectedModel
          : _availableModels.first;

      AppLogger.info(
          'Creating new chat with model: $modelToUse (using last selected model preference)');
      await createNewChat(modelToUse);
    }

    await sendMessage(message, attachedFiles: attachedFiles);
  }

  Future<void> refreshModels() async {
    try {
      _error = null; // Clear any previous errors
      _safeNotifyListeners();

      await _loadModels();
      _safeNotifyListeners();

      if (_availableModels.isNotEmpty) {
        AppLogger.info(
            'Models refreshed successfully: ${_availableModels.length} models available');
      }
    } catch (e) {
      // _loadModels now handles its own errors gracefully
      AppLogger.error('Error refreshing models', e);
      _safeNotifyListeners();
    }
  }

  /// Retry connection and model loading (useful after settings changes)
  Future<bool> retryConnection() async {
    try {
      _error = null;
      _safeNotifyListeners();

      // Wait for settings to be ready
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await _loadModels();
      _safeNotifyListeners();

      return _availableModels.isNotEmpty;
    } catch (e) {
      AppLogger.error('Error retrying connection', e);
      _safeNotifyListeners();
      return false;
    }
  }
}
