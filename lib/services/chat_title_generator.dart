import 'dart:async';
import '../services/ollama_service.dart';
import '../services/model_manager.dart';
import '../utils/logger.dart';

/// Service responsible for generating chat titles automatically
/// Handles title generation logic with fallback handling and timeout management
class ChatTitleGenerator {
  final OllamaService _ollamaService;

  /// Set of chat IDs currently generating titles
  final Set<String> _chatsGeneratingTitle = <String>{};

  /// Timeout duration for title generation
  static const Duration _titleGenerationTimeout = Duration(seconds: 30);

  ChatTitleGenerator({
    required OllamaService ollamaService,
    required ModelManager modelManager,
  }) : _ollamaService = ollamaService;

  /// Check if a specific chat is currently generating a title
  bool isChatGeneratingTitle(String chatId) {
    return _chatsGeneratingTitle.contains(chatId);
  }

  /// Check if any chat is currently generating a title
  bool get isGeneratingTitle => _chatsGeneratingTitle.isNotEmpty;

  /// Get list of chat IDs currently generating titles
  Set<String> get chatsGeneratingTitle =>
      Set.unmodifiable(_chatsGeneratingTitle);

  /// Clear title generation state for a specific chat
  void clearTitleGenerationState(String chatId) {
    _chatsGeneratingTitle.remove(chatId);
    AppLogger.info('Cleared title generation state for chat $chatId');
  }

  /// Clear all title generation states
  void clearAllTitleGenerationState() {
    final clearedChats = Set<String>.from(_chatsGeneratingTitle);
    _chatsGeneratingTitle.clear();
    AppLogger.info(
        'Cleared title generation state for ${clearedChats.length} chats');
  }

  /// Generate a title for a chat based on the first message exchange
  Future<String> generateTitle({
    required String chatId,
    required String userMessage,
    required String aiResponse,
    required String modelName,
  }) async {
    if (_chatsGeneratingTitle.contains(chatId)) {
      AppLogger.warning(
          'Title generation already in progress for chat $chatId');
      return '';
    }

    _chatsGeneratingTitle.add(chatId);
    AppLogger.info('Starting title generation for chat $chatId');

    try {
      // Create a prompt for title generation
      final prompt = _createTitleGenerationPrompt(userMessage, aiResponse);

      // Set up a timeout for title generation
      final completer = Completer<String>();

      // Start title generation
      _ollamaService
          .generateResponseWithContext(
        prompt,
        model: modelName,
      )
          .then((response) {
        if (!completer.isCompleted) {
          final title = _extractTitle(response.response);
          completer.complete(title);
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          AppLogger.error('Error generating title', error);
          completer.complete('');
        }
      });

      // Set up timeout
      Timer(_titleGenerationTimeout, () {
        if (!completer.isCompleted) {
          AppLogger.warning('Title generation timed out for chat $chatId');
          completer.complete('');
        }
      });

      // Wait for result or timeout
      final title = await completer.future;

      // Process the title
      final finalTitle = _processTitleResult(title, userMessage);

      AppLogger.info('Generated title for chat $chatId: $finalTitle');
      return finalTitle;
    } catch (e) {
      AppLogger.error('Error generating title for chat $chatId', e);
      return '';
    } finally {
      _chatsGeneratingTitle.remove(chatId);
    }
  }

  /// Create a prompt for title generation
  String _createTitleGenerationPrompt(String userMessage, String aiResponse) {
    return '''
You are a helpful assistant that generates concise, descriptive titles for conversations.
Based on the following conversation, create a short, descriptive title (4-8 words) that captures the main topic.
Do not use quotes in your response. Only respond with the title text.

User: $userMessage
Assistant: $aiResponse

Title:''';
  }

  /// Extract title from the AI response
  String _extractTitle(String response) {
    if (response.isEmpty) return '';

    // Clean up the response
    String title = response.trim();

    // Remove common prefixes
    final prefixes = ['Title:', 'title:', 'TITLE:', '**', '*'];
    for (final prefix in prefixes) {
      if (title.startsWith(prefix)) {
        title = title.substring(prefix.length).trim();
      }
    }

    // Remove quotes if present
    if ((title.startsWith('"') && title.endsWith('"')) ||
        (title.startsWith("'") && title.endsWith("'"))) {
      title = title.substring(1, title.length - 1);
    }

    return title.trim();
  }

  /// Process the title result and apply fallbacks
  String _processTitleResult(String title, String userMessage) {
    if (title.isNotEmpty && title.length <= 100) {
      return title;
    }

    // Fallback: create title from user message
    if (userMessage.isNotEmpty) {
      final words = userMessage.split(' ').take(6).join(' ');
      return words.length > 50 ? '${words.substring(0, 47)}...' : words;
    }

    // Final fallback
    return 'New Chat';
  }
}
