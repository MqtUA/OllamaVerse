import 'dart:async';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_history_service.dart';
import '../services/error_recovery_service.dart';

import '../utils/logger.dart';

/// Manages chat list and active chat state
///
/// This service centralizes chat state management to ensure consistency
/// across the application and prevent race conditions that occurred when
/// state was managed directly in the provider
class ChatStateManager {
  final ChatHistoryService _chatHistoryService;
  final ErrorRecoveryService? _errorRecoveryService;

  List<Chat> _chats = [];
  Chat? _activeChat;
  bool _shouldScrollToBottomOnChatSwitch = false;

  StreamSubscription? _chatStreamSubscription;
  bool _disposed = false;

  // Prevents race conditions during concurrent state updates
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
  bool get shouldScrollToBottomOnChatSwitch =>
      _shouldScrollToBottomOnChatSwitch;

  /// Current state snapshot
  ChatStateManagerState get currentState => ChatStateManagerState(
        chats: chats,
        activeChat: activeChat,
        shouldScrollToBottomOnChatSwitch: shouldScrollToBottomOnChatSwitch,
      );

  ChatStateManager({
    required ChatHistoryService chatHistoryService,
    ErrorRecoveryService? errorRecoveryService,
  })  : _chatHistoryService = chatHistoryService,
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
      
      // Validate and clean up invalid chat references
      await _validateAndCleanupChats();
      
      _setActiveToMostRecentIfNeeded();
      _notifyStateChange();

      AppLogger.info('Successfully loaded ${_chats.length} existing chats');
    } catch (e) {
      AppLogger.error('Error loading existing chats in ChatStateManager', e);
      rethrow;
    }
  }

  /// Validate existing chat IDs and clean up invalid references
  /// This ensures data consistency on application startup
  Future<void> _validateAndCleanupChats() async {
    try {
      AppLogger.info('Starting comprehensive chat validation and cleanup');
      
      final validChats = <Chat>[];
      final invalidChatIds = <String>[];
      final duplicateIds = <String>[];
      final corruptedChats = <String>[];
      
      for (final chat in _chats) {
        // Basic validation checks
        if (chat.id.isEmpty) {
          AppLogger.warning('Found chat with empty ID, removing: ${chat.title}');
          invalidChatIds.add('empty_id_${DateTime.now().millisecondsSinceEpoch}');
          continue;
        }
        
        // Check for duplicate IDs
        if (validChats.any((validChat) => validChat.id == chat.id)) {
          AppLogger.warning('Found duplicate chat ID, removing duplicate: ${chat.id}');
          duplicateIds.add(chat.id);
          continue;
        }
        
        // Validate chat structure
        if (chat.title.isEmpty || chat.modelName.isEmpty) {
          AppLogger.warning('Found chat with invalid structure, removing: ${chat.id}');
          corruptedChats.add(chat.id);
          continue;
        }
        
        // Validate timestamps
        if (chat.createdAt.isAfter(DateTime.now()) || 
            chat.lastUpdatedAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
          AppLogger.warning('Found chat with invalid timestamps, fixing: ${chat.id}');
          // Fix the timestamps instead of removing the chat
          final fixedChat = chat.copyWith(
            createdAt: chat.createdAt.isAfter(DateTime.now()) ? DateTime.now() : chat.createdAt,
            lastUpdatedAt: chat.lastUpdatedAt.isAfter(DateTime.now()) ? DateTime.now() : chat.lastUpdatedAt,
          );
          validChats.add(fixedChat);
          continue;
        }
        
        // Validate messages structure
        bool hasInvalidMessages = false;
        final validMessages = <Message>[];
        
        for (final message in chat.messages) {
          if (message.id.isEmpty || message.content.isEmpty) {
            AppLogger.warning('Found invalid message in chat ${chat.id}, removing message');
            hasInvalidMessages = true;
            continue;
          }
          validMessages.add(message);
        }
        
        if (hasInvalidMessages) {
          // Create a new chat with only valid messages
          final cleanedChat = chat.copyWith(messages: validMessages);
          validChats.add(cleanedChat);
          AppLogger.info('Cleaned invalid messages from chat: ${chat.id}');
        } else {
          validChats.add(chat);
        }
      }
      
      // Update the chat list with only valid chats
      final originalCount = _chats.length;
      _chats = validChats;
      
      // Remove invalid chats from storage
      final allInvalidIds = [...invalidChatIds, ...duplicateIds, ...corruptedChats];
      for (final invalidId in allInvalidIds) {
        try {
          if (invalidId.startsWith('empty_id_')) {
            // Skip empty IDs as they can't be deleted from storage
            continue;
          }
          await _chatHistoryService.deleteChat(invalidId);
          AppLogger.info('Removed invalid chat from storage: $invalidId');
        } catch (e) {
          AppLogger.error('Failed to remove invalid chat from storage: $invalidId', e);
        }
      }
      
      // Log cleanup summary
      final cleanedCount = originalCount - _chats.length;
      if (cleanedCount > 0) {
        AppLogger.info('Chat cleanup completed: $cleanedCount invalid chats removed, ${_chats.length} valid chats remaining');
        AppLogger.info('Cleanup details: ${invalidChatIds.length} empty IDs, ${duplicateIds.length} duplicates, ${corruptedChats.length} corrupted');
      } else {
        AppLogger.info('Chat validation completed: All ${_chats.length} chats are valid');
      }
      
      // Validate active chat after cleanup
      if (_activeChat != null && !_chats.any((c) => c.id == _activeChat!.id)) {
        AppLogger.warning('Active chat was removed during cleanup, clearing active chat');
        _activeChat = null;
      }
      
    } catch (e) {
      AppLogger.error('Error during chat validation and cleanup', e);
      // Don't rethrow - we want the app to continue even if cleanup fails
    }
  }

  /// Set active chat to most recent if no active chat is currently set
  ///
  /// This ensures users always have a chat selected when the app starts,
  /// providing a better user experience than showing an empty state
  void _setActiveToMostRecentIfNeeded() {
    if (_activeChat == null && _chats.isNotEmpty) {
      final sortedChats = List<Chat>.from(_chats);
      sortedChats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

      // Find the first chat with a valid ID
      final validChat = sortedChats.firstWhere(
        (chat) => chat.id.isNotEmpty,
        orElse: () => sortedChats.first,
      );

      // Only set active chat if we have a valid ID
      if (validChat.id.isNotEmpty) {
        try {
          setActiveChat(validChat.id);
          AppLogger.info('Set active chat to most recent: ${_activeChat?.title}');
        } catch (e) {
          AppLogger.warning('Failed to set active chat to most recent: ${e.toString()}');
        }
      } else {
        AppLogger.warning('No valid chats available to set as active');
      }
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

      // Generate unique chat ID with additional entropy to prevent collisions
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch % 1000;
      final chatId = '${timestamp}_$random';
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
          id: '${timestamp}_${random}_system',
          content: systemPrompt,
          role: MessageRole.system,
          timestamp: DateTime.now(),
        );
        newChat.messages.add(systemMessage);
      }

      // ATOMIC OPERATION: Save to storage first, then update local state
      // This ensures the chat exists in persistent storage before we reference it
      try {
        await _chatHistoryService.saveChat(newChat);
        AppLogger.info('Chat saved to storage: $chatTitle');
      } catch (e) {
        AppLogger.error('Failed to save chat to storage: $chatTitle', e);
        throw Exception('Failed to create chat: Unable to save to storage. ${e.toString()}');
      }

      // Add to local chat list immediately to prevent race conditions
      // This ensures the chat is available in _chats before setting as active
      if (!_chats.any((chat) => chat.id == chatId)) {
        _chats.add(newChat);
        AppLogger.info('Chat added to local list: $chatTitle');
      }

      // Now safely set as active chat since it exists in both storage and local list
      _activeChat = newChat;
      _notifyStateChange();

      AppLogger.info('Created new chat successfully: $chatTitle (ID: $chatId)');
      return newChat;
    } catch (e) {
      AppLogger.error('Error creating new chat', e);
      
      // Provide meaningful error messages based on error type
      if (e.toString().contains('storage')) {
        throw Exception('Failed to create chat: Storage error. Please check your device storage and try again.');
      } else if (e.toString().contains('disposed') || e is StateError) {
        // Re-throw StateError as-is for proper test compatibility
        rethrow;
      } else {
        throw Exception('Failed to create chat: ${e.toString()}');
      }
    }
  }

  /// Set the active chat by ID
  void setActiveChat(String chatId) {
    _validateNotDisposed();

    // Validate chat ID format first
    if (chatId.isEmpty) {
      AppLogger.warning('Attempted to set active chat with empty ID');
      throw ArgumentError('Cannot set active chat: Chat ID cannot be empty');
    }

    // First try to find the chat in the local list
    Chat? chat;
    try {
      chat = _chats.firstWhere((c) => c.id == chatId);
    } catch (e) {
      chat = null;
    }

    // If chat not found, provide meaningful error message
    if (chat == null) {
      AppLogger.warning('Chat with ID $chatId not found in local list');
      
      // Provide helpful error message based on current state
      if (_chats.isEmpty) {
        throw ArgumentError('Cannot set active chat: No chats available. Please create a new chat first.');
      } else {
        final availableIds = _chats.map((c) => c.id).take(3).join(', ');
        throw ArgumentError('Chat with ID $chatId not found. Available chats: $availableIds${_chats.length > 3 ? '...' : ''}');
      }
    }

    _setActiveChatInternal(chat);
  }

  /// Set the active chat by ID with recovery attempt
  /// This is the resilient version that attempts recovery
  Future<void> setActiveChatWithRecovery(String chatId) async {
    _validateNotDisposed();

    // First try to find the chat in the local list
    Chat? chat;
    try {
      chat = _chats.firstWhere((c) => c.id == chatId);
    } catch (e) {
      chat = null;
    }

    // If chat not found in local list, try to recover from storage
    if (chat == null) {
      AppLogger.warning('Chat with ID $chatId not found in local list, attempting recovery');
      
      final recoveredChat = await _recoverMissingChat(chatId);
      if (recoveredChat != null) {
        AppLogger.info('Successfully recovered chat: ${recoveredChat.title}');
        // Add to local list if not already present
        if (!_chats.any((c) => c.id == chatId)) {
          _chats.add(recoveredChat);
        }
        // Set as active
        _setActiveChatInternal(recoveredChat);
        return;
      } else {
        AppLogger.error('Failed to recover chat with ID $chatId');
        throw ArgumentError('Chat with ID $chatId not found and could not be recovered');
      }
    }

    _setActiveChatInternal(chat);
  }

  /// Internal method to set active chat with proper state management
  void _setActiveChatInternal(Chat chat) {
    final previousActiveChat = _activeChat;
    _activeChat = chat;

    // Auto-scroll is needed when switching to a different chat with messages
    // to ensure users see the latest conversation context immediately
    if ((previousActiveChat?.id != chat.id || previousActiveChat == null) &&
        chat.messages.isNotEmpty) {
      _shouldScrollToBottomOnChatSwitch = true;
      AppLogger.info(
          'Triggering auto-scroll for chat switch to: ${chat.title}');
    } else {
      _shouldScrollToBottomOnChatSwitch = false;
    }

    _notifyStateChange();
    AppLogger.info('Set active chat to: ${chat.title}');
  }

  /// Attempt to recover a missing chat from storage
  Future<Chat?> _recoverMissingChat(String chatId) async {
    try {
      final recoveredChat = await _chatHistoryService.getChat(chatId);
      if (recoveredChat != null) {
        AppLogger.info('Recovered chat from storage: ${recoveredChat.title}');
        return recoveredChat;
      }
    } catch (e) {
      AppLogger.error('Error recovering chat from storage', e);
    }
    return null;
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

      // Validate input parameters
      if (newTitle.trim().isEmpty) {
        throw ArgumentError('Chat title cannot be empty');
      }

      // Comprehensive validation with recovery
      final validationResult = await validateChatForOperation(chatId, 'updateChatTitle');
      if (!validationResult.isValid) {
        throw ArgumentError(validationResult.errorMessage ?? 'Chat validation failed');
      }

      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex == -1) {
        throw ArgumentError('Chat with ID $chatId not found in local list after validation');
      }

      final updatedChat = _chats[chatIndex].copyWith(
        title: newTitle.trim(),
        lastUpdatedAt: DateTime.now(),
      );

      // Update local list
      _chats[chatIndex] = updatedChat;

      // Update active chat if this is the active one
      if (_activeChat?.id == chatId) {
        _activeChat = updatedChat;
      }

      // Save to service - this will trigger the stream update
      try {
        await _chatHistoryService.saveChat(updatedChat);
        AppLogger.info('Updated chat title: $newTitle');
      } catch (e) {
        AppLogger.error('Failed to save chat title update to storage', e);
        throw Exception('Failed to update chat title: Unable to save to storage. ${e.toString()}');
      }

      _notifyStateChange();
    } catch (e) {
      AppLogger.error('Error updating chat title', e);
      rethrow;
    }
  }

  /// Update chat model
  Future<void> updateChatModel(String chatId, String newModelName) async {
    try {
      _validateNotDisposed();

      // Validate input parameters
      if (newModelName.trim().isEmpty) {
        throw ArgumentError('Model name cannot be empty');
      }

      // Comprehensive validation with recovery
      final validationResult = await validateChatForOperation(chatId, 'updateChatModel');
      if (!validationResult.isValid) {
        throw ArgumentError(validationResult.errorMessage ?? 'Chat validation failed');
      }

      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex == -1) {
        throw ArgumentError('Chat with ID $chatId not found in local list after validation');
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
        modelName: newModelName.trim(),
        title:
            isDefaultTitle ? 'New chat with $newModelName' : currentChat.title,
        lastUpdatedAt: DateTime.now(),
      );

      // Update local list
      _chats[chatIndex] = updatedChat;

      // Update active chat if this is the active one
      if (_activeChat?.id == chatId) {
        _activeChat = updatedChat;
      }

      // Save to service - this will trigger the stream update
      try {
        await _chatHistoryService.saveChat(updatedChat);
        AppLogger.info('Updated chat model to: $newModelName');
      } catch (e) {
        AppLogger.error('Failed to save chat model update to storage', e);
        throw Exception('Failed to update chat model: Unable to save to storage. ${e.toString()}');
      }

      _notifyStateChange();
    } catch (e) {
      AppLogger.error('Error updating chat model', e);
      rethrow;
    }
  }

  /// Update chat with new messages or other changes
  Future<void> updateChat(Chat updatedChat) async {
    try {
      _validateNotDisposed();

      // Check if chat exists in local list first
      final chatIndex = _chats.indexWhere((c) => c.id == updatedChat.id);
      if (chatIndex == -1) {
        // For test compatibility, throw error if chat doesn't exist
        throw ArgumentError('Chat with ID ${updatedChat.id} not found');
      }

      // Update the existing chat in local list
      _chats[chatIndex] = updatedChat;

      // Update active chat if this is the active one
      if (_activeChat?.id == updatedChat.id) {
        _activeChat = updatedChat;
      }

      // Save to service - this will trigger the stream update
      try {
        await _chatHistoryService.saveChat(updatedChat);
        AppLogger.info('Updated chat: ${updatedChat.title}');
      } catch (e) {
        AppLogger.error('Failed to save updated chat to storage', e);
        throw Exception('Failed to update chat: Unable to save to storage. ${e.toString()}');
      }

      _notifyStateChange();
    } catch (e) {
      AppLogger.error('Error updating chat', e);
      rethrow;
    }
  }

  /// Update chat with recovery - resilient version that handles missing chats
  Future<void> updateChatWithRecovery(Chat updatedChat) async {
    try {
      _validateNotDisposed();

      // Ensure the chat exists, with recovery attempt if missing
      final chatExists = await ensureChatExists(updatedChat.id);
      if (!chatExists) {
        AppLogger.warning('Chat ${updatedChat.id} not found, adding as new chat');
        // Add the chat to local list since it doesn't exist
        _chats.add(updatedChat);
      } else {
        // Update the existing chat in local list
        final chatIndex = _chats.indexWhere((c) => c.id == updatedChat.id);
        if (chatIndex != -1) {
          _chats[chatIndex] = updatedChat;
        }
      }

      // Update active chat if this is the active one
      if (_activeChat?.id == updatedChat.id) {
        _activeChat = updatedChat;
      }

      // Save to service - this will trigger the stream update
      try {
        await _chatHistoryService.saveChat(updatedChat);
        AppLogger.info('Updated chat: ${updatedChat.title}');
      } catch (e) {
        AppLogger.error('Failed to save updated chat to storage', e);
        throw Exception('Failed to update chat: Unable to save to storage. ${e.toString()}');
      }

      _notifyStateChange();
    } catch (e) {
      AppLogger.error('Error updating chat', e);
      rethrow;
    }
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    try {
      _validateNotDisposed();

      // Validate chat ID format
      if (chatId.isEmpty) {
        throw ArgumentError('Cannot delete chat: Chat ID cannot be empty');
      }

      // Find the index of the chat to be deleted
      final int index = _chats.indexWhere((c) => c.id == chatId);
      if (index == -1) {
        // Provide helpful error message
        if (_chats.isEmpty) {
          throw ArgumentError('Cannot delete chat: No chats available');
        } else {
          final availableIds = _chats.map((c) => c.id).take(3).join(', ');
          throw ArgumentError('Chat with ID $chatId not found. Available chats: $availableIds${_chats.length > 3 ? '...' : ''}');
        }
      }

      final chatToDelete = _chats[index];
      AppLogger.info('Deleting chat: ${chatToDelete.title} (ID: $chatId)');

      // Optimistically remove the chat from the local list
      _chats.removeAt(index);

      // If the deleted chat was active, set active chat to most recent or null
      if (_activeChat?.id == chatId) {
        if (_chats.isNotEmpty) {
          // Sort by last updated to get most recent
          final sortedChats = List<Chat>.from(_chats);
          sortedChats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
          _activeChat = sortedChats.first;
          AppLogger.info('Set active chat to most recent: ${_activeChat!.title}');
        } else {
          _activeChat = null;
          AppLogger.info('No chats remaining, cleared active chat');
        }
      }

      _notifyStateChange(); // Notify listeners immediately to update UI

      // Perform the asynchronous deletion from the history service
      try {
        await _chatHistoryService.deleteChat(chatId);
        AppLogger.info('Successfully deleted chat from storage: ${chatToDelete.title}');
      } catch (e) {
        AppLogger.error('Failed to delete chat from storage', e);
        // If deletion fails, the _chatHistoryService.chatStream should ideally
        // re-emit the original list, which will then cause the UI to revert.
        throw Exception('Failed to delete chat "${chatToDelete.title}": Unable to remove from storage. ${e.toString()}');
      }
    } catch (e) {
      AppLogger.error('Error deleting chat', e);
      rethrow;
    }
  }

  /// Get a specific chat by ID
  Chat? getChatById(String chatId) {
    if (chatId.isEmpty || _disposed) return null;
    
    try {
      // Use more efficient lookup for large lists
      for (final chat in _chats) {
        if (chat.id == chatId) {
          return chat;
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting chat by ID: $chatId', e);
      return null;
    }
  }

  /// Check if a chat exists
  bool chatExists(String chatId) {
    if (chatId.isEmpty || _disposed) return false;
    
    // Use more efficient lookup for large lists
    for (final chat in _chats) {
      if (chat.id == chatId) {
        return true;
      }
    }
    return false;
  }

  /// Validate that a chat exists before performing operations
  /// Returns true if chat exists, false otherwise
  bool validateChatExists(String chatId, {String? operationName}) {
    final exists = chatExists(chatId);
    if (!exists) {
      final operation = operationName ?? 'operation';
      AppLogger.warning('Chat validation failed for $operation: Chat ID $chatId not found');
    }
    return exists;
  }

  /// Comprehensive validation of chat ID before operations
  /// This method performs thorough validation and provides detailed error information
  Future<ChatValidationResult> validateChatForOperation(
    String chatId, 
    String operationName
  ) async {
    try {
      // Basic validation - check if chat ID is valid format
      if (chatId.isEmpty) {
        return ChatValidationResult.invalid(
          'Empty chat ID provided for $operationName',
          ChatValidationError.emptyId
        );
      }

      // Check if chat exists in local list
      if (chatExists(chatId)) {
        return ChatValidationResult.valid();
      }

      // Chat not found in local list - attempt recovery
      AppLogger.info('Chat $chatId not found locally for $operationName, attempting recovery');
      
      final recoveredChat = await _recoverMissingChat(chatId);
      if (recoveredChat != null) {
        // Add to local list if not already present
        if (!_chats.any((c) => c.id == chatId)) {
          _chats.add(recoveredChat);
          _notifyStateChange();
        }
        
        AppLogger.info('Successfully recovered chat $chatId for $operationName');
        return ChatValidationResult.recovered(recoveredChat);
      }

      // Recovery failed - chat truly doesn't exist
      AppLogger.warning('Chat validation failed for $operationName: Chat ID $chatId not found and could not be recovered');
      return ChatValidationResult.invalid(
        'Chat with ID $chatId not found and could not be recovered for $operationName',
        ChatValidationError.notFound
      );

    } catch (e) {
      AppLogger.error('Error during chat validation for $operationName', e);
      return ChatValidationResult.invalid(
        'Error validating chat $chatId for $operationName: ${e.toString()}',
        ChatValidationError.validationError
      );
    }
  }

  /// Ensure a chat exists, with recovery attempt if missing
  Future<bool> ensureChatExists(String chatId) async {
    // First check local list
    if (chatExists(chatId)) {
      return true;
    }

    // Try to recover from storage
    try {
      final recoveredChat = await _recoverMissingChat(chatId);
      if (recoveredChat != null) {
        // Add to local list if not already present
        if (!_chats.any((c) => c.id == chatId)) {
          _chats.add(recoveredChat);
          _notifyStateChange();
        }
        return true;
      }
    } catch (e) {
      AppLogger.error('Error ensuring chat exists for ID $chatId', e);
    }

    return false;
  }

  /// Get displayable messages for the active chat
  List<Message> get displayableMessages {
    if (_activeChat == null) return [];
    return _activeChat!.messages.where((msg) => !msg.isSystem).toList();
  }
  
  /// Refresh the active chat from storage
  /// 
  /// This is useful when settings or other properties have changed
  /// but the chat ID remains the same
  Future<void> refreshActiveChat() async {
    try {
      _validateNotDisposed();
      
      if (_activeChat == null) return;
      
      final chatId = _activeChat!.id;
      final refreshedChat = await _chatHistoryService.getChat(chatId);
      
      if (refreshedChat != null) {
        _activeChat = refreshedChat;
        _notifyStateChange();
        AppLogger.info('Refreshed active chat: ${refreshedChat.title}');
      }
    } catch (e) {
      AppLogger.error('Error refreshing active chat', e);
      rethrow;
    }
  }

  /// Validate that the manager is not disposed
  void _validateNotDisposed() {
    if (_disposed) {
      throw StateError('ChatStateManager has been disposed');
    }
  }

  /// Notify listeners of state changes
  void _notifyStateChange() {
    if (_disposed) return;

    // Prevent recursive state updates but allow queued updates
    if (_isUpdatingState) {
      // Schedule the update for the next event loop iteration
      Future.microtask(() => _notifyStateChange());
      return;
    }

    _isUpdatingState = true;
    try {
      if (!_stateController.isClosed) {
        _stateController.add(currentState);
      }
    } catch (e) {
      AppLogger.error('Error notifying state change', e);
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
        AppLogger.warning(
            'Invalid state: active chat exists but no chats available');
        return false;
      }

      if (_activeChat != null &&
          !_chats.any((chat) => chat.id == _activeChat!.id)) {
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
      if (_activeChat != null &&
          !_chats.any((chat) => chat.id == _activeChat!.id)) {
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

  /// Handle edge cases in chat state management
  /// This method addresses various edge cases that can occur during normal operation
  Future<void> handleChatStateEdgeCases() async {
    try {
      AppLogger.info('Checking for chat state edge cases');
      
      // Edge case 1: Active chat exists but not in chats list
      if (_activeChat != null && !_chats.any((c) => c.id == _activeChat!.id)) {
        AppLogger.warning('Edge case detected: Active chat not in chats list, attempting recovery');
        
        final recoveredChat = await _recoverMissingChat(_activeChat!.id);
        if (recoveredChat != null) {
          _chats.add(recoveredChat);
          AppLogger.info('Recovered missing active chat: ${recoveredChat.title}');
        } else {
          AppLogger.warning('Could not recover active chat, clearing active chat');
          _activeChat = null;
        }
      }
      
      // Edge case 2: Chats exist but no active chat is set
      if (_chats.isNotEmpty && _activeChat == null) {
        AppLogger.info('Edge case detected: No active chat set, setting to most recent');
        _setActiveToMostRecentIfNeeded();
      }
      
      // Edge case 3: Duplicate chat IDs in local list
      final seenIds = <String>{};
      final uniqueChats = <Chat>[];
      
      for (final chat in _chats) {
        if (!seenIds.contains(chat.id)) {
          seenIds.add(chat.id);
          uniqueChats.add(chat);
        } else {
          AppLogger.warning('Edge case detected: Duplicate chat ID in local list: ${chat.id}');
        }
      }
      
      if (uniqueChats.length != _chats.length) {
        _chats = uniqueChats;
        AppLogger.info('Removed ${_chats.length - uniqueChats.length} duplicate chats from local list');
      }
      
      // Edge case 4: Chat with invalid timestamps
      bool hasInvalidTimestamps = false;
      final fixedChats = <Chat>[];
      
      for (final chat in _chats) {
        if (chat.createdAt.isAfter(chat.lastUpdatedAt)) {
          AppLogger.warning('Edge case detected: Chat created after last updated: ${chat.id}');
          final fixedChat = chat.copyWith(lastUpdatedAt: chat.createdAt);
          fixedChats.add(fixedChat);
          hasInvalidTimestamps = true;
        } else {
          fixedChats.add(chat);
        }
      }
      
      if (hasInvalidTimestamps) {
        _chats = fixedChats;
        AppLogger.info('Fixed invalid timestamps in chat list');
      }
      
      // Edge case 5: Empty chat list but active chat exists
      if (_chats.isEmpty && _activeChat != null) {
        AppLogger.warning('Edge case detected: Empty chat list but active chat exists, clearing active chat');
        _activeChat = null;
      }
      
      _notifyStateChange();
      AppLogger.info('Chat state edge case handling completed');
      
    } catch (e) {
      AppLogger.error('Error handling chat state edge cases', e);
      // Don't rethrow - we want the app to continue even if edge case handling fails
    }
  }

  /// Perform comprehensive state validation and recovery
  /// This method can be called periodically or when issues are suspected
  Future<ChatStateHealthReport> performHealthCheck() async {
    try {
      AppLogger.info('Performing ChatStateManager health check');
      
      final report = ChatStateHealthReport();
      
      // Check 1: Basic state consistency
      if (_chats.isEmpty && _activeChat != null) {
        report.addIssue('Active chat exists but no chats available', ChatStateIssueType.inconsistentState);
      }
      
      if (_activeChat != null && !_chats.any((c) => c.id == _activeChat!.id)) {
        report.addIssue('Active chat not found in chats list', ChatStateIssueType.missingActiveChat);
      }
      
      // Check 2: Chat data integrity
      for (final chat in _chats) {
        if (chat.id.isEmpty) {
          report.addIssue('Chat with empty ID found', ChatStateIssueType.invalidChatData);
        }
        
        if (chat.title.isEmpty) {
          report.addIssue('Chat with empty title found: ${chat.id}', ChatStateIssueType.invalidChatData);
        }
        
        if (chat.modelName.isEmpty) {
          report.addIssue('Chat with empty model name found: ${chat.id}', ChatStateIssueType.invalidChatData);
        }
        
        if (chat.createdAt.isAfter(chat.lastUpdatedAt)) {
          report.addIssue('Chat with invalid timestamps: ${chat.id}', ChatStateIssueType.invalidTimestamps);
        }
        
        // Check for future timestamps
        final now = DateTime.now();
        if (chat.createdAt.isAfter(now.add(const Duration(minutes: 1))) ||
            chat.lastUpdatedAt.isAfter(now.add(const Duration(minutes: 1)))) {
          report.addIssue('Chat with future timestamps: ${chat.id}', ChatStateIssueType.invalidTimestamps);
        }
      }
      
      // Check 3: Duplicate chat IDs
      final seenIds = <String>{};
      for (final chat in _chats) {
        if (seenIds.contains(chat.id)) {
          report.addIssue('Duplicate chat ID found: ${chat.id}', ChatStateIssueType.duplicateIds);
        }
        seenIds.add(chat.id);
      }
      
      // Check 4: Storage consistency (if possible)
      try {
        final storageChats = _chatHistoryService.chats;
        if (storageChats.length != _chats.length) {
          report.addIssue('Local chat count (${_chats.length}) differs from storage count (${storageChats.length})', 
                         ChatStateIssueType.storageInconsistency);
        }
      } catch (e) {
        report.addIssue('Could not verify storage consistency: ${e.toString()}', ChatStateIssueType.storageError);
      }
      
      // Attempt to fix issues if any were found
      if (report.hasIssues) {
        AppLogger.warning('Health check found ${report.issueCount} issues, attempting fixes');
        await handleChatStateEdgeCases();
        await _validateAndCleanupChats();
        report.addFix('Performed edge case handling and cleanup');
      }
      
      report.markComplete();
      AppLogger.info('Health check completed: ${report.isHealthy ? 'HEALTHY' : 'ISSUES FOUND'}');
      
      return report;
      
    } catch (e) {
      AppLogger.error('Error during health check', e);
      final errorReport = ChatStateHealthReport();
      errorReport.addIssue('Health check failed: ${e.toString()}', ChatStateIssueType.healthCheckError);
      errorReport.markComplete();
      return errorReport;
    }
  }

  /// Dispose of resources
  void dispose() {
    if (_disposed) return;
    
    AppLogger.info('Disposing ChatStateManager');
    _disposed = true;

    try {
      // Cancel subscription first to prevent further state updates
      _chatStreamSubscription?.cancel();
      _chatStreamSubscription = null;
    } catch (e) {
      AppLogger.error('Error cancelling chat stream subscription', e);
    }

    try {
      // Close stream controller safely
      if (!_stateController.isClosed) {
        _stateController.close();
      }
    } catch (e) {
      AppLogger.error('Error closing state controller', e);
    }

    // Clear references to help with garbage collection
    _chats.clear();
    _activeChat = null;

    AppLogger.info('ChatStateManager disposed successfully');
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
      shouldScrollToBottomOnChatSwitch: shouldScrollToBottomOnChatSwitch ??
          this.shouldScrollToBottomOnChatSwitch,
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
        other.shouldScrollToBottomOnChatSwitch ==
            shouldScrollToBottomOnChatSwitch;
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

/// Result of chat validation operations
class ChatValidationResult {
  final bool isValid;
  final String? errorMessage;
  final ChatValidationError? errorType;
  final Chat? recoveredChat;

  const ChatValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.errorType,
    this.recoveredChat,
  });

  /// Create a valid result
  factory ChatValidationResult.valid() {
    return const ChatValidationResult._(isValid: true);
  }

  /// Create an invalid result with error details
  factory ChatValidationResult.invalid(String message, ChatValidationError errorType) {
    return ChatValidationResult._(
      isValid: false,
      errorMessage: message,
      errorType: errorType,
    );
  }

  /// Create a result indicating successful recovery
  factory ChatValidationResult.recovered(Chat chat) {
    return ChatValidationResult._(
      isValid: true,
      recoveredChat: chat,
    );
  }

  /// Whether the chat was recovered during validation
  bool get wasRecovered => recoveredChat != null;

  @override
  String toString() {
    if (isValid) {
      return wasRecovered 
        ? 'ChatValidationResult.recovered(${recoveredChat!.title})'
        : 'ChatValidationResult.valid()';
    } else {
      return 'ChatValidationResult.invalid($errorMessage, $errorType)';
    }
  }
}

/// Types of chat validation errors
enum ChatValidationError {
  emptyId,
  notFound,
  validationError,
  recoveryFailed,
}

/// Health report for ChatStateManager
class ChatStateHealthReport {
  final List<String> _issues = [];
  final List<String> _fixes = [];
  final DateTime _startTime = DateTime.now();
  DateTime? _endTime;

  /// Add an issue to the report
  void addIssue(String issue, ChatStateIssueType type) {
    _issues.add('[$type] $issue');
  }

  /// Add a fix that was applied
  void addFix(String fix) {
    _fixes.add(fix);
  }

  /// Mark the health check as complete
  void markComplete() {
    _endTime = DateTime.now();
  }

  /// Whether any issues were found
  bool get hasIssues => _issues.isNotEmpty;

  /// Whether the state is healthy (no issues)
  bool get isHealthy => _issues.isEmpty;

  /// Number of issues found
  int get issueCount => _issues.length;

  /// Number of fixes applied
  int get fixCount => _fixes.length;

  /// Duration of the health check
  Duration get duration => (_endTime ?? DateTime.now()).difference(_startTime);

  /// List of all issues found
  List<String> get issues => List.unmodifiable(_issues);

  /// List of all fixes applied
  List<String> get fixes => List.unmodifiable(_fixes);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ChatStateHealthReport:');
    buffer.writeln('  Status: ${isHealthy ? 'HEALTHY' : 'ISSUES FOUND'}');
    buffer.writeln('  Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('  Issues: $issueCount');
    buffer.writeln('  Fixes: $fixCount');
    
    if (_issues.isNotEmpty) {
      buffer.writeln('  Issue Details:');
      for (final issue in _issues) {
        buffer.writeln('    - $issue');
      }
    }
    
    if (_fixes.isNotEmpty) {
      buffer.writeln('  Fixes Applied:');
      for (final fix in _fixes) {
        buffer.writeln('    - $fix');
      }
    }
    
    return buffer.toString();
  }
}

/// Types of chat state issues
enum ChatStateIssueType {
  inconsistentState,
  missingActiveChat,
  invalidChatData,
  invalidTimestamps,
  duplicateIds,
  storageInconsistency,
  storageError,
  healthCheckError,
}
