import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/processed_file.dart';
import '../services/ollama_service.dart';
import '../services/chat_history_service.dart';
import '../services/model_manager.dart';
import '../services/chat_state_manager.dart';
import '../services/message_streaming_service.dart';
import '../services/chat_title_generator.dart';
import '../services/file_processing_manager.dart';
import '../services/file_content_processor.dart';
import '../services/thinking_model_detection_service.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';

/// Refactored ChatProvider that delegates to extracted services
/// Maintains all existing public method signatures for backward compatibility
class ChatProvider with ChangeNotifier {
  final ChatHistoryService _chatHistoryService;
  final SettingsProvider _settingsProvider;
  final ModelManager _modelManager;
  final ChatStateManager _chatStateManager;
  final MessageStreamingService _messageStreamingService;
  final ChatTitleGenerator _chatTitleGenerator;
  final FileProcessingManager _fileProcessingManager;

  // Core state
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSendingMessage = false;
  String? _error;
  String? _currentGeneratingChatId;
  
  // Stream subscriptions
  StreamSubscription? _chatStateSubscription;
  bool _disposed = false;

  ChatProvider({
    required ChatHistoryService chatHistoryService,
    required SettingsProvider settingsProvider,
    required ModelManager modelManager,
    required ChatStateManager chatStateManager,
    required MessageStreamingService messageStreamingService,
    required ChatTitleGenerator chatTitleGenerator,
    required FileProcessingManager fileProcessingManager,
  })  : _chatHistoryService = chatHistoryService,
        _settingsProvider = settingsProvider,
        _modelManager = modelManager,
        _chatStateManager = chatStateManager,
        _messageStreamingService = messageStreamingService,
        _chatTitleGenerator = chatTitleGenerator,
        _fileProcessingManager = fileProcessingManager {
    _initialize();
  }

  // Getters - delegate to services
  List<Chat> get chats => _chatStateManager.chats;
  Chat? get activeChat => _chatStateManager.activeChat;
  List<String> get availableModels => _modelManager.availableModels;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get isSendingMessage => _isSendingMessage;
  bool get isProcessingFiles => _fileProcessingManager.isProcessingFiles;

  // Add unified getter for any operation in progress
  bool get isAnyOperationInProgress =>
      _isGenerating || _isSendingMessage || isProcessingFiles;

  /// Check if the currently active chat is the one that's generating
  bool get isActiveChatGenerating =>
      _isGenerating && _currentGeneratingChatId == activeChat?.id;

  /// Check if the active chat has any operation in progress
  bool get isActiveChatBusy =>
      isAnyOperationInProgress && _currentGeneratingChatId == activeChat?.id;

  // Service-delegated getters
  String? get error => _error;
  Map<String, FileProcessingProgress> get fileProcessingProgress =>
      _fileProcessingManager.fileProcessingProgress;
  String get currentStreamingResponse => _messageStreamingService.streamingState.currentResponse;
  String get currentDisplayResponse => _messageStreamingService.streamingState.displayResponse;
  String get currentThinkingContent => _messageStreamingService.thinkingState.currentThinkingContent;
  bool get hasActiveThinkingBubble => _messageStreamingService.thinkingState.hasActiveThinkingBubble;
  bool get isThinkingPhase => _messageStreamingService.thinkingState.isThinkingPhase;
  bool get isInsideThinkingBlock => _messageStreamingService.thinkingState.isInsideThinkingBlock;
  bool get shouldScrollToBottomOnChatSwitch => _chatStateManager.shouldScrollToBottomOnChatSwitch;
  SettingsProvider get settingsProvider => _settingsProvider;

  // Title generation getters
  bool get isGeneratingTitle => _chatTitleGenerator.isGeneratingTitle;
  bool isChatGeneratingTitle(String chatId) => _chatTitleGenerator.isChatGeneratingTitle(chatId);

  /// Check if a thinking bubble is expanded
  bool isThinkingBubbleExpanded(String messageId) {
    return _messageStreamingService.isThinkingBubbleExpanded(messageId);
  }

  /// Toggle thinking bubble expansion
  void toggleThinkingBubble(String messageId) {
    _messageStreamingService.toggleThinkingBubble(messageId);
  }

  @override
  void dispose() {
    _disposed = true;
    _chatStateSubscription?.cancel();
    _messageStreamingService.dispose();
    _chatStateManager.dispose();
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

      // Initialize services
      await _modelManager.initialize();
      
      // Set up service state listeners
      _setupServiceListeners();

      // Load models in parallel (network operation that may fail)
      // Don't wait for this to complete - let it load in background
      _modelManager.loadModels().then((success) {
        if (success) {
          AppLogger.info('Models loaded successfully');
        } else {
          _error = _modelManager.lastError;
          AppLogger.error('Models failed to load: ${_modelManager.lastError}');
        }
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

  /// Set up listeners for service state changes
  void _setupServiceListeners() {
    // Listen to chat state changes
    _chatStateSubscription = _chatStateManager.stateStream.listen(
      (state) {
        _safeNotifyListeners();
      },
      onError: (error) {
        _error = 'Chat state error: $error';
        AppLogger.error('Error in chat state stream', error);
        _safeNotifyListeners();
      },
    );

    // Set up streaming service callbacks
    _messageStreamingService.setStreamingStateCallback((streamingState) {
      _safeNotifyListeners();
    });

    _messageStreamingService.setThinkingStateCallback((thinkingState) {
      _safeNotifyListeners();
    });
  }

  void cancelGeneration() {
    _messageStreamingService.cancelStreaming();
    _cancelOngoingGeneration();
  }

  /// Internal method to cancel ongoing generation and reset streaming state
  void _cancelOngoingGeneration() {
    AppLogger.info('Cancelling all ongoing operations');
    _isGenerating = false;
    _isSendingMessage = false;
    _currentGeneratingChatId = null;

    // Clear file processing state
    _fileProcessingManager.clearProcessingState();

    // Clear title generation state
    _chatTitleGenerator.clearAllTitleGenerationState();

    _safeNotifyListeners();
  }

  List<Message> get displayableMessages {
    return _chatStateManager.displayableMessages;
  }

  Future<void> createNewChat([String? modelName]) async {
    try {
      _cancelOngoingGeneration();
      
      final selectedModel = _modelManager.getModelForNewChat(modelName);
      await _modelManager.setSelectedModel(selectedModel);

      final systemPrompt = _settingsProvider.settings.systemPrompt;
      
      await _chatStateManager.createNewChat(
        modelName: selectedModel,
        systemPrompt: systemPrompt.isNotEmpty ? systemPrompt : null,
      );
      
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
        if (activeChat?.id == chatId) {
          await _chatStateManager.updateChat(updatedChat);
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
        if (activeChat?.id == chat.id) {
          await _chatStateManager.updateChat(updatedChat);
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
      // Don't cancel generation - let it continue in background for original chat
      // Just log that we're switching away from a generating chat
      if (_isGenerating &&
          activeChat?.id != chatId &&
          _currentGeneratingChatId != null) {
        AppLogger.info(
            'Switching away from generating chat $_currentGeneratingChatId to $chatId (generation continues in background)');
      }

      _chatStateManager.setActiveChat(chatId);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to set active chat: ${e.toString()}';
      AppLogger.error('Error setting active chat', e);
      _safeNotifyListeners();
    }
  }

  // Method to reset the scroll flag after scrolling is complete
  void resetScrollToBottomFlag() {
    _chatStateManager.resetScrollToBottomFlag();
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    try {
      await _chatStateManager.updateChatTitle(chatId, newTitle);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to update chat title: ${e.toString()}';
      AppLogger.error('Error updating chat title', e);
      _safeNotifyListeners();
    }
  }

  Future<void> updateChatModel(String chatId, String newModelName) async {
    try {
      await _modelManager.setSelectedModel(newModelName);
      await _chatStateManager.updateChatModel(chatId, newModelName);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to update chat model: ${e.toString()}';
      AppLogger.error('Error updating chat model', e);
      _safeNotifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      // If the deleted chat was active, cancel any ongoing operations
      if (activeChat?.id == chatId) {
        if (_isGenerating || _isSendingMessage) {
          AppLogger.info('Cancelling operations for deleted chat: $chatId');
          _cancelOngoingGeneration();
        }
        
        // Clear title generation state for deleted chat
        _chatTitleGenerator.clearTitleGenerationState(chatId);
      }

      await _chatStateManager.deleteChat(chatId);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'Failed to delete chat: ${e.toString()}';
      AppLogger.error('Error deleting chat', e);
      _safeNotifyListeners();
    }
  }

  Future<void> sendMessage(String content,
      {List<String>? attachedFiles}) async {
    if (activeChat == null) {
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
      
      // Process attached files if any using FileProcessingManager
      List<ProcessedFile> processedFiles = [];
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        AppLogger.info('Processing ${attachedFiles.length} attached files');
        try {
          processedFiles = await _fileProcessingManager.processFiles(attachedFiles);
          AppLogger.info('Successfully processed ${processedFiles.length} files');
        } catch (e) {
          AppLogger.error('Error processing files', e);
          _error = 'Failed to process attached files: $e';
          _safeNotifyListeners();
          return;
        }

        // Check if operation was cancelled during file processing
        if (_messageStreamingService.isCancelled) {
          AppLogger.info('Operation cancelled during file processing');
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

      final updatedMessages = [...activeChat!.messages, userMessage];
      final updatedChat = activeChat!.copyWith(
        messages: updatedMessages,
        lastUpdatedAt: DateTime.now(),
      );

      await _chatStateManager.updateChat(updatedChat);

      _isGenerating = true;
      _currentGeneratingChatId = activeChat!.id; // Track which chat is generating
      _safeNotifyListeners();

      final model = activeChat!.modelName;

      // Check if live response is enabled in settings
      final showLiveResponse = _settingsProvider.settings.showLiveResponse;

      String finalResponse = '';
      List<int>? newContext;

      // Use MessageStreamingService for response generation
      await for (final streamResult in _messageStreamingService.generateStreamingMessage(
        content: content,
        model: model,
        conversationHistory: activeChat!.messages,
        processedFiles: processedFiles.isNotEmpty ? processedFiles : null,
        context: activeChat!.context,
        contextLength: _settingsProvider.settings.contextLength,
        showLiveResponse: showLiveResponse,
      )) {
        // Check if generation was cancelled
        if (_messageStreamingService.isCancelled) {
          AppLogger.warning('Stream cancelled: generation was stopped');
          break;
        }

        // Handle streaming updates
        if (streamResult['type'] == 'chunk') {
          _safeNotifyListeners(); // Update UI with current streaming state
        } else if (streamResult['type'] == 'complete') {
          finalResponse = streamResult['fullResponse'] as String;
          newContext = streamResult['context'] as List<int>?;
          break;
        }
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
      final generatingChat = chats.firstWhere(
        (chat) => chat.id == _currentGeneratingChatId,
        orElse: () => activeChat!,
      );

      final updatedWithAiMessages = [...generatingChat.messages, aiMessage];
      final updatedWithAiChat = generatingChat.copyWith(
        messages: updatedWithAiMessages,
        lastUpdatedAt: DateTime.now(),
        context: newContext, // Store the context for future requests
      );

      // Clear streaming state immediately to prevent duplicate message bubbles
      AppLogger.info('Clearing _isGenerating (success path)');
      _isGenerating = false;
      _currentGeneratingChatId = null; // Clear immediately after response is complete
      _isSendingMessage = false; // Clear sending state
      AppLogger.info(
          'Calling _safeNotifyListeners() after clearing _isGenerating (success path)');
      _safeNotifyListeners();

      // Update the generating chat, not necessarily the active chat
      await _chatStateManager.updateChat(updatedWithAiChat);

      // Notify UI that streaming is complete and message is final
      _safeNotifyListeners();

      // Auto-generate chat title in background without blocking UI
      // This runs independently and won't affect the generating state
      _autoGenerateChatTitleIfNeeded(
          updatedWithAiChat, userMessage.content, finalResponse);
    } on OllamaConnectionException catch (e) {
      _error = 'Cannot connect to Ollama server. Please check your connection.';
      AppLogger.error('Connection error sending message', e);
    } on OllamaApiException catch (e) {
      _error = 'Error from Ollama: ${e.message}';
      AppLogger.error('API error sending message', e);
    } catch (e) {
      _error = 'Failed to generate response:  [31m${e.toString()} [0m';
      AppLogger.error('Error sending message', e);
      AppLogger.info('Clearing _isGenerating (error path)');
      _isGenerating = false;
      _safeNotifyListeners();
    } finally {
      AppLogger.info('Clearing _isGenerating (finally block)');
      _isGenerating = false;
      _currentGeneratingChatId = null;
      _isSendingMessage = false;
      
      // Clear file processing state
      _fileProcessingManager.clearProcessingState();
      
      AppLogger.info(
          'Calling _safeNotifyListeners() after clearing _isGenerating (finally block)');
      _safeNotifyListeners();
    }
  }

  Future<void> sendMessageWithOptionalChatCreation(
    String message, {
    List<String>? attachedFiles,
  }) async {
    if (message.isEmpty) return;

    // Only create new chat if no active chat exists
    if (activeChat == null) {
      if (availableModels.isEmpty) {
        _error = 'No models available. Please check Ollama server connection.';
        _safeNotifyListeners();
        return;
      }

      // Use model manager to get the best available model
      final modelToUse = _modelManager.getBestAvailableModel();

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

      final success = await _modelManager.refreshModels();
      if (success) {
        AppLogger.info(
            'Models refreshed successfully: ${availableModels.length} models available');
      } else {
        _error = _modelManager.lastError;
      }
      _safeNotifyListeners();
    } catch (e) {
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

      final success = await _modelManager.loadModels();
      if (!success) {
        _error = _modelManager.lastError;
      }
      _safeNotifyListeners();

      return success;
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

        final newTitle = await _chatTitleGenerator.generateTitle(
          chatId: chat.id,
          userMessage: userMessageContent,
          aiResponse: aiResponseContent,
          modelName: chat.modelName,
        );

        if (newTitle.isNotEmpty && newTitle != chat.title) {
          await updateChatTitle(chat.id, newTitle);
          AppLogger.info('Auto-generated title: $newTitle');
        } else {
          AppLogger.warning(
              'Generated title was empty or same as current title');
        }
      } else {
        AppLogger.info('Chat already has custom title: ${chat.title}');
      }
    } catch (e) {
      AppLogger.error('Error auto-generating chat title', e);
      // Use fallback title for large document chats
      try {
        if (chat.title == 'New Chat' ||
            chat.title.startsWith('New chat with')) {
          await updateChatTitle(chat.id, 'Document Analysis Chat');
          AppLogger.info('Applied fallback title after error');
        }
      } catch (fallbackError) {
        AppLogger.error('Error applying fallback title', fallbackError);
      }
    }
  }

  /// Validate system prompt support for the current model
  Future<Map<String, dynamic>> validateCurrentModelSystemPromptSupport() async {
    final currentModel = activeChat?.modelName ?? _modelManager.lastSelectedModel;
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
    final currentModel = activeChat?.modelName ?? _modelManager.lastSelectedModel;
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