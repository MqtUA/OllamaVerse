import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/processed_file.dart';
import '../models/generation_settings.dart';
import '../services/file_content_processor.dart';

import '../services/model_manager.dart';
import '../services/chat_state_manager.dart';
import '../services/message_streaming_service.dart';
import '../services/chat_title_generator.dart';
import '../services/file_processing_manager.dart';
import '../services/cancellation_manager.dart';
import '../services/system_prompt_service.dart';
import '../services/model_compatibility_service.dart';
import '../services/service_health_coordinator.dart';
import '../services/chat_settings_manager.dart';
import '../providers/settings_provider.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';

/// Refactored ChatProvider that orchestrates services and maintains UI state
///
/// This provider focuses solely on UI coordination, delegating all business logic
/// to specialized services while providing a unified interface for the UI layer.
class ChatProvider with ChangeNotifier {
  // Service dependencies - all business logic is handled by these services
  final SettingsProvider _settingsProvider;
  final ModelManager _modelManager;
  final ChatStateManager _chatStateManager;
  final MessageStreamingService _messageStreamingService;
  final ChatTitleGenerator _chatTitleGenerator;
  final FileProcessingManager _fileProcessingManager;
  final CancellationManager _cancellationManager;
  final SystemPromptService _systemPromptService;
  final ModelCompatibilityService _modelCompatibilityService;
  final ServiceHealthCoordinator _serviceHealthCoordinator;
  final ChatSettingsManager _chatSettingsManager;

  // Minimal UI state - only what's needed for UI coordination
  bool _isLoading = true;
  String? _error;

  // Service subscriptions for reactive UI updates
  StreamSubscription? _chatStateSubscription;
  StreamSubscription? _fileProgressSubscription;
  bool _disposed = false;

  ChatProvider({
    required SettingsProvider settingsProvider,
    required ModelManager modelManager,
    required ChatStateManager chatStateManager,
    required MessageStreamingService messageStreamingService,
    required ChatTitleGenerator chatTitleGenerator,
    required FileProcessingManager fileProcessingManager,
    required CancellationManager cancellationManager,
    required SystemPromptService systemPromptService,
    required ModelCompatibilityService modelCompatibilityService,
    required ServiceHealthCoordinator serviceHealthCoordinator,
    required ChatSettingsManager chatSettingsManager,
  })  : _settingsProvider = settingsProvider,
        _modelManager = modelManager,
        _chatStateManager = chatStateManager,
        _messageStreamingService = messageStreamingService,
        _chatTitleGenerator = chatTitleGenerator,
        _fileProcessingManager = fileProcessingManager,
        _cancellationManager = cancellationManager,
        _systemPromptService = systemPromptService,
        _modelCompatibilityService = modelCompatibilityService,
        _serviceHealthCoordinator = serviceHealthCoordinator,
        _chatSettingsManager = chatSettingsManager {
    _initialize();
  }

  // Getters - delegate to services for clean architecture
  List<Chat> get chats => _chatStateManager.chats;
  Chat? get activeChat => _chatStateManager.activeChat;
  List<String> get availableModels => _modelManager.availableModels;
  bool get isLoading => _isLoading;
  bool get isGenerating => _messageStreamingService.isStreaming;
  bool get isSendingMessage => _messageStreamingService.isStreaming;
  bool get isProcessingFiles => _fileProcessingManager.isProcessingFiles;

  // Unified operation status getters
  bool get isAnyOperationInProgress => isGenerating || isProcessingFiles;
  bool get isActiveChatGenerating => isGenerating;
  bool get isActiveChatBusy => isAnyOperationInProgress;

  // Service-delegated getters
  String? get error => _error;
  Map<String, FileProcessingProgress> get fileProcessingProgress =>
      _fileProcessingManager.fileProcessingProgress;
  String get currentStreamingResponse =>
      _messageStreamingService.streamingState.currentResponse;
  String get currentDisplayResponse =>
      _messageStreamingService.streamingState.displayResponse;
  String get currentThinkingContent =>
      _messageStreamingService.thinkingState.currentThinkingContent;
  bool get hasActiveThinkingBubble =>
      _messageStreamingService.thinkingState.hasActiveThinkingBubble;
  bool get isThinkingPhase =>
      _messageStreamingService.thinkingState.isThinkingPhase;
  bool get isInsideThinkingBlock =>
      _messageStreamingService.thinkingState.isInsideThinkingBlock;
  bool get shouldScrollToBottomOnChatSwitch =>
      _chatStateManager.shouldScrollToBottomOnChatSwitch;
  SettingsProvider get settingsProvider => _settingsProvider;
  bool get isGeneratingTitle => _chatTitleGenerator.isGeneratingTitle;
  bool isChatGeneratingTitle(String chatId) =>
      _chatTitleGenerator.isChatGeneratingTitle(chatId);
  bool isThinkingBubbleExpanded(String messageId) =>
      _messageStreamingService.isThinkingBubbleExpanded(messageId);
  void toggleThinkingBubble(String messageId) =>
      _messageStreamingService.toggleThinkingBubble(messageId);
      
  /// Check if a chat has custom generation settings
  bool chatHasCustomSettings(String chatId) => 
      _chatSettingsManager.chatHasCustomSettings(chatId);
  
  /// Get generation settings for a chat (either custom or global)
  GenerationSettings getEffectiveSettingsForChat(String chatId) => 
      _chatSettingsManager.getEffectiveSettingsForChat(chatId);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Cancel all subscriptions first to prevent further state updates
    _chatStateSubscription?.cancel();
    _chatStateSubscription = null;
    _fileProgressSubscription?.cancel();
    _fileProgressSubscription = null;

    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void cancelGeneration() {
    _messageStreamingService.cancelStreaming();
    _fileProcessingManager.clearProcessingState();
    _chatTitleGenerator.clearAllTitleGenerationState();
    _cancellationManager.cancelAll();
    _safeNotifyListeners();
  }

  List<Message> get displayableMessages =>
      _chatStateManager.displayableMessages;

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      _safeNotifyListeners();

      // Wait for settings to load
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Initialize services
      await _modelManager.initialize();
      _setupServiceListeners();

      // Load models in background
      _modelManager.loadModels().then((success) {
        if (!success) _error = _modelManager.lastError;
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
    _chatStateSubscription = _chatStateManager.stateStream.listen(
      (state) => _safeNotifyListeners(),
      onError: (error) {
        _error = 'Chat state error: ${error.toString()}';
        AppLogger.error('Error in chat state stream', error);
        _safeNotifyListeners();
      },
    );

    _fileProgressSubscription = _fileProcessingManager.progressStream.listen(
      (progress) => _safeNotifyListeners(),
      onError: (error) {
        AppLogger.error('Error in file progress stream', error);
      },
    );

    _messageStreamingService
        .setStreamingStateCallback((_) => _safeNotifyListeners());
    _messageStreamingService
        .setThinkingStateCallback((_) => _safeNotifyListeners());
  }

  Future<void> createNewChat([String? modelName]) async {
    try {
      cancelGeneration();

      final selectedModel = _modelManager.getModelForNewChat(modelName);
      await _modelManager.setSelectedModel(selectedModel);

      final systemPrompt = _settingsProvider.settings.systemPrompt;

      await _chatStateManager.createNewChat(
        modelName: selectedModel,
        systemPrompt: systemPrompt.isNotEmpty ? systemPrompt : null,
      );

      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to create new chat', e, 'Error creating new chat');
    }
  }

  /// Update system prompt for existing chat
  Future<void> updateChatSystemPrompt(String chatId) async {
    try {
      await _systemPromptService.updateChatSystemPrompt(chatId);
      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to update chat system prompt', e,
          'Error updating chat system prompt');
    }
  }

  /// Update system prompt for all existing chats
  Future<void> updateAllChatsSystemPrompt() async {
    try {
      await _systemPromptService.updateAllChatsSystemPrompt();
      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to update system prompt for all chats', e,
          'Error updating system prompt for all chats');
    }
  }

  void setActiveChat(String chatId) {
    try {
      _chatStateManager.setActiveChat(chatId);
    } catch (e) {
      _handleError('Failed to set active chat', e, 'Error setting active chat');
      return;
    }
    _safeNotifyListeners();
  }

  void resetScrollToBottomFlag() => _chatStateManager.resetScrollToBottomFlag();

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    try {
      await _chatStateManager.updateChatTitle(chatId, newTitle);
    } catch (e) {
      _handleError(
          'Failed to update chat title', e, 'Error updating chat title');
      return;
    }
    _safeNotifyListeners();
  }

  Future<void> updateChatModel(String chatId, String newModelName) async {
    try {
      await _modelManager.setSelectedModel(newModelName);
      await _chatStateManager.updateChatModel(chatId, newModelName);
      _safeNotifyListeners();
    } catch (e) {
      _handleError(
          'Failed to update chat model', e, 'Error updating chat model');
    }
  }

  Future<void> updateChatGenerationSettings(String chatId, GenerationSettings? customSettings) async {
    try {
      await _chatSettingsManager.updateChatGenerationSettings(chatId, customSettings);
      _safeNotifyListeners();
    } catch (e) {
      _handleError(
          'Failed to update chat generation settings', e, 'Error updating chat settings');
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      // Cancel operations if deleting active chat
      if (activeChat?.id == chatId) {
        cancelGeneration();
        _chatTitleGenerator.clearTitleGenerationState(chatId);
      }

      await _chatStateManager.deleteChat(chatId);
      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to delete chat', e, 'Error deleting chat');
    }
  }

  Future<void> sendMessage(String content,
      {List<String>? attachedFiles}) async {
    if (activeChat == null) {
      _error = 'No active chat';
      _safeNotifyListeners();
      return;
    }

    try {
      // Process attached files if any
      List<ProcessedFile> processedFiles = [];
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        processedFiles =
            await _fileProcessingManager.processFiles(attachedFiles);
      }

      // Create user message
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        processedFiles: processedFiles,
      );

      // Update chat with user message
      final updatedMessages = [...activeChat!.messages, userMessage];
      final updatedChat = activeChat!.copyWith(
        messages: updatedMessages,
        lastUpdatedAt: DateTime.now(),
      );

      await _chatStateManager.updateChat(updatedChat);

      // Generate AI response using streaming service
      await for (final streamResult
          in _messageStreamingService.generateStreamingMessage(
        content: content,
        model: activeChat!.modelName,
        conversationHistory: activeChat!.messages,
        processedFiles: processedFiles.isNotEmpty ? processedFiles : null,
        context: activeChat!.context,
        contextLength: _settingsProvider.settings.contextLength,
        showLiveResponse: _settingsProvider.settings.showLiveResponse,
        chat: activeChat, // Pass the chat for per-chat settings resolution
        appSettings: _settingsProvider.settings, // Pass global settings
      )) {
        if (_messageStreamingService.isCancelled) break;

        if (streamResult['type'] == 'chunk') {
          _safeNotifyListeners();
        } else if (streamResult['type'] == 'complete') {
          final finalResponse = streamResult['fullResponse'] as String;
          final newContext = streamResult['context'] as List<int>?;

          // Create AI message
          final aiMessage = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: finalResponse,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          );

          // Update chat with AI response
          final finalMessages = [...updatedChat.messages, aiMessage];
          final finalChat = updatedChat.copyWith(
            messages: finalMessages,
            lastUpdatedAt: DateTime.now(),
            context: newContext,
          );

          await _chatStateManager.updateChat(finalChat);

          // Auto-generate title if needed
          _autoGenerateChatTitleIfNeeded(finalChat, content, finalResponse);
          break;
        }
      }

      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to send message', e, 'Error sending message');
    }
  }

  Future<void> sendMessageWithOptionalChatCreation(
    String message, {
    List<String>? attachedFiles,
  }) async {
    if (message.isEmpty) return;

    // Create new chat if needed
    if (activeChat == null) {
      if (availableModels.isEmpty) {
        _error = 'No models available. Please check Ollama server connection.';
        _safeNotifyListeners();
        return;
      }
      await createNewChat(_modelManager.getBestAvailableModel());
    }

    await sendMessage(message, attachedFiles: attachedFiles);
  }

  Future<void> refreshModels() async {
    try {
      _error = null;
      _safeNotifyListeners();

      final success = await _modelManager.refreshModels();
      if (!success) _error = _modelManager.lastError;
      _safeNotifyListeners();
    } catch (e) {
      AppLogger.error('Error refreshing models', e);
      _error = e.toString();
      _safeNotifyListeners();
    }
  }

  /// Retry connection and model loading
  Future<bool> retryConnection() async {
    try {
      _error = null;
      _safeNotifyListeners();

      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final success = await _modelManager.retryConnection();
      if (!success) _error = _modelManager.lastError;
      _safeNotifyListeners();

      return success;
    } catch (e) {
      AppLogger.error('Error retrying connection', e);
      _safeNotifyListeners();
      return false;
    }
  }

  /// Auto-generate chat title if needed
  Future<void> _autoGenerateChatTitleIfNeeded(
      Chat chat, String userMessageContent, String aiResponseContent) async {
    try {
      // Only auto-name if the chat has a default title
      if (chat.title == 'New Chat' || chat.title.startsWith('New chat with')) {
        final newTitle = await _chatTitleGenerator.generateTitle(
          chatId: chat.id,
          userMessage: userMessageContent,
          aiResponse: aiResponseContent,
          modelName: chat.modelName,
        );

        if (newTitle.isNotEmpty && newTitle != chat.title) {
          await updateChatTitle(chat.id, newTitle);
        }
      }
    } catch (e) {
      AppLogger.error('Error auto-generating chat title', e);
    }
  }

  /// Validate system prompt support for the current model
  Future<Map<String, dynamic>> validateCurrentModelSystemPromptSupport() async {
    final currentModel =
        activeChat?.modelName ?? _modelManager.lastSelectedModel;
    return await _systemPromptService.validateSystemPromptSupport(currentModel);
  }

  /// Get system prompt handling strategy for current model
  String getCurrentModelSystemPromptStrategy() {
    final currentModel =
        activeChat?.modelName ?? _modelManager.lastSelectedModel;
    return _systemPromptService.getSystemPromptStrategy(currentModel);
  }

  /// Get current error recovery status
  Map<String, dynamic> getErrorRecoveryStatus() => 
      _serviceHealthCoordinator.getErrorRecoveryStatus();

  /// Validate settings for current model and provide recommendations
  Future<Map<String, dynamic>> validateSettingsForCurrentModel() async {
    final currentModel = activeChat?.modelName ?? _modelManager.lastSelectedModel;
    return await _modelCompatibilityService.validateSettingsForModel(currentModel);
  }

  /// Manually trigger error recovery for a specific service
  Future<bool> recoverService(String serviceName) async {
    try {
      final result = await _serviceHealthCoordinator.recoverService(serviceName);
      _safeNotifyListeners();
      return result;
    } catch (e) {
      AppLogger.error('Error during manual service recovery', e);
      return false;
    }
  }

  /// Clear all service errors
  void clearAllServiceErrors() {
    _serviceHealthCoordinator.clearAllServiceErrors();
    _error = null;
    _safeNotifyListeners();
  }
  
  /// Handle global generation settings changes
  /// 
  /// This method is called when the global generation settings are updated
  /// to ensure that any active chat using global settings is properly updated.
  void handleGlobalSettingsChange() {
    try {
      _chatSettingsManager.handleGlobalSettingsChange();
      
      // No need to update anything if there's no active chat
      if (activeChat == null) return;
      
      // Only refresh if the active chat is using global settings
      if (!activeChat!.hasCustomGenerationSettings) {
        _safeNotifyListeners();
      }
    } catch (e) {
      _handleError(
          'Failed to handle settings change', e, 'Error handling settings change');
    }
  }

  /// Get service health status
  Map<String, String> getServiceHealthStatus() => 
      _serviceHealthCoordinator.getServiceHealthStatus();

  /// Validate all service states
  bool validateAllServiceStates() => 
      _serviceHealthCoordinator.validateAllServiceStates();

  /// Reset all service states to consistent state
  Future<void> resetAllServiceStates() async {
    try {
      // Cancel any ongoing operations
      cancelGeneration();

      await _serviceHealthCoordinator.resetAllServiceStates();

      // Reset provider state
      _error = null;
      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to reset service states', e);
    }
  }

  /// Handle errors with enhanced logging and user feedback
  void _handleError(String operation, dynamic error, [String? userMessage]) {
    // Generate correlation ID for tracking
    final correlationId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Use ErrorHandler for consistent error processing
    final userFriendlyMessage = userMessage ?? ErrorHandler.getUserFriendlyMessage(error);
    _error = userFriendlyMessage;
    
    // Enhanced error logging with context
    ErrorHandler.logError(
      operation,
      error,
      correlationId: correlationId,
      context: {
        'activeChat': activeChat?.id,
        'availableModels': availableModels.length,
        'isGenerating': isGenerating,
        'isProcessingFiles': isProcessingFiles,
      },
    );
    
    // Log recovery suggestions for debugging
    final suggestions = ErrorHandler.getRecoverySuggestions(error);
    AppLogger.info('[$correlationId] Recovery suggestions: ${suggestions.join(', ')}');
    
    _safeNotifyListeners();
  }
}