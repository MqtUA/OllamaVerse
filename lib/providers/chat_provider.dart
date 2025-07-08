import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../utils/cancellation_token.dart';
import '../models/message.dart';
import '../models/processed_file.dart';
import '../services/ollama_service.dart';
import '../services/chat_history_service.dart';

import '../services/file_content_processor.dart';
import '../services/thinking_model_detection_service.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';

class ChatProvider with ChangeNotifier {
  final ChatHistoryService _chatHistoryService;
  final SettingsProvider _settingsProvider;

  List<Chat> _chats = [];
  Chat? _activeChat;
  List<String> _availableModels = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isProcessingFiles = false;
  bool _isSendingMessage = false; // New flag for overall sending state
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
  CancellationToken _cancellationToken = CancellationToken();

  // Thinking-related state
  final Map<String, bool> _expandedThinkingBubbles = {};
  bool _isThinkingPhase = false;

  // Chat switching state
  bool _shouldScrollToBottomOnChatSwitch = false;

  // Stream management - track which chat is currently generating
  String? _currentGeneratingChatId;

  // File processing state
  final Map<String, FileProcessingProgress> _fileProcessingProgress = {};

  // Getters
  List<Chat> get chats => _chats;
  Chat? get activeChat => _activeChat;
  List<String> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get isSendingMessage => _isSendingMessage;
  bool get isProcessingFiles => _isProcessingFiles;
  String? get error => _error;
  Map<String, FileProcessingProgress> get fileProcessingProgress =>
      _fileProcessingProgress;
  String get currentStreamingResponse => _currentStreamingResponse;
  String get currentDisplayResponse => _currentDisplayResponse;
  String get currentThinkingContent => _currentThinkingContent;
  bool get hasActiveThinkingBubble => _hasActiveThinkingBubble;
  bool get isThinkingPhase => _isThinkingPhase;
  bool get isInsideThinkingBlock => _isInsideThinkingBlock;
  bool get shouldScrollToBottomOnChatSwitch =>
      _shouldScrollToBottomOnChatSwitch;
  SettingsProvider get settingsProvider => _settingsProvider;

  /// Check if the currently active chat is the one that's generating
  bool get isActiveChatGenerating =>
      _isGenerating && _currentGeneratingChatId == _activeChat?.id;

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
    required SettingsProvider settingsProvider,
  })  : _chatHistoryService = chatHistoryService,
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

      // Load chat history immediately (synchronous local operation)
      // This ensures UI shows chats quickly even if Ollama is offline
      await _loadExistingChats();
      await _loadLastSelectedModel();

      // Update UI with loaded chats first
      _safeNotifyListeners();
      AppLogger.info('Chat history loaded successfully, now loading models...');

      // Load models in parallel (network operation that may fail)
      // Don't wait for this to complete - let it load in background
      _loadModels().then((_) {
        // Update UI when models are loaded
        _safeNotifyListeners();
        AppLogger.info('Models loaded successfully after chat history');
      }).catchError((e) {
        // Models failed to load, but app is still functional with chat history
        AppLogger.error(
            'Models failed to load, but chat history is available', e);
        _safeNotifyListeners();
      });

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
      // Wait for settings to be ready before loading models
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

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
      final lastModel = await _settingsProvider.getLastSelectedModel();
      if (lastModel.isNotEmpty) {
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

      // Use setActiveChat to properly trigger scroll flags and other logic
      setActiveChat(sortedChats.first.id);
      AppLogger.info('Set active chat to most recent: ${_activeChat?.title}');
    }
  }

  void cancelGeneration() {
    _cancellationToken.cancel();
    _cancelOngoingGeneration();
  }

  /// Internal method to cancel ongoing generation and reset streaming state
  void _cancelOngoingGeneration() {
    AppLogger.info('Cancelling ongoing generation');
    _isGenerating = false;
    _isProcessingFiles = false;
    _fileProcessingProgress.clear();
    _isThinkingPhase = false;
    _currentStreamingResponse = '';
    _currentDisplayResponse = '';
    _currentThinkingContent = '';
    _hasActiveThinkingBubble = false;
    _isInsideThinkingBlock = false;
    _currentGeneratingChatId = null;
    _cancellationToken = CancellationToken(); // Reset the token
    _safeNotifyListeners();
  }

  List<Message> get displayableMessages {
    if (_activeChat == null) return [];
    return _activeChat!.messages.where((msg) => !msg.isSystem).toList();
  }

  Future<void> _updateChatInList(Chat updatedChat) async {
    try {
      // Save to service - this will trigger the stream update
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
      _cancelOngoingGeneration();
      final selectedModel = modelName ??
          (_lastSelectedModel.isNotEmpty
              ? _lastSelectedModel
              : (_availableModels.isNotEmpty
                  ? _availableModels.first
                  : 'unknown'));

      _lastSelectedModel = selectedModel;
      await _settingsProvider.setLastSelectedModel(selectedModel);

      final newChat = Chat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New chat with $selectedModel',
        modelName: selectedModel,
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      );

      // Add system prompt if available
      final systemPrompt = _settingsProvider.settings.systemPrompt;
      if (systemPrompt.isNotEmpty) {
        final systemMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: systemPrompt,
          role: MessageRole.system,
          timestamp: DateTime.now(),
        );
        newChat.messages.add(systemMessage);
      }

      // Save the chat to the service - this will trigger the stream update
      await _chatHistoryService.saveChat(newChat);

      // Set as active chat
      _activeChat = newChat;
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to create new chat: ${e.toString()}';
      AppLogger.error('Error creating new chat', e);
      _safeNotifyListeners();
    }
  }

  /// Update system prompt for existing chat
  /// This will add/update/remove the system prompt for the specified chat
  Future<void> updateChatSystemPrompt(String chatId) async {
    try {
      final currentChats = _chatHistoryService.chats;
      final chatIndex = currentChats.indexWhere((c) => c.id == chatId);

      if (chatIndex >= 0) {
        final currentChat = currentChats[chatIndex];
        final currentSystemPrompt = _settingsProvider.settings.systemPrompt;

        // Create a new messages list
        List<Message> updatedMessages = [];

        // Remove any existing system messages
        updatedMessages = currentChat.messages
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
          // Insert system message at the beginning
          updatedMessages.insert(0, systemMessage);
        }

        final updatedChat = currentChat.copyWith(
          messages: updatedMessages,
          lastUpdatedAt: DateTime.now(),
        );

        // Update active chat if this is the active one
        if (_activeChat?.id == chatId) {
          _activeChat = updatedChat;
        }

        // Save to service - this will trigger the stream update
        await _chatHistoryService.saveChat(updatedChat);
        _safeNotifyListeners();

        AppLogger.info('Updated system prompt for chat: ${currentChat.title}');
      }
    } catch (e) {
      _error = 'Failed to update chat system prompt: ${e.toString()}';
      AppLogger.error('Error updating chat system prompt', e);
      _safeNotifyListeners();
    }
  }

  /// Update system prompt for all existing chats
  /// This is useful when the user changes the system prompt and wants to apply it to all chats
  Future<void> updateAllChatsSystemPrompt() async {
    try {
      final currentChats = _chatHistoryService.chats;
      final currentSystemPrompt = _settingsProvider.settings.systemPrompt;

      for (final chat in currentChats) {
        // Create a new messages list
        List<Message> updatedMessages = [];

        // Remove any existing system messages
        updatedMessages = chat.messages
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
          // Insert system message at the beginning
          updatedMessages.insert(0, systemMessage);
        }

        final updatedChat = chat.copyWith(
          messages: updatedMessages,
          lastUpdatedAt: DateTime.now(),
        );

        // Update active chat if this is the active one
        if (_activeChat?.id == chat.id) {
          _activeChat = updatedChat;
        }

        // Save to service - this will trigger the stream update
        await _chatHistoryService.saveChat(updatedChat);
      }

      _safeNotifyListeners();
      AppLogger.info('Updated system prompt for ${currentChats.length} chats');
    } catch (e) {
      _error = 'Failed to update system prompt for all chats: ${e.toString()}';
      AppLogger.error('Error updating system prompt for all chats', e);
      _safeNotifyListeners();
    }
  }

  void setActiveChat(String chatId) {
    try {
      final chat = _chats.firstWhere((c) => c.id == chatId);
      final previousActiveChat = _activeChat;

      // Don't cancel generation - let it continue in background for original chat
      // Just log that we're switching away from a generating chat
      if (_isGenerating &&
          previousActiveChat?.id != chatId &&
          _currentGeneratingChatId != null) {
        AppLogger.info(
            'Switching away from generating chat $_currentGeneratingChatId to $chatId (generation continues in background)');
      }

      _activeChat = chat;

      // Check if we're switching to a different chat with existing messages
      // and should trigger auto-scroll to bottom
      // Handle startup case where previousActiveChat is null
      if ((previousActiveChat?.id != chatId || previousActiveChat == null) &&
          chat.messages.isNotEmpty) {
        _shouldScrollToBottomOnChatSwitch = true;
        AppLogger.info(
            'Triggering auto-scroll for chat switch to: ${chat.title}');
      } else {
        _shouldScrollToBottomOnChatSwitch = false;
      }

      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to set active chat: ${e.toString()}';
      AppLogger.error('Error setting active chat', e);
      _safeNotifyListeners();
    }
  }

  // Method to reset the scroll flag after scrolling is complete
  void resetScrollToBottomFlag() {
    _shouldScrollToBottomOnChatSwitch = false;
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    try {
      // Find the chat in the current list
      final currentChats = _chatHistoryService.chats;
      final chatIndex = currentChats.indexWhere((c) => c.id == chatId);

      if (chatIndex >= 0) {
        final updatedChat = currentChats[chatIndex].copyWith(
          title: newTitle,
          lastUpdatedAt: DateTime.now(),
        );

        // Update active chat if this is the active one
        if (_activeChat?.id == chatId) {
          _activeChat = updatedChat;
        }

        // Save to service - this will trigger the stream update
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
      // Find the chat in the current list
      final currentChats = _chatHistoryService.chats;
      final chatIndex = currentChats.indexWhere((c) => c.id == chatId);

      if (chatIndex >= 0) {
        final currentChat = currentChats[chatIndex];
        // Check if this is a new chat (only has system messages, no user/assistant messages)
        final hasUserMessages =
            currentChat.messages.where((msg) => !msg.isSystem).isNotEmpty;
        bool isDefaultTitle = !hasUserMessages &&
            (currentChat.title == 'New Chat' ||
                currentChat.title.startsWith('New chat with'));

        _lastSelectedModel = newModelName;
        await _settingsProvider.setLastSelectedModel(newModelName);

        final updatedChat = currentChat.copyWith(
          modelName: newModelName,
          title: isDefaultTitle
              ? 'New chat with $newModelName'
              : currentChat.title,
          lastUpdatedAt: DateTime.now(),
        );

        // Update active chat if this is the active one
        if (_activeChat?.id == chatId) {
          _activeChat = updatedChat;
        }

        // Save to service - this will trigger the stream update
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
      // Find the index of the chat to be deleted
      final int index = _chats.indexWhere((c) => c.id == chatId);
      if (index == -1) return; // Chat not found

      // Optimistically remove the chat from the local list
      _chats.removeAt(index);

      // If the deleted chat was active, set active chat to most recent or null
      if (_activeChat?.id == chatId) {
        _cancelOngoingGeneration(); // Cancel generation if active chat is deleted
        _activeChat = _chats.isNotEmpty ? _chats.first : null;
      }

      _safeNotifyListeners(); // Notify listeners immediately to update UI

      // Now, perform the asynchronous deletion from the history service
      await _chatHistoryService.deleteChat(chatId);

      // The _chatHistoryService.chatStream listener will eventually update _chats
      // with the confirmed state. If the deletion fails, the stream should
      // ideally re-emit the original list, which will then cause the UI to revert.
      // For now, we'll rely on the stream for eventual consistency.
    } catch (e) {
      _error = 'Failed to delete chat: ${e.toString()}';
      AppLogger.error('Error deleting chat', e);
      _safeNotifyListeners();
      // If deletion fails, the _chatHistoryService.chatStream should ideally
      // re-emit the original list, which will then cause the UI to revert.
      // If not, we might need to re-insert the chat here.
    }
  }

  Future<void> sendMessage(String content,
      {List<String>? attachedFiles}) async {
    if (_activeChat == null) {
      _error = 'No active chat';
      _safeNotifyListeners();
      return;
    }
    if (_isSendingMessage) {
      _error = 'A message is already being sent or processed.';
      _safeNotifyListeners();
      return;
    }

    try {
      _isSendingMessage = true; // Set sending flag at the start
      _safeNotifyListeners();
      // Process attached files if any
      List<ProcessedFile> processedFiles = [];
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        _isProcessingFiles = true;
        _fileProcessingProgress.clear();
        _safeNotifyListeners();

        AppLogger.info('Processing ${attachedFiles.length} attached files');
        try {
          processedFiles = await FileContentProcessor.processFiles(
            attachedFiles,
            onProgress: (progress) {
              _fileProcessingProgress[progress.filePath] = progress;
              _safeNotifyListeners();
            },
            isCancelled: () => _cancellationToken.isCancelled,
          );
          AppLogger.info(
              'Successfully processed ${processedFiles.length} files');
        } catch (e) {
          AppLogger.error('Error processing files', e);
          _error = 'Failed to process attached files: $e';
          _isProcessingFiles = false;
          _safeNotifyListeners();
          return;
        } finally {
          _isProcessingFiles = false;
          _fileProcessingProgress.clear();
          _safeNotifyListeners();
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
      _currentGeneratingChatId =
          _activeChat!.id; // Track which chat is generating
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
              contextLength: _settingsProvider.settings.contextLength,
              isCancelled: () => _cancellationToken.isCancelled,
            )) {
          // CRITICAL: Check if generation was explicitly cancelled (but allow chat switching)
          if (_cancellationToken.isCancelled) {
            AppLogger.warning('Stream cancelled: generation was stopped');
            break; // Exit the stream loop only if generation was explicitly cancelled
          }

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
              contextLength: _settingsProvider.settings.contextLength,
              isCancelled: () => _cancellationToken.isCancelled,
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

      // Find the chat that initiated the generation (it might not be the active chat anymore)
      final generatingChat = _chats.firstWhere(
        (chat) => chat.id == _currentGeneratingChatId,
        orElse: () => _activeChat!,
      );

      final updatedWithAiMessages = [...generatingChat.messages, aiMessage];
      final updatedWithAiChat = generatingChat.copyWith(
        messages: updatedWithAiMessages,
        lastUpdatedAt: DateTime.now(),
        context: newContext, // Store the context for future requests
      );

      // Clear streaming state immediately to prevent duplicate message bubbles
      _isGenerating = false;
      _currentStreamingResponse = '';
      _currentDisplayResponse = '';
      _currentThinkingContent = '';
      _hasActiveThinkingBubble = false;
      _isInsideThinkingBlock = false;
      _isThinkingPhase = false;

      // Update the generating chat, not necessarily the active chat
      await _updateChatInList(updatedWithAiChat);

      // If the generating chat is currently active, update the active chat reference
      if (_activeChat?.id == _currentGeneratingChatId) {
        _activeChat = updatedWithAiChat;
      }

      // Notify UI that streaming is complete and message is final
      _safeNotifyListeners();

      // Auto-generate chat title if this is the first AI response and chat has default title
      // Keep the generating chat ID until title generation is complete
      await _autoGenerateChatTitleIfNeeded(
          updatedWithAiChat, userMessage.content, finalResponse);
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
      // Clear any remaining streaming state (in case of errors)
      _isGenerating = false;
      _isProcessingFiles = false;
      _fileProcessingProgress.clear();
      _isThinkingPhase = false;
      _currentStreamingResponse = '';
      _currentDisplayResponse = '';
      _currentThinkingContent = '';
      _hasActiveThinkingBubble = false;
      _isInsideThinkingBlock = false;
      _currentGeneratingChatId = null; // Clear tracking
      _isSendingMessage = false; // Reset overall sending flag
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

  /// Auto-generate chat title if this is the first AI response and chat has default title
  Future<void> _autoGenerateChatTitleIfNeeded(
      Chat chat, String userMessageContent, String aiResponseContent) async {
    try {
      // Only auto-name if the chat has a default title
      if (chat.title == 'New Chat' || chat.title.startsWith('New chat with')) {
        AppLogger.info('Auto-generating title for chat: ${chat.id}');

        final newTitle = await _generateChatTitle(
            userMessageContent, aiResponseContent, chat.modelName);
        if (newTitle.isNotEmpty && newTitle != chat.title) {
          await updateChatTitle(chat.id, newTitle);
          AppLogger.info('Auto-generated title: $newTitle');
        }
      }
    } catch (e) {
      AppLogger.error('Error auto-generating chat title', e);
      // Don't throw - auto-naming is not critical functionality
    }
  }

  /// Generate a concise chat title using the same Ollama model
  Future<String> _generateChatTitle(
      String userMessage, String aiResponse, String modelName) async {
    try {
      // Wait for settings to be ready before generating title
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Filter thinking content from AI response for better title generation
      String processedAiResponse = aiResponse;

      // Check if the response contains thinking content and extract final answer
      if (ThinkingModelDetectionService.hasThinkingContent(aiResponse)) {
        final thinkingContent =
            ThinkingModelDetectionService.extractThinkingContent(aiResponse);
        processedAiResponse = thinkingContent.finalAnswer.isNotEmpty
            ? thinkingContent.finalAnswer
            : aiResponse;
        AppLogger.info(
            'Filtered thinking content for title generation. Original length: ${aiResponse.length}, Filtered length: ${processedAiResponse.length}');
      }

      // Check if AI response is too short or uninformative
      final isAiResponseUseful = processedAiResponse.trim().length > 20 &&
          !processedAiResponse
              .toLowerCase()
              .contains(RegExp(r'^(here|this|that|it|what)\s+(is|are|we|got)'));

      // Truncate user message if it's very long (from large files)
      String truncatedUserMessage = userMessage;
      if (userMessage.length > 200) {
        // Take first meaningful sentence or first 200 chars
        final sentences = userMessage.split(RegExp(r'[.!?]+'));
        if (sentences.isNotEmpty && sentences.first.length <= 200) {
          truncatedUserMessage = sentences.first.trim();
        } else {
          truncatedUserMessage = '${userMessage.substring(0, 200)}...';
        }
      }

      // Improved prompt that focuses more on user intent when AI response is poor
      String prompt;
      if (isAiResponseUseful) {
        // Use both user and AI content for title
        prompt =
            '''Based on this conversation, create a concise 2-5 word title without quotes or explanation. Reply only with the title:

User asked: $truncatedUserMessage

AI responded: ${processedAiResponse.length > 300 ? '${processedAiResponse.substring(0, 300)}...' : processedAiResponse}

Title:''';
      } else {
        // Focus primarily on user message when AI response is unhelpful
        prompt =
            '''Based on the user's request, create a concise 2-5 word title without quotes or explanation. Reply only with the title:

User asked: $truncatedUserMessage

Title:''';
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final titleResponse = await ollamaService
          .generateResponseWithFiles(prompt, model: modelName);

      // Clean up the response - remove quotes, extra whitespace, and limit length
      // Also filter any thinking content that might appear in the title response itself
      String cleanTitle = titleResponse;

      // Filter thinking content from title response if present
      if (ThinkingModelDetectionService.hasThinkingContent(titleResponse)) {
        final titleThinkingContent =
            ThinkingModelDetectionService.extractThinkingContent(titleResponse);
        cleanTitle = titleThinkingContent.finalAnswer.isNotEmpty
            ? titleThinkingContent.finalAnswer
            : titleResponse;
      }

      cleanTitle = cleanTitle
          .trim()
          .replaceAll('"', '') // Remove quotes
          .replaceAll("'", '') // Remove single quotes
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();

      // Remove common prefixes that might appear
      cleanTitle = cleanTitle.replaceAll(
          RegExp(r'^(title:|the title is:?|title should be:?)\s*',
              caseSensitive: false),
          '');

      // Limit to 5 words as requested (2-5 word range)
      final words = cleanTitle.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.length > 5) {
        cleanTitle = words.take(5).join(' ');
      }

      // Enhanced fallback logic
      if (cleanTitle.isEmpty || cleanTitle.length < 3 || words.length < 2) {
        // Extract key words from user message for fallback
        final userWords = truncatedUserMessage
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((w) =>
                w.length > 3 &&
                ![
                  'what',
                  'this',
                  'that',
                  'about',
                  'please',
                  'could',
                  'would',
                  'should'
                ].contains(w))
            .take(3)
            .join(' ');

        if (userWords.isNotEmpty) {
          return 'Chat about $userWords';
        } else {
          return 'Document Analysis Chat';
        }
      }

      return cleanTitle;
    } catch (e) {
      AppLogger.error('Error generating chat title', e);
      return 'Document Analysis Chat'; // Better fallback than empty string
    }
  }

  /// Validate system prompt support for the current model
  Future<Map<String, dynamic>> validateCurrentModelSystemPromptSupport() async {
    final currentModel = _activeChat?.modelName ?? _lastSelectedModel;
    if (currentModel.isEmpty) {
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
          await ollamaService.validateSystemPromptSupport(currentModel);

      return validation;
    } catch (e) {
      AppLogger.error('Error validating system prompt support', e);
      return {
        'supported': true, // Default to supported
        'modelName': currentModel,
        'fallbackMethod': 'native',
        'recommendation':
            'Unable to validate system prompt support. Assuming native support.',
        'error': e.toString(),
      };
    }
  }

  /// Get system prompt handling strategy for current model
  String getCurrentModelSystemPromptStrategy() {
    final currentModel = _activeChat?.modelName ?? _lastSelectedModel;
    if (currentModel.isEmpty) return 'native';

    try {
      // Note: This is a synchronous method, but we should ideally make it async
      // For now, we check if settings are still loading and return default
      if (_settingsProvider.isLoading) {
        AppLogger.warning('Settings still loading, using default strategy');
        return 'native';
      }

      final ollamaService = _settingsProvider.getOllamaService();

      final strategy = ollamaService.getSystemPromptStrategy(currentModel);

      return strategy;
    } catch (e) {
      AppLogger.error('Error getting system prompt strategy', e);
      return 'native'; // Default fallback
    }
  }
}
