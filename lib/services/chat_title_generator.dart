import 'dart:async';
import '../services/ollama_service.dart';
import '../services/thinking_model_detection_service.dart';
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
  }) : _ollamaService = ollamaService;

  /// Check if a specific chat is currently generating a title
  bool isChatGeneratingTitle(String chatId) {
    return _chatsGeneratingTitle.contains(chatId);
  }

  /// Check if any chat is currently generating a title
  bool get isGeneratingTitle => _chatsGeneratingTitle.isNotEmpty;

  /// Get list of chat IDs currently generating titles
  Set<String> get chatsGeneratingTitle => Set.unmodifiable(_chatsGeneratingTitle);

  /// Generate a chat title based on user message and AI response
  /// Returns the generated title or a fallback title if generation fails
  Future<String> generateTitle({
    required String chatId,
    required String userMessage,
    required String aiResponse,
    required String modelName,
  }) async {
    // Check if already generating title for this chat
    if (_chatsGeneratingTitle.contains(chatId)) {
      AppLogger.warning('Title generation already in progress for chat: $chatId');
      return _getFallbackTitle(userMessage);
    }

    // Add to generating set
    _chatsGeneratingTitle.add(chatId);
    
    try {
      AppLogger.info('Auto-generating title for chat: $chatId');
      
      // Generate title with timeout protection
      final newTitle = await _generateChatTitle(
        userMessage, 
        aiResponse, 
        modelName
      ).timeout(
        _titleGenerationTimeout,
        onTimeout: () {
          AppLogger.warning('Title generation timed out, using fallback');
          return _getFallbackTitle(userMessage);
        },
      );
      
      AppLogger.info('Generated title for chat $chatId: $newTitle');
      return newTitle;
      
    } catch (e) {
      AppLogger.error('Error generating title for chat $chatId', e);
      return _getFallbackTitle(userMessage);
    } finally {
      // Always remove from generating set
      _chatsGeneratingTitle.remove(chatId);
    }
  }

  /// Internal method to generate chat title using Ollama
  Future<String> _generateChatTitle(
    String userMessage, 
    String aiResponse, 
    String modelName
  ) async {
    try {
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

      // Truncate user message more aggressively for large files (e.g., PDFs)
      String truncatedUserMessage = _truncateUserMessage(userMessage);

      // Create prompt based on response usefulness
      String prompt = _createTitlePrompt(
        truncatedUserMessage, 
        processedAiResponse, 
        isAiResponseUseful
      );

      final titleResponse = await _ollamaService
          .generateResponseWithFiles(prompt, model: modelName);

      // Clean up the response
      String cleanTitle = _cleanTitleResponse(titleResponse);

      // Enhanced fallback logic
      if (_isTitleInvalid(cleanTitle)) {
        return _getFallbackTitle(truncatedUserMessage);
      }

      return cleanTitle;
    } catch (e) {
      AppLogger.error('Error generating chat title', e);
      return _getFallbackTitle(userMessage);
    }
  }

  /// Truncate user message for title generation
  String _truncateUserMessage(String userMessage) {
    if (userMessage.length <= 150) {
      return userMessage;
    }

    // For large documents, extract just the key request part
    // Look for common request patterns at the end of long messages
    final requestPatterns = [
      RegExp(
          r'(please|can you|could you|summarize|summary|analyze|analysis|explain|tell me)[^.!?]*[.!?]?',
          caseSensitive: false),
      RegExp(r'(what is|what are|how does|how do)[^.!?]*[.!?]?',
          caseSensitive: false),
    ];

    String? extractedRequest;
    for (final pattern in requestPatterns) {
      final match = pattern.firstMatch(userMessage);
      if (match != null && match.group(0)!.length <= 150) {
        extractedRequest = match.group(0)!.trim();
        break;
      }
    }

    if (extractedRequest != null) {
      return extractedRequest;
    }

    // Fall back to simple truncation
    final sentences = userMessage.split(RegExp(r'[.!?]+'));
    if (sentences.isNotEmpty && sentences.last.trim().length <= 150) {
      return sentences.last.trim();
    }

    return '${userMessage.substring(userMessage.length - 150)}...';
  }

  /// Create title generation prompt
  String _createTitlePrompt(
    String truncatedUserMessage, 
    String processedAiResponse, 
    bool isAiResponseUseful
  ) {
    if (isAiResponseUseful && processedAiResponse.length < 200) {
      // Use both user and AI content for title (only for short responses)
      return '''Create a 3-5 word title for this conversation, reply only with a single title, no other text:

User: $truncatedUserMessage
AI: ${processedAiResponse.substring(0, 200.clamp(0, processedAiResponse.length))}

Title:''';
    } else {
      // Focus on user request for large documents or poor responses
      return '''Create a 3-5 word title for this request, reply only with a single title, no other text:

"$truncatedUserMessage"

Title:''';
    }
  }

  /// Clean up title response from Ollama
  String _cleanTitleResponse(String titleResponse) {
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

    return cleanTitle;
  }

  /// Check if generated title is invalid
  bool _isTitleInvalid(String title) {
    final words = title.split(' ').where((w) => w.isNotEmpty).toList();
    return title.isEmpty || title.length < 3 || words.length < 2;
  }

  /// Generate fallback title based on user message
  String _getFallbackTitle(String userMessage) {
    // Extract key words from user message for fallback
    final userWords = userMessage
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
    }
    
    return 'Document Analysis Chat';
  }

  /// Clear title generation state for a specific chat
  void clearTitleGenerationState(String chatId) {
    _chatsGeneratingTitle.remove(chatId);
  }

  /// Clear all title generation state
  void clearAllTitleGenerationState() {
    _chatsGeneratingTitle.clear();
  }
}