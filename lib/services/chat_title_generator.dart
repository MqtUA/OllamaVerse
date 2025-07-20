import 'dart:async';
import '../services/ollama_service.dart';
import '../services/model_manager.dart';
import '../utils/logger.dart';

/// Service responsible for generating chat titles automatically
///
/// This service improves user experience by creating meaningful titles
/// instead of generic "New Chat" labels, making chat history more navigable
class ChatTitleGenerator {
  final OllamaService _ollamaService;

  /// Tracks which chats are generating titles to prevent duplicate requests
  final Set<String> _chatsGeneratingTitle = <String>{};
  bool _disposed = false;

  /// Timeout prevents hanging requests from blocking the UI indefinitely
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
    if (_disposed) {
      AppLogger.warning(
          'ChatTitleGenerator is disposed, cannot generate title');
      return '';
    }

    if (_chatsGeneratingTitle.contains(chatId)) {
      AppLogger.warning(
          'Title generation already in progress for chat $chatId');
      // Return fallback title instead of empty string
      return _generateFallbackTitle(userMessage);
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
    // Remove thinking content from AI response first
    String cleanedAiResponse = _removeThinkingContent(aiResponse);

    // Truncate user message if too long, preserving the end which often contains the key request
    String truncatedUserMessage = userMessage;
    if (userMessage.length > 600) {
      // Keep the first 300 chars and last 300 chars to preserve context and key request
      final start = userMessage.substring(0, 300);
      final end = userMessage.substring(userMessage.length - 300);
      truncatedUserMessage = '$start...$end';
    }

    return '''
You are a helpful assistant that generates concise, descriptive titles for conversations.
Based on the following conversation, create a short, descriptive title (4-8 words) that captures the main topic.
Do not use quotes in your response. Only respond with the title text.

User: $truncatedUserMessage
Assistant: $cleanedAiResponse

Title:''';
  }

  /// Remove thinking content from AI response
  String _removeThinkingContent(String response) {
    // Remove thinking blocks
    String cleaned = response.replaceAll(RegExp(r'<thinking>.*?</thinking>', dotAll: true), '');
    
    // Clean up extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n').trim();
    
    return cleaned;
  }

  /// Extract title from the AI response
  String _extractTitle(String response) {
    if (response.isEmpty) return '';

    // Clean up the response and remove thinking content
    String title = _removeThinkingContent(response).trim();

    // Remove quotes if present (do this first)
    if ((title.startsWith('"') && title.endsWith('"')) ||
        (title.startsWith("'") && title.endsWith("'"))) {
      title = title.substring(1, title.length - 1).trim();
    }

    // Remove common prefixes (do this after quote removal)
    final prefixes = ['Title:', 'title:', 'TITLE:', '**', '*'];
    for (final prefix in prefixes) {
      if (title.startsWith(prefix)) {
        title = title.substring(prefix.length).trim();
      }
    }

    // Limit to 5 words maximum
    final words = title.split(' ');
    if (words.length > 5) {
      title = words.take(5).join(' ');
    }

    return title.trim();
  }

  /// Process the title result and apply fallbacks
  String _processTitleResult(String title, String userMessage) {
    // Check if title is valid (at least 2 words and reasonable length)
    if (title.isNotEmpty && title.split(' ').length >= 2 && title.length <= 100) {
      return title;
    }

    // Fallback: create title from user message keywords
    return _generateFallbackTitle(userMessage);
  }

  /// Generate fallback title from user message
  String _generateFallbackTitle(String userMessage) {
    if (userMessage.isEmpty) {
      return 'New Chat';
    }

    // Extract keywords from user message
    final keywords = _extractKeywords(userMessage);
    
    if (keywords.isNotEmpty) {
      // Use first few keywords
      final titleWords = keywords.take(3).join(' ');
      return 'Chat about $titleWords';
    }

    // Check for specific query patterns
    final lowerMessage = userMessage.toLowerCase();
    if (lowerMessage.contains('document') || 
        lowerMessage.contains('file') ||
        lowerMessage.contains('analyze') ||
        lowerMessage.contains('what is this') ||
        lowerMessage.contains('what is ai')) {
      return 'Document Analysis Chat';
    }

    // Final fallback
    return 'New Chat';
  }

  /// Extract meaningful keywords from user message
  List<String> _extractKeywords(String message) {
    // Common stop words to filter out (excluding domain-specific terms)
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'must', 'can', 'this', 'that', 'these',
      'those', 'what', 'how', 'when', 'where', 'why', 'who', 'which',
      'please', 'explain', 'their'
    };

    final words = message
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toList();

    return words.take(5).toList();
  }

  /// Dispose resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Clear all title generation states
    clearAllTitleGenerationState();

    AppLogger.info('ChatTitleGenerator disposed');
  }
}
