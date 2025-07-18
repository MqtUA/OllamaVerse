import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/processed_file.dart';
import '../services/chat_history_service.dart';
import '../services/model_manager.dart';
import '../services/chat_state_manager.dart';
import '../services/message_streaming_service.dart';
import '../services/chat_title_generator.dart';
import '../services/file_processing_manager.dart';
import '../services/file_content_processor.dart';
import '../services/thinking_content_processor.dart';
import '../services/error_recovery_service.dart';
import '../services/recovery_strategies.dart';
import '../providers/settings_provider.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Refactored ChatProvider that orchestrates services and maintains UI state
/// Follows clean architecture with complete separation of UI and business logic
class ChatProvider with ChangeNotifier {
  final ChatHistoryService _chatHistoryService;
  final SettingsProvider _settingsProvider;
  final ModelManager _modelManager;
  final ChatStateManager _chatStateManager;
  final MessageStreamingService _messageStreamingService;
  final ChatTitleGenerator _chatTitleGenerator;
  final FileProcessingManager _fileProcessingManager;
  final ErrorRecoveryService _errorRecoveryService;

  // UI state only - business logic delegated to services
  bool _isLoading = true;
  String? _error;
  
  // Stream subscriptions for service coordination
  StreamSubscription? _chatStateSubscription;
  StreamSubscription? _errorStateSubscription;
  bool _disposed = false;

  ChatProvider({
    required ChatHistoryService chatHistoryService,
    required SettingsProvider settingsProvider,
    required ModelManager modelManager,
    required ChatStateManager chatStateManager,
    required MessageStreamingService messageStreamingService,
    required ChatTitleGenerator chatTitleGenerator,
    required FileProcessingManager fileProcessingManager,
    required ThinkingContentProcessor thinkingContentProcessor,
    required ErrorRecoveryService errorRecoveryService,
  })  : _chatHistoryService = chatHistoryService,
        _settingsProvider = settingsProvider,
        _modelManager = modelManager,
        _chatStateManager = chatStateManager,
        _messageStreamingService = messageStreamingService,
        _chatTitleGenerator = chatTitleGenerator,
        _fileProcessingManager = fileProcessingManager,
        _errorRecoveryService = errorRecoveryService {
    _setupErrorRecoveryStrategies();
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
  bool get isAnyOperationInProgress =>
      isGenerating || isProcessingFiles;

  bool get isActiveChatGenerating => isGenerating;
  bool get isActiveChatBusy => isAnyOperationInProgress;

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
  bool get isGeneratingTitle => _chatTitleGenerator.isGeneratingTitle;
  bool isChatGeneratingTitle(String chatId) => _chatTitleGenerator.isChatGeneratingTitle(chatId);
  bool isThinkingBubbleExpanded(String messageId) => _messageStreamingService.isThinkingBubbleExpanded(messageId);
  void toggleThinkingBubble(String messageId) => _messageStreamingService.toggleThinkingBubble(messageId);

  @override
  void dispose() {
    _disposed = true;
    _chatStateSubscription?.cancel();
    _errorStateSubscription?.cancel();
    _messageStreamingService.dispose();
    _chatStateManager.dispose();
    _errorRecoveryService.dispose();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  /// Setup error recovery strategies for all services
  void _setupErrorRecoveryStrategies() {
    try {
      // Register recovery strategies for each service
      _errorRecoveryService.registerRecoveryStrategy(
        'ModelManager',
        RecoveryStrategyFactory.createForService(
          'model',
          ollamaService: _settingsProvider.getOllamaService(),
          modelManager: _modelManager,
        ),
      );

      _errorRecoveryService.registerRecoveryStrategy(
        'MessageStreamingService',
        RecoveryStrategyFactory.createForService(
          'streaming',
          ollamaService: _settingsProvider.getOllamaService(),
        ),
      );

      _errorRecoveryService.registerRecoveryStrategy(
        'ChatStateManager',
        RecoveryStrategyFactory.createForService(
          'state',
          resetStateCallback: () => _chatStateManager.resetState(),
        ),
      );

      _errorRecoveryService.registerRecoveryStrategy(
        'FileProcessingManager',
        RecoveryStrategyFactory.createForService('fileprocessing'),
      );

      _errorRecoveryService.registerRecoveryStrategy(
        'ChatTitleGenerator',
        RecoveryStrategyFactory.createForService('titlegeneration'),
      );

      AppLogger.info('Error recovery strategies registered successfully');
    } catch (e) {
      AppLogger.error('Error setting up recovery strategies', e);
    }
  }

  /// Helper method to handle errors consistently
  void _handleError(String message, dynamic error, [String? logContext]) {
    final errorState = ErrorHandler.createErrorState(
      error,
      operation: logContext ?? message,
      context: {
        'isLoading': _isLoading,
        'hasActiveChat': activeChat != null,
        'isGenerating': isGenerating,
      },
    );
    
    _error = errorState.message;
    ErrorHandler.logError(logContext ?? message, error);
    _safeNotifyListeners();
  }

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
        _handleError('Chat state error', error, 'ChatStateManager.stateStream');
      },
    );

    _errorStateSubscription = _errorRecoveryService.errorStateStream.listen(
      (errorStates) {
        // Update UI error state based on service errors
        _updateErrorFromServiceStates(errorStates);
        _safeNotifyListeners();
      },
      onError: (error) {
        AppLogger.error('Error in error state stream', error);
      },
    );

    _messageStreamingService.setStreamingStateCallback((_) => _safeNotifyListeners());
    _messageStreamingService.setThinkingStateCallback((_) => _safeNotifyListeners());
  }

  /// Update error state based on service error states
  void _updateErrorFromServiceStates(Map<String, ErrorState> errorStates) {
    if (errorStates.isEmpty) {
      // Clear error if no service errors
      if (_error != null) {
        _error = null;
      }
      return;
    }

    // Find the most critical error to display
    ErrorState? mostCriticalError;
    ErrorSeverity highestSeverity = ErrorSeverity.info;

    for (final errorState in errorStates.values) {
      if (errorState.severity.index > highestSeverity.index) {
        highestSeverity = errorState.severity;
        mostCriticalError = errorState;
      }
    }

    if (mostCriticalError != null) {
      _error = mostCriticalError.message;
    }
  }

  void cancelGeneration() {
    _messageStreamingService.cancelStreaming();
    _fileProcessingManager.clearProcessingState();
    _chatTitleGenerator.clearAllTitleGenerationState();
    _safeNotifyListeners();
  }

  List<Message> get displayableMessages => _chatStateManager.displayableMessages;

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
        if (activeChat?.id == chatId) {
          await _chatStateManager.updateChat(updatedChat);
        }

        await _chatHistoryService.saveChat(updatedChat);
      }
      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to update chat system prompt', e, 'Error updating chat system prompt');
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
        if (activeChat?.id == chat.id) {
          await _chatStateManager.updateChat(updatedChat);
        }

        await _chatHistoryService.saveChat(updatedChat);
      }
      _safeNotifyListeners();
    } catch (e) {
      _handleError('Failed to update system prompt for all chats', e, 'Error updating system prompt for all chats');
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
      _handleError('Failed to update chat title', e, 'Error updating chat title');
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
      _handleError('Failed to update chat model', e, 'Error updating chat model');
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

  Future<void> sendMessage(String content, {List<String>? attachedFiles}) async {
    if (activeChat == null) {
      _error = 'No active chat';
      _safeNotifyListeners();
      return;
    }

    try {
      // Process attached files if any
      List<ProcessedFile> processedFiles = [];
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        processedFiles = await _fileProcessingManager.processFiles(attachedFiles);
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
      await for (final streamResult in _messageStreamingService.generateStreamingMessage(
        content: content,
        model: activeChat!.modelName,
        conversationHistory: activeChat!.messages,
        processedFiles: processedFiles.isNotEmpty ? processedFiles : null,
        context: activeChat!.context,
        contextLength: _settingsProvider.settings.contextLength,
        showLiveResponse: _settingsProvider.settings.showLiveResponse,
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

      final success = await _modelManager.loadModels();
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
    final currentModel = activeChat?.modelName ?? _modelManager.lastSelectedModel;
    if (currentModel.isEmpty) {
      return {
        'supported': true,
        'modelName': 'unknown',
        'fallbackMethod': 'native',
        'recommendation': 'No model selected. System prompt support cannot be determined.',
      };
    }

    try {
      // Wait for settings to be ready before validation
      while (_settingsProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ollamaService = _settingsProvider.getOllamaService();
      final validation = await ollamaService.validateSystemPromptSupport(currentModel);
      return validation;
    } catch (e) {
      AppLogger.error('Error validating system prompt support', e);
      return {
        'supported': true, // Default to supported
        'modelName': currentModel,
        'fallbackMethod': 'native',
        'recommendation': 'Unable to validate system prompt support. Assuming native support.',
        'error': e.toString(),
      };
    }
  }

  /// Get system prompt handling strategy for current model
  String getCurrentModelSystemPromptStrategy() {
    final currentModel = activeChat?.modelName ?? _modelManager.lastSelectedModel;
    if (currentModel.isEmpty) return 'native';

    try {
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

  /// Get current error recovery status
  Map<String, dynamic> getErrorRecoveryStatus() {
    final serviceErrors = _errorRecoveryService.currentErrorStates;
    final systemHealth = _errorRecoveryService.getSystemHealth();
    
    return {
      'systemHealth': systemHealth.name,
      'serviceErrors': serviceErrors.map((key, value) => MapEntry(key, {
        'errorType': value.errorType.name,
        'message': value.message,
        'canRetry': value.canRetry,
        'severity': value.severity.name,
        'isRecent': value.isRecent,
        'operation': value.operation,
      })),
      'hasActiveErrors': serviceErrors.isNotEmpty,
      'errorCount': serviceErrors.length,
    };
  }

  /// Manually trigger error recovery for a specific service
  Future<bool> recoverService(String serviceName) async {
    try {
      final errorState = _errorRecoveryService.getServiceError(serviceName);
      if (errorState == null) {
        AppLogger.info('No error state found for service: $serviceName');
        return true;
      }

      final result = await _errorRecoveryService.handleServiceError(
        serviceName,
        errorState.error,
        operation: 'manualRecovery',
      );

      _safeNotifyListeners();
      return result != null;
    } catch (e) {
      AppLogger.error('Error during manual service recovery', e);
      return false;
    }
  }

  /// Clear all service errors
  void clearAllServiceErrors() {
    _errorRecoveryService.clearAllErrors();
    _error = null;
    _safeNotifyListeners();
  }

  /// Get service health status
  Map<String, String> getServiceHealthStatus() {
    final services = [
      'ModelManager',
      'MessageStreamingService', 
      'ChatStateManager',
      'FileProcessingManager',
      'ChatTitleGenerator',
    ];

    return Map.fromEntries(
      services.map((service) => MapEntry(
        service,
        _errorRecoveryService.getServiceHealth(service).name,
      )),
    );
  }

  /// Validate all service states
  bool validateAllServiceStates() {
    try {
      final modelManagerValid = _modelManager.validateState();
      final chatStateValid = _chatStateManager.validateState();
      final streamingValid = _messageStreamingService.validateStreamingState();
      
      final allValid = modelManagerValid && chatStateValid && streamingValid;
      
      if (!allValid) {
        AppLogger.warning('Service state validation failed: '
          'ModelManager=$modelManagerValid, '
          'ChatState=$chatStateValid, '
          'Streaming=$streamingValid');
      }
      
      return allValid;
    } catch (e) {
      AppLogger.error('Error validating service states', e);
      return false;
    }
  }

  /// Reset all service states to consistent state
  Future<void> resetAllServiceStates() async {
    try {
      AppLogger.info('Resetting all service states');
      
      // Cancel any ongoing operations
      cancelGeneration();
      
      // Reset individual service states
      _modelManager.resetState();
      _chatStateManager.resetState();
      _messageStreamingService.resetStreamingState();
      
      // Clear error recovery state
      _errorRecoveryService.clearAllErrors();
      
      // Reset provider state
      _error = null;
      
      _safeNotifyListeners();
      
      AppLogger.info('All service states reset completed');
    } catch (e) {
      AppLogger.error('Error resetting service states', e);
      _handleError('Failed to reset service states', e);
    }
  }
}