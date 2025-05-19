import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../models/ollama_model.dart';
import '../services/ollama_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import 'settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  late OllamaService _ollamaService;
  
  List<Chat> _chats = [];
  Chat? _activeChat;
  List<OllamaModel> _availableModels = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  String _error = '';

  ChatProvider(SettingsProvider settingsProvider) {
    _ollamaService = OllamaService(settings: settingsProvider.settings);
    _loadChats();
    _loadModels();
    
    // Listen for settings changes
    settingsProvider.addListener(() {
      _ollamaService = OllamaService(settings: settingsProvider.settings);
    });
  }

  // Getters
  List<Chat> get chats => _chats;
  Chat? get activeChat => _activeChat;
  List<OllamaModel> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String get error => _error;

  // Load all chats from storage
  Future<void> _loadChats() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    try {
      _chats = await _storageService.loadAllChats();
      
      // Set active chat to the most recent one if available
      if (_chats.isNotEmpty && _activeChat == null) {
        _activeChat = _chats.first;
      }
    } catch (e) {
      _error = 'Failed to load chats: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load available models from Ollama
  Future<void> _loadModels() async {
    await _refreshModelsWithRetry();
  }

  // Public method to refresh models with retry logic
  Future<bool> _refreshModelsWithRetry({int retryCount = 2, int delaySeconds = 1}) async {
    _error = '';
    notifyListeners();
    
    for (int attempt = 0; attempt <= retryCount; attempt++) {
      try {
        // If not the first attempt, wait before retrying
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: delaySeconds));
        }
        
        _availableModels = await _ollamaService.getModels();
        notifyListeners();
        return true; // Success
      } catch (e) {
        // On last attempt, set the error
        if (attempt == retryCount) {
          _error = 'Failed to load models: $e';
          notifyListeners();
        }
      }
    }
    
    return false; // Failed after all retries
  }

  // Create a new chat
  Future<void> createNewChat(String modelName) async {
    final newChat = Chat(
      title: 'New Chat',
      modelName: modelName,
    );
    
    _chats.insert(0, newChat);
    _activeChat = newChat;
    
    await _storageService.saveChat(newChat);
    notifyListeners();
  }

  // Set active chat
  void setActiveChat(String chatId) {
    final chat = _chats.firstWhere((c) => c.id == chatId);
    _activeChat = chat;
    notifyListeners();
  }

  // Update chat title
  Future<void> updateChatTitle(String chatId, String newTitle) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index >= 0) {
      final updatedChat = _chats[index].copyWith(title: newTitle);
      _chats[index] = updatedChat;
      
      if (_activeChat?.id == chatId) {
        _activeChat = updatedChat;
      }
      
      await _storageService.saveChat(updatedChat);
      notifyListeners();
    }
  }
  
  // Update chat model
  Future<void> updateChatModel(String chatId, String newModelName) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index >= 0) {
      final updatedChat = _chats[index].copyWith(modelName: newModelName);
      _chats[index] = updatedChat;
      
      if (_activeChat?.id == chatId) {
        _activeChat = updatedChat;
      }
      
      await _storageService.saveChat(updatedChat);
      notifyListeners();
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    
    if (_activeChat?.id == chatId) {
      _activeChat = _chats.isNotEmpty ? _chats.first : null;
    }
    
    await _storageService.deleteChat(chatId);
    notifyListeners();
  }

  // Current streaming response content
  String _currentStreamingResponse = '';
  String get currentStreamingResponse => _currentStreamingResponse;
  
  // Cancel the current generation
  void cancelGeneration() {
    if (_isGenerating) {
      _ollamaService.cancelGeneration();
      _isGenerating = false;
      _currentStreamingResponse = '';
      notifyListeners();
    }
  }
  
  // Send a message and get a response
  Future<void> sendMessage(String content, {List<String>? attachedFiles}) async {
    if (_activeChat == null) return;
    
    if (_isGenerating) {
      _ollamaService.cancelGeneration();
      _isGenerating = false;
      _currentStreamingResponse = '';
      notifyListeners();
      return;
    }
    
    // Prepare context from previous messages
    List<dynamic>? context;
    String conversationHistory = '';
  
    // First check if we have a context from previous exchanges
    if (_activeChat!.messages.isNotEmpty) {
      // Get the last AI response if available
      final lastAiMessage = _activeChat!.messages.lastWhere(
        (msg) => !msg.isUser, 
        orElse: () => ChatMessage(content: '', isUser: true)
      );
      
      if (!lastAiMessage.isUser && lastAiMessage.context != null) {
        // We have a previous AI response with context
        context = lastAiMessage.context;
      }
      
      // Build conversation history for better context
      // Include up to the last 10 messages or fewer if there aren't that many
      final historyMessages = _activeChat!.messages.length > 10 ?
          _activeChat!.messages.sublist(_activeChat!.messages.length - 10) :
          _activeChat!.messages;
      
      for (final msg in historyMessages) {
        conversationHistory += msg.isUser ? 
            '\nUser: ${msg.content}\n' : 
            '\nAssistant: ${msg.content}\n';
      }
    }
    
    final userMessage = ChatMessage(
      content: content,
      isUser: true,
      attachedFiles: attachedFiles,
    );
    
    final updatedMessages = [..._activeChat!.messages, userMessage];
    final updatedChat = _activeChat!.copyWith(
      messages: updatedMessages,
    );
    
    _activeChat = updatedChat;
    
    // Update chat in list
    final index = _chats.indexWhere((c) => c.id == updatedChat.id);
    if (index >= 0) {
      _chats[index] = updatedChat;
    }
    
    await _storageService.saveChat(updatedChat);
    notifyListeners();
    
    // Generate AI response
    _isGenerating = true;
    notifyListeners();
    
    try {
      final useStreaming = _ollamaService.settings.showLiveResponse;
      String response;
      
      // Prepare the prompt with conversation history if needed
      String enhancedPrompt = content;
      
      // If this isn't the first message and the prompt is short, it might be a follow-up
      // So include conversation history to provide better context
      if (_activeChat!.messages.length > 1 && content.length < 100) {
        enhancedPrompt = "Previous conversation:\n$conversationHistory\n\nUser: $content";
      }
      
      if (useStreaming) {
        // Use streaming response
        response = await _ollamaService.generateResponse(
          modelName: _activeChat!.modelName,
          prompt: enhancedPrompt,
          attachedFiles: attachedFiles,
          context: context,
          stream: true,
          onStreamResponse: (partialResponse) {
            _currentStreamingResponse += partialResponse;
            notifyListeners();
          },
        );
      } else {
        // Use regular response
        response = await _ollamaService.generateResponse(
          modelName: _activeChat!.modelName,
          prompt: enhancedPrompt,
          attachedFiles: attachedFiles,
          context: context,
        );
      }
      
      // Add AI response with context
      final aiMessage = ChatMessage(
        content: response,
        isUser: false,
        context: context, // Store the context for future messages
      );
      
      final updatedWithAiMessages = [...updatedMessages, aiMessage];
      final updatedWithAiChat = _activeChat!.copyWith(
        messages: updatedWithAiMessages,
      );
      
      _activeChat = updatedWithAiChat;
      
      // Update chat in list
      final updatedIndex = _chats.indexWhere((c) => c.id == updatedWithAiChat.id);
      if (updatedIndex >= 0) {
        _chats[updatedIndex] = updatedWithAiChat;
      }
      
      await _storageService.saveChat(updatedWithAiChat);
      
      // If this is the first message exchange, generate a better title
      if (updatedMessages.length == 1 || _activeChat!.title == 'New Chat') {
        await _generateChatTitle(content, response, _activeChat!.modelName, _activeChat!.id);
      }
    } catch (e) {
      _error = 'Failed to generate response: $e';
    } finally {
      _isGenerating = false;
      _currentStreamingResponse = '';
      notifyListeners();
    }
  }
  
  // Generate a title for the chat using the same Ollama model
  Future<void> _generateChatTitle(String userMessage, String aiResponse, String modelName, String chatId) async {
    try {
      final titlePrompt = "Generate a concise title (2-5 words only) that captures the essence of this conversation. The title should be specific, descriptive, and relevant to the topic discussed.\n\nUser: $userMessage\n\nAssistant: ${aiResponse.substring(0, aiResponse.length > 150 ? 150 : aiResponse.length)}...\n\nTitle (2-5 words only):";
      
      final titleResponse = await _ollamaService.generateResponse(
        modelName: modelName,
        prompt: titlePrompt,
      );
      
      // Clean up the title (remove quotes, newlines, etc.)
      String cleanTitle = titleResponse.trim();
      
      // Remove quotes if present
      if (cleanTitle.startsWith('"') && cleanTitle.endsWith('"')) {
        cleanTitle = cleanTitle.substring(1, cleanTitle.length - 1);
      }
      
      // Remove any "Title:" prefix if the model included it
      if (cleanTitle.toLowerCase().startsWith('title:')) {
        cleanTitle = cleanTitle.substring(6).trim();
      }
      
      // Replace newlines with spaces and trim extra whitespace
      cleanTitle = cleanTitle.replaceAll('\n', ' ').trim();
      
      // Remove any trailing punctuation
      if (cleanTitle.endsWith('.') || cleanTitle.endsWith(',') || cleanTitle.endsWith(':')) {
        cleanTitle = cleanTitle.substring(0, cleanTitle.length - 1);
      }
      
      // Limit title length
      if (cleanTitle.length > 50) {
        cleanTitle = '${cleanTitle.substring(0, 47)}...';
      }
      
      // Capitalize first letter of each word
      cleanTitle = cleanTitle.split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
      ).join(' ');
      
      // Update the chat title
      if (cleanTitle.isNotEmpty) {
        await updateChatTitle(chatId, cleanTitle);
      }
    } catch (e) {
      AppLogger.error('Error generating chat title', e);
      // Fall back to using the first few words of the user message as title
      final defaultTitle = userMessage.length > 30 ? '${userMessage.substring(0, 27)}...' : userMessage;
      await updateChatTitle(chatId, defaultTitle);
    }
  }

  // Refresh available models - used by external components
  Future<bool> refreshModels() async {
    return _refreshModelsWithRetry();
  }
}
