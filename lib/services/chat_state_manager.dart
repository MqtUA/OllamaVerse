import 'dart:async';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_history_service.dart';
import '../services/error_recovery_service.dart';

import '../utils/logger.dart';

/// Manages chat list and active chat state
/// Handles chat CRUD operations and state synchronization
class ChatStateManager {
  final ChatHistoryService _chatHistoryService;
  final ErrorRecoveryService? _errorRecoveryService;
  
  List<Chat> _chats = [];
  Chat? _activeChat;
  bool _shouldScrollToBottomOnChatSwitch = false;
  
  StreamSubscription? _chatStreamSubscription;
  bool _disposed = false;
  
  // Synchronization for state updates
  bool _isUpdatingState = false;
  
  // Stream controller for state changes
  final _stateController = StreamController<ChatStateManagerState>.broadcast();
  
  // Error handling
  static const String _serviceName = 'ChatStateManager';
  
  /// Stream of state changes
  Stream<ChatStateManagerState> get stateStream => _stateController.stream;
  
  /// Current list of chats (immutable)
  List<Chat> get chats => List.unmodifiable(_chats);
  
  /// Currently active chat
  Chat? get activeChat => _activeChat;
  
  /// Whether to scroll to bottom on chat switch
  bool get shouldScrollToBottomOnChatSwitch => _shouldScrollToBottomOnChatSwitch;
  
  /// Current state snapshot
  ChatStateManagerState get currentState => ChatStateManagerState(
    chats: chats,
    activeChat: activeChat,
    shouldScrollToBottomOnChatSwitch: shouldScrollToBottomOnChatSwitch,
  );

  ChatStateManager({
    required ChatHistoryService chatHistoryService,
    ErrorRecoveryService? errorRecoveryService,
  }) : _chatHistoryService = chatHistoryService,
       _errorRecoveryService = errorRecoveryService {
    _initialize();
  }

  /// Initialize the chat state manager
  Future<void> _initialize() async {
    if (_errorRecoveryService != null) {
      await _errorRecoveryService!.executeServiceOperation(
        _serviceName,
        () => _performInitialization(),
        operationName: 'initialize',
      );
    } else {
      await _performInitialization();
    }
  }

  /// Perform the actual initialization
  Future<void> _performInitialization() async {
    try {
      AppLogger.info('Initializing ChatStateManager');
      
      // Listen to chat updates from the history service
      _chatStreamSubscription = _chatHistoryService.chatStream.listen(
        (chats) {
          _chats = chats.toList();
          _setActiveToMostRecentIfNeeded();
          _notifyStateChange();
        },
        onError: (error) {
          _handleStreamError(error);
        },
      );

      // Load existing chats immediately
      await _loadExistingChats();
      
      AppLogger.info('ChatStateManager initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing ChatStateManager', e);
      rethrow;
    }
  }

  /// Load existing chats on startup
  Future<void> _loadExistingChats() async {
    if (_errorRecoveryService != null) {
      await _errorRecoveryService!.executeServiceOperation(
        _serviceName,
        () => _performLoadExistingChats(),
        operationName: 'loadExistingChats',
        timeout: const Duration(seconds: 10),
      );
    } else {
      await _performLoadExistingChats();
    }
  }

  /// Perform the actual loading of existing chats
  Future<void> _performLoadExistingChats() async {
    try {
      AppLogger.info('Loading existing chats in ChatStateManager');

      // Wait for chat history service to finish initializing
      int attempts = 0;
      const maxAttempts = 50; // 5 seconds max wait

      while (attempts < maxAttempts && !_chatHistoryService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!_chatHistoryService.isInitialized) {
        throw TimeoutException(
          'ChatHistoryService initialization timed out after 5 seconds',
          const Duration(seconds: 5),
        );
      }

      // Force an initial update with current chats
      _chats = _chatHistoryService.chats.toList();
      _setActiveToMostRecentIfNeeded();
      _notifyStateChange();

      AppLogger.info('Successfully loaded ${_chats.length} existing chats');
    } catch (e) {
      AppLogger.error('Error loading existing chats in ChatStateManager', e);
      rethrow;
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

  /// Create a new chat
  Future<Chat> createNewChat({
    required String modelName,
    String? title,
    String? systemPrompt,
  }) async {
    return await _executeWithErrorHandling(
      () => _performCreateNewChat(
        modelName: modelName,
        title: title,
        systemPrompt: systemPrompt,
      ),
      'createNewChat',
    );
  }

  /// Perform the actual chat creation
  Future<Chat> _performCreateNewChat({
    required String modelName,
    String? title,
    String? systemPrompt,
  }) async {
    try {
      _validateNotDisposed();
      
      final chatId = DateTime.now().millisecondsSinceEpoch.toString();
      final chatTitle = title ?? 'New chat with $modelName';
      
      final newChat = Chat(
        id: chatId,
        title: chatTitle,
        modelName: modelName,
        messages: [],
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      );

      // Add system prompt if provided
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
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
      _notifyStateChange();
      
      AppLogger.info('Created new chat: $chatTitle');
      return newChat;
    } catch (e) {
      AppLogger.error('Error creating new chat', e);
      rethrow;
    }
  }

  /// Set the active chat by ID
  void setActiveChat(String chatId) {
    _validateNotDisposed();
    
    final chat = _chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => throw ArgumentError('Chat with ID $chatId not found'),
    );
    
    final previousActiveChat = _activeChat;
    _activeChat = chat;

    // Check if we're switching to a different chat with existing messages
    // and should trigger auto-scroll to bottom
    if ((previousActiveChat?.id != chatId || previousActiveChat == null) &&
        chat.messages.isNotEmpty) {
      _shouldScrollToBottomOnChatSwitch = true;
      AppLogger.info('Triggering auto-scroll for chat switch to: ${chat.title}');
    } else {
      _shouldScrollToBottomOnChatSwitch = false;
    }

    _notifyStateChange();
    AppLogger.info('Set active chat to: ${chat.title}');
  }

  /// Reset the scroll to bottom flag after scrolling is complete
  void resetScrollToBottomFlag() {
    _shouldScrollToBottomOnChatSwitch = false;
    _notifyStateChange();
  }

  /// Update chat title
  Future<void> updateChatTitle(String chatId, String newTitle) async {
    try {
      _validateNotDisposed();
      
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex == -1) {
        throw ArgumentError('Chat with ID $chatId not found');
      }

      final updatedChat = _chats[chatIndex].copyWith(
        title: newTitle,
        lastUpdatedAt: DateTime.now(),
      );

      // Update active chat if this is the active one
      if (_activeChat?.id == chatId) {
        _activeChat = updatedChat;
      }

      // Save to service - this will trigger the stream update
      await _chatHistoryService.saveChat(updatedChat);
      _notifyStateChange();
      
      AppLogger.info('Updated chat title: $newTitle');
    } catch (e) {
      AppLogger.error('Error updating chat title', e);
      rethrow;
    }
  }

  /// Update chat model
  Future<void> updateChatModel(String chatId, String newModelName) async {
    try {
      _validateNotDisposed();
      
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex == -1) {
        throw ArgumentError('Chat with ID $chatId not found');
      }

      final currentChat = _chats[chatIndex];
      
      // Check if this is a new chat (only has system messages, no user/assistant messages)
      final hasUserMessages = currentChat.messages
          .where((msg) => msg.role != MessageRole.system)
          .isNotEmpty;
      
      bool isDefaultTitle = !hasUserMessages &&
          (currentChat.title == 'New Chat' ||
              currentChat.title.startsWith('New chat with'));

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
      _notifyStateChange();
      
      AppLogger.info('Updated chat model to: $newModelName');
    } catch (e) {
      AppLogger.error('Error updating chat model', e);
      rethrow;
    }
  }

  /// Update chat with new messages or other changes
  Future<void> updateChat(Chat updatedChat) async {
    try {
      _validateNotDisposed();
      
      // Validate that the chat exists
      final chatIndex = _chats.indexWhere((c) => c.id == updatedChat.id);
      if (chatIndex == -1) {
        throw ArgumentError('Chat with ID ${updatedChat.id} not found');
      }

      // Update active chat if this is the active one
      if (_activeChat?.id == updatedChat.id) {
        _activeChat = updatedChat;
      }

      // Save to service - this will trigger the stream update
      await _chatHistoryService.saveChat(updatedChat);
      _notifyStateChange();
      
      AppLogger.info('Updated chat: ${updatedChat.title}');
    } catch (e) {
      AppLogger.error('Error updating chat', e);
      rethrow;
    }
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    try {
      _validateNotDisposed();
      
      // Find the index of the chat to be deleted
      final int index = _chats.indexWhere((c) => c.id == chatId);
      if (index == -1) {
        throw ArgumentError('Chat with ID $chatId not found');
      }

      // Optimistically remove the chat from the local list
      _chats.removeAt(index);

      // If the deleted chat was active, set active chat to most recent or null
      if (_activeChat?.id == chatId) {
        _activeChat = _chats.isNotEmpty ? _chats.first : null;
      }

      _notifyStateChange(); // Notify listeners immediately to update UI

      // Now, perform the asynchronous deletion from the history service
      await _chatHistoryService.deleteChat(chatId);
      
      AppLogger.info('Deleted chat: $chatId');
    } catch (e) {
      AppLogger.error('Error deleting chat', e);
      // If deletion fails, the _chatHistoryService.chatStream should ideally
      // re-emit the original list, which will then cause the UI to revert.
      rethrow;
    }
  }

  /// Get a specific chat by ID
  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((c) => c.id == chatId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a chat exists
  bool chatExists(String chatId) {
    return _chats.any((c) => c.id == chatId);
  }

  /// Get displayable messages for the active chat
  List<Message> get displayableMessages {
    if (_activeChat == null) return [];
    return _activeChat!.messages.where((msg) => !msg.isSystem).toList();
  }

  /// Validate that the manager is not disposed
  void _validateNotDisposed() {
    if (_disposed) {
      throw StateError('ChatStateManager has been disposed');
    }
  }

  /// Notify listeners of state changes
  void _notifyStateChange() {
    if (_disposed || _isUpdatingState) return;
    
    _isUpdatingState = true;
    try {
      if (!_stateController.isClosed) {
        _stateController.add(currentState);
      }
    } finally {
      _isUpdatingState = false;
    }
  }

  /// Handle stream errors with recovery
  void _handleStreamError(Object error) {
    if (_errorRecoveryService != null) {
      _errorRecoveryService!.handleServiceError(
        _serviceName,
        error,
        operation: 'chatStream',
      );
    } else {
      AppLogger.error('Error in chat stream', error);
    }
    _notifyStateChange();
  }

  /// Execute operation with error handling
  Future<T> _executeWithErrorHandling<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    if (_errorRecoveryService != null) {
      return await _errorRecoveryService!.executeServiceOperation(
        _serviceName,
        operation,
        operationName: operationName,
      );
    } else {
      return await operation();
    }
  }

  /// Validate state consistency
  bool validateState() {
    try {
      // Check basic state consistency
      if (_chats.isEmpty && _activeChat != null) {
        AppLogger.warning('Invalid state: active chat exists but no chats available');
        return false;
      }

      if (_activeChat != null && !_chats.any((chat) => chat.id == _activeChat!.id)) {
        AppLogger.warning('Invalid state: active chat not found in chats list');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('Error validating state', e);
      return false;
    }
  }

  /// Reset state to a consistent state
  void resetState() {
    try {
      AppLogger.info('Resetting ChatStateManager state');
      
      // Clear active chat if it's not in the chats list
      if (_activeChat != null && !_chats.any((chat) => chat.id == _activeChat!.id)) {
        _activeChat = null;
      }
      
      // Set active chat to most recent if none is set
      _setActiveToMostRecentIfNeeded();
      
      _notifyStateChange();
      
      AppLogger.info('ChatStateManager state reset completed');
    } catch (e) {
      AppLogger.error('Error resetting state', e);
    }
  }

  /// Dispose of resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    
    // Cancel subscription first to prevent further state updates
    _chatStreamSubscription?.cancel();
    _chatStreamSubscription = null;
    
    // Close stream controller
    if (!_stateController.isClosed) {
      _stateController.close();
    }
    
    AppLogger.info('ChatStateManager disposed');
  }
}

/// State container for ChatStateManager
class ChatStateManagerState {
  final List<Chat> chats;
  final Chat? activeChat;
  final bool shouldScrollToBottomOnChatSwitch;

  const ChatStateManagerState({
    required this.chats,
    this.activeChat,
    required this.shouldScrollToBottomOnChatSwitch,
  });

  /// Create initial state
  factory ChatStateManagerState.initial() {
    return const ChatStateManagerState(
      chats: [],
      activeChat: null,
      shouldScrollToBottomOnChatSwitch: false,
    );
  }

  /// Create a copy with updated fields
  ChatStateManagerState copyWith({
    List<Chat>? chats,
    Chat? activeChat,
    bool? shouldScrollToBottomOnChatSwitch,
    bool clearActiveChat = false,
  }) {
    return ChatStateManagerState(
      chats: chats ?? this.chats,
      activeChat: clearActiveChat ? null : (activeChat ?? this.activeChat),
      shouldScrollToBottomOnChatSwitch:
          shouldScrollToBottomOnChatSwitch ?? this.shouldScrollToBottomOnChatSwitch,
    );
  }

  /// Validation
  bool get isValid => _validateState();

  bool _validateState() {
    // Basic validation rules
    if (chats.isEmpty && activeChat != null) {
      return false; // Can't have active chat without any chats
    }

    if (activeChat != null && !chats.contains(activeChat)) {
      return false; // Active chat must be in the chats list
    }

    return true;
  }

  @override
  String toString() {
    return 'ChatStateManagerState('
        'chats: ${chats.length}, '
        'activeChat: ${activeChat?.id}, '
        'shouldScrollToBottomOnChatSwitch: $shouldScrollToBottomOnChatSwitch'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatStateManagerState &&
        other.chats.length == chats.length &&
        other.activeChat?.id == activeChat?.id &&
        other.shouldScrollToBottomOnChatSwitch == shouldScrollToBottomOnChatSwitch;
  }

  @override
  int get hashCode {
    return Object.hash(
      chats.length,
      activeChat?.id,
      shouldScrollToBottomOnChatSwitch,
    );
  }
}