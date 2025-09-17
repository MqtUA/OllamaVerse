import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/processed_file.dart';
import '../models/ollama_response.dart';
import '../models/message.dart';
import '../models/chat.dart';
import '../services/model_capability_service.dart';
import '../services/optimized_generation_settings_service.dart';
import '../utils/logger.dart';

/// Custom exception for Ollama API errors
class OllamaApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? originalError;

  OllamaApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => statusCode != null
      ? 'OllamaApiException: $message (Status code: $statusCode)'
      : originalError != null
          ? 'OllamaApiException: $message (Error: $originalError)'
          : 'OllamaApiException: $message';
}

/// Custom exception for connection errors
class OllamaConnectionException implements Exception {
  final String message;
  final Object? originalError;

  OllamaConnectionException(this.message, {this.originalError});

  @override
  String toString() => originalError != null
      ? 'OllamaConnectionException: $message (Error: $originalError)'
      : 'OllamaConnectionException: $message';
}

class OllamaService {
  final http.Client _client;
  final AppSettings _settings;
  final String? _authToken;

  bool _isDisposed = false;

  // Connection timeout for Android devices - optimized for better responsiveness
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 120);

  OllamaService({
    required AppSettings settings,
    String? authToken,
    http.Client? client,
  })  : _settings = settings,
        _authToken = authToken,
        _client = client ?? http.Client();

  String get _baseUrl => _settings.ollamaUrl;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };

    // Add auth token if provided
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  String _mapRoleToApiRole(MessageRole role) {
    switch (role) {
      case MessageRole.system:
        return 'system';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.user:
        return 'user';
    }
  }

  List<Map<String, dynamic>> _buildStructuredChatContent({
    String? content,
    List<ProcessedFile> textFiles = const <ProcessedFile>[],
    List<ProcessedFile> imageFiles = const <ProcessedFile>[],
  }) {
    final segments = <Map<String, dynamic>>[];

    final trimmedContent = content?.trim();
    if (trimmedContent != null && trimmedContent.isNotEmpty) {
      segments.add({'type': 'text', 'text': trimmedContent});
    }

    for (final file in textFiles) {
      final text = file.textContent;
      if (text != null && text.isNotEmpty) {
        segments.add({
          'type': 'text',
          'text':
              '--- Start of File: ${file.fileName} ---\n$text\n--- End of File: ${file.fileName} ---',
        });
      }
    }

    for (final file in imageFiles) {
      final base64 = file.base64Content;
      if (base64 != null && base64.isNotEmpty) {
        segments.add({'type': 'image', 'image': base64});
      }
    }

    return segments;
  }

  String _buildFallbackChatContent({
    String? content,
    List<ProcessedFile> textFiles = const <ProcessedFile>[],
    List<ProcessedFile> imageFiles = const <ProcessedFile>[],
  }) {
    final sections = <String>[];
    final trimmedContent = content?.trim();
    if (trimmedContent != null && trimmedContent.isNotEmpty) {
      sections.add(trimmedContent);
    }

    for (final file in textFiles) {
      final text = file.textContent;
      if (text != null && text.isNotEmpty) {
        sections.add(
            '--- Start of File: ${file.fileName} ---\n$text\n--- End of File: ${file.fileName} ---');
      }
    }

    if (imageFiles.isNotEmpty) {
      sections.add(
          'Attached images: ${imageFiles.map((file) => file.fileName).join(', ')}');
    }

    return sections.join('\n\n').trim();
  }

  Map<String, dynamic> _buildChatMessage({
    required MessageRole role,
    required String content,
    List<ProcessedFile> textFiles = const <ProcessedFile>[],
    List<ProcessedFile> imageFiles = const <ProcessedFile>[],
    required bool allowImages,
  }) {
    final message = <String, dynamic>{
      'role': _mapRoleToApiRole(role),
    };

    if (allowImages) {
      final structuredContent = _buildStructuredChatContent(
        content: content,
        textFiles: textFiles,
        imageFiles: imageFiles,
      );

      if (structuredContent.isEmpty) {
        message['content'] = [
          {
            'type': 'text',
            'text': content.isNotEmpty
                ? content
                : 'Please analyse the provided attachments.',
          }
        ];
      } else {
        message['content'] = structuredContent;
      }
    } else {
      message['content'] = _buildFallbackChatContent(
        content: content,
        textFiles: textFiles,
        imageFiles: imageFiles,
      );
    }

    return message;
  }

  List<Map<String, dynamic>> _buildChatMessages({
    required List<Message>? conversationHistory,
    required String prompt,
    List<ProcessedFile>? processedFiles,
    required bool allowImages,
  }) {
    final messages = <Map<String, dynamic>>[];

    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (final message in conversationHistory) {
        messages.add(
          _buildChatMessage(
            role: message.role,
            content: message.content,
            textFiles: message.textFiles,
            imageFiles: message.imageFiles
                .where((file) =>
                    file.base64Content != null &&
                    file.base64Content!.isNotEmpty)
                .toList(),
            allowImages: allowImages,
          ),
        );
      }
    }

    final includesPrompt = conversationHistory != null &&
        conversationHistory.isNotEmpty &&
        conversationHistory.last.role == MessageRole.user &&
        conversationHistory.last.content == prompt;

    if (!includesPrompt) {
      final files = processedFiles ?? const <ProcessedFile>[];
      final textFiles = files.where((file) => file.hasTextContent).toList();
      final imageFiles = files
          .where((file) =>
              file.type == FileType.image &&
              (file.base64Content?.isNotEmpty ?? false))
          .toList();

      messages.add(
        _buildChatMessage(
          role: MessageRole.user,
          content: prompt,
          textFiles: textFiles,
          imageFiles: imageFiles,
          allowImages: allowImages,
        ),
      );
    }

    return messages;
  }

  String _buildGeneratePrompt({
    required String prompt,
    List<Message>? conversationHistory,
    List<ProcessedFile>? processedFiles,
    required ModelCapabilities capabilities,
  }) {
    final buffer = StringBuffer();

    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (final message in conversationHistory) {
        if (message.role == MessageRole.system) {
          if (capabilities.supportsSystemPrompts) {
            buffer.writeln(message.content);
            buffer.writeln();
          } else {
            buffer.writeln('Instructions: ${message.content}');
            buffer.writeln(
                'Please follow the above instructions when responding.');
            buffer.writeln();
          }
        } else {
          buffer.writeln(
              '${message.role.name.toUpperCase()}: ${message.content}');
          if (message.hasTextContent) {
            for (final file in message.textFiles) {
              buffer.writeln('--- Start of File: ${file.fileName} ---');
              if (file.textContent != null && file.textContent!.isNotEmpty) {
                buffer.writeln(file.textContent);
              }
              buffer.writeln('--- End of File: ${file.fileName} ---');
            }
          }
          buffer.writeln();
        }
      }

      final lastMessage = conversationHistory.last;
      if (lastMessage.role == MessageRole.user) {
        buffer.writeln('=== CURRENT USER REQUEST ===');
        buffer.writeln('Please focus on this specific request:');
        buffer.writeln(lastMessage.content);
        buffer.writeln('=== END CURRENT REQUEST ===');
        buffer.writeln();
      }
    } else {
      buffer.write(prompt);
      if (processedFiles != null && processedFiles.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
        for (final file in processedFiles) {
          if (file.hasTextContent) {
            buffer.writeln('--- Start of File: ${file.fileName} ---');
            if (file.textContent != null && file.textContent!.isNotEmpty) {
              buffer.writeln(file.textContent);
            }
            buffer.writeln('--- End of File: ${file.fileName} ---');
          }
        }
        buffer.writeln();
        buffer.writeln('=== USER REQUEST ===');
        buffer.writeln(
            'Please analyze the above file(s) and respond to this request:');
        buffer.writeln(prompt);
        buffer.writeln('=== END REQUEST ===');
      }
    }

    return buffer.toString().trimRight();
  }

  Future<T> _makeRequest<T>(
    Future<T> Function() request, {
    Duration? timeout,
  }) async {
    try {
      return await request().timeout(
        timeout ?? _connectionTimeout,
        onTimeout: () {
          throw OllamaConnectionException(
            'Connection timed out. Please check your network connection and server settings.',
          );
        },
      );
    } on TimeoutException {
      throw OllamaConnectionException(
        'Request timed out. The server may be unreachable or overloaded.',
      );
    } on http.ClientException catch (e) {
      throw OllamaConnectionException(
        'Network error occurred',
        originalError: e,
      );
    } catch (e) {
      if (e is OllamaConnectionException || e is OllamaApiException) {
        rethrow;
      }
      throw OllamaConnectionException(
        'Failed to connect to Ollama server',
        originalError: e,
      );
    }
  }

  Future<List<String>> getModels() async {
    return _makeRequest(() async {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['models'] != null) {
            return (data['models'] as List)
                .map((model) => model['name'] as String)
                .toList();
          } else {
            return [];
          }
        } catch (e) {
          throw OllamaApiException(
            'Invalid JSON response from models endpoint',
            originalError: e,
          );
        }
      } else {
        throw OllamaApiException(
          'Failed to load models',
          statusCode: response.statusCode,
        );
      }
    });
  }

  Future<bool> testConnection() async {
    try {
      return await _makeRequest(() async {
        final response = await _client.get(
          Uri.parse('$_baseUrl/api/tags'),
          headers: _headers,
        );
        return response.statusCode == 200;
      });
    } catch (e) {
      AppLogger.error('Error testing connection', e);
      return false;
    }
  }

  Future<void> refreshModels() async {
    try {
      await getModels();
    } catch (e) {
      AppLogger.error('Error refreshing models', e);
      rethrow;
    }
  }

  /// Generate response with context support (new implementation)
  Future<OllamaResponse> generateResponseWithContext(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    List<Message>? conversationHistory,
    int? contextLength,
    Chat? chat,
    bool Function()? isCancelled,
  }) async {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }
    if (isCancelled?.call() ?? false) {
      throw OllamaApiException('Request cancelled by user');
    }

    return _makeRequest(() async {
      final modelName = model ?? 'llama2';
      final capabilities =
          ModelCapabilityService.getModelCapabilities(modelName);

      final requestBody = <String, dynamic>{
        'model': modelName,
        'stream': false,
      };

      try {
        final settingsService = OptimizedGenerationSettingsService();
        final generationSettings = settingsService.getEffectiveSettings(
          chat: chat,
          globalSettings: _settings,
        );

        final validatedSettings =
            settingsService.validateSettings(generationSettings)
                ? generationSettings
                : settingsService.createSafeSettings(generationSettings);

        final options = settingsService.buildOllamaOptions(
          settings: validatedSettings,
          contextLength: contextLength,
          isStreaming: false,
        );

        if (options.isNotEmpty) {
          requestBody['options'] = options;
        }
      } catch (e) {
        AppLogger.error(
            'Error applying generation settings, using defaults', e);
      }

      final hasImageAttachments =
          processedFiles?.any((file) => file.type == FileType.image) ?? false;
      final useChatEndpoint =
          capabilities.supportsVision || hasImageAttachments;

      if (useChatEndpoint) {
        requestBody['messages'] = _buildChatMessages(
          conversationHistory: conversationHistory,
          prompt: prompt,
          processedFiles: processedFiles,
          allowImages: true,
        );

        final response = await _client.post(
          Uri.parse('$_baseUrl/api/chat'),
          headers: _headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final message = data['message'] as Map<String, dynamic>?;
            if (message == null || message['content'] == null) {
              throw OllamaApiException(
                  'Invalid response format: missing message content');
            }
            return OllamaResponse.fromJson(data);
          } catch (e) {
            AppLogger.error('Raw response body: ${response.body}');
            throw OllamaApiException(
              'Invalid JSON response from chat endpoint',
              originalError: e,
            );
          }
        } else {
          final errorBody = response.body.trim();
          final message = errorBody.isNotEmpty
              ? 'Failed to generate response with vision: $errorBody'
              : 'Failed to generate response with vision';
          throw OllamaApiException(
            message,
            statusCode: response.statusCode,
          );
        }
      } else {
        final promptBody = _buildGeneratePrompt(
          prompt: prompt,
          conversationHistory: conversationHistory,
          processedFiles: processedFiles,
          capabilities: capabilities,
        );
        requestBody['prompt'] = promptBody;

        if (context != null && context.isNotEmpty) {
          requestBody['context'] = context;
        }

        final response = await _client.post(
          Uri.parse('$_baseUrl/api/generate'),
          headers: _headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return OllamaResponse.fromJson(data);
          } catch (e) {
            if (e is OllamaApiException) rethrow;
            AppLogger.error('Raw response body: ${response.body}');
            throw OllamaApiException(
              'Invalid JSON response from generate endpoint',
              originalError: e,
            );
          }
        } else {
          final errorBody = response.body.trim();
          final message = errorBody.isNotEmpty
              ? 'Failed to generate response: $errorBody'
              : 'Failed to generate response';
          throw OllamaApiException(
            message,
            statusCode: response.statusCode,
          );
        }
      }
    }, timeout: _receiveTimeout);
  }

  /// Generate response with file content support (backwards compatibility)
  Future<String> generateResponseWithFiles(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
  }) async {
    final response = await generateResponseWithContext(
      prompt,
      model: model,
      processedFiles: processedFiles,
      context: context,
    );
    return response.response;
  }

  /// Generate streaming response with context support (new implementation)
  Stream<OllamaStreamResponse> generateStreamingResponseWithContext(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    List<Message>? conversationHistory,
    int? contextLength,
    Chat? chat,
    bool Function()? isCancelled,
  }) async* {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }

    try {
      final modelName = model ?? 'llama2';
      final capabilities =
          ModelCapabilityService.getModelCapabilities(modelName);

      final requestBody = <String, dynamic>{
        'model': modelName,
        'stream': true,
      };

      try {
        final settingsService = OptimizedGenerationSettingsService();
        final generationSettings = settingsService.getEffectiveSettings(
          chat: chat,
          globalSettings: _settings,
        );

        final options = settingsService.buildOllamaOptions(
          settings: generationSettings,
          contextLength: contextLength,
          isStreaming: true,
        );

        if (options.isNotEmpty) {
          requestBody['options'] = options;
        }
      } catch (e) {
        AppLogger.error(
            'Error applying generation settings for streaming, using defaults',
            e);
      }

      final hasImageAttachments =
          processedFiles?.any((file) => file.type == FileType.image) ?? false;
      final useChatEndpoint =
          capabilities.supportsVision || hasImageAttachments;

      http.Request request;

      if (useChatEndpoint) {
        requestBody['messages'] = _buildChatMessages(
          conversationHistory: conversationHistory,
          prompt: prompt,
          processedFiles: processedFiles,
          allowImages: true,
        );
        request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'));
      } else {
        final promptBody = _buildGeneratePrompt(
          prompt: prompt,
          conversationHistory: conversationHistory,
          processedFiles: processedFiles,
          capabilities: capabilities,
        );
        requestBody['prompt'] = promptBody;

        if (context != null && context.isNotEmpty) {
          requestBody['context'] = context;
        }

        request = http.Request('POST', Uri.parse('$_baseUrl/api/generate'));
      }

      request.headers.addAll(_headers);
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _client.send(request);

      if (streamedResponse.statusCode == 200) {
        await for (String line in streamedResponse.stream
            .transform(const Utf8Decoder())
            .transform(const LineSplitter())) {
          if (isCancelled?.call() ?? false) {
            AppLogger.info('Stream generation cancelled by user.');
            break;
          }
          final trimmedLine = line.trim();
          if (trimmedLine.isNotEmpty) {
            try {
              final data = jsonDecode(trimmedLine) as Map<String, dynamic>;
              final streamResponse = OllamaStreamResponse.fromJson(data);
              yield streamResponse;

              if (streamResponse.done) {
                break;
              }
            } catch (e) {
              AppLogger.error('Error parsing streaming response', e);
            }
          }
        }
      } else {
        String? errorBody;
        try {
          errorBody = await streamedResponse.stream
              .transform(const Utf8Decoder())
              .join();
        } catch (e) {
          AppLogger.warning('Failed to read streaming error body: $e');
        }

        final message = errorBody != null && errorBody.trim().isNotEmpty
            ? 'Failed to start streaming response: ${errorBody.trim()}'
            : 'Failed to start streaming response';
        throw OllamaApiException(message,
            statusCode: streamedResponse.statusCode);
      }
    } catch (e) {
      AppLogger.error('Error in streaming response', e);
      rethrow;
    }
  }

  /// Generate streaming response with file content support (backwards compatibility)
  Stream<String> generateStreamingResponseWithFiles(
    String prompt, {
    String? model,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
  }) async* {
    await for (final streamResponse in generateStreamingResponseWithContext(
      prompt,
      model: model,
      processedFiles: processedFiles,
      context: context,
    )) {
      if (streamResponse.response.isNotEmpty) {
        yield streamResponse.response;
      }
    }
  }

  /// Check if a model supports system prompts and provide feedback
  Future<Map<String, dynamic>> validateSystemPromptSupport(
      String modelName) async {
    try {
      final capabilities =
          ModelCapabilityService.getModelCapabilities(modelName);

      return {
        'supported': capabilities.supportsSystemPrompts,
        'modelName': modelName,
        'fallbackMethod': capabilities.supportsSystemPrompts
            ? 'native'
            : 'instruction-prepend',
        'recommendation': capabilities.supportsSystemPrompts
            ? 'This model has excellent system prompt support. System messages will be sent natively.'
            : 'This model has limited system prompt support. System prompts will be converted to instructions for better compatibility.',
        'capabilities': {
          'vision': capabilities.supportsVision,
          'code': capabilities.supportsCode,
          'multimodal': capabilities.supportsMultimodal,
          'systemPrompts': capabilities.supportsSystemPrompts,
        }
      };
    } catch (e) {
      AppLogger.error(
          'Error validating system prompt support for $modelName', e);
      return {
        'supported':
            true, // Default to supported to avoid breaking functionality
        'modelName': modelName,
        'fallbackMethod': 'native',
        'recommendation':
            'Unable to determine system prompt support. Assuming native support.',
        'error': e.toString(),
      };
    }
  }

  /// Get system prompt handling strategy for current model
  String getSystemPromptStrategy(String modelName) {
    final capabilities = ModelCapabilityService.getModelCapabilities(modelName);
    return capabilities.supportsSystemPrompts
        ? 'native'
        : 'instruction-prepend';
  }

  /// Get performance recommendations for current settings and model
  Map<String, dynamic> getPerformanceRecommendations(String modelName) {
    final settingsService = OptimizedGenerationSettingsService();
    final generationSettings = _settings.generationSettings;
    final recommendations = <String, dynamic>{
      'warnings': settingsService.getValidationErrors(generationSettings),
      'suggestions': settingsService.getRecommendations(generationSettings),
      'optimizations': <String, dynamic>{},
    };

    // Add model-specific recommendations
    final capabilities = ModelCapabilityService.getModelCapabilities(modelName);
    if (capabilities.supportsVision) {
      (recommendations['suggestions'] as List<String>).add(
          'Vision models work best with clear, high-resolution images and specific questions about visual content.');
    }

    if (capabilities.supportsCode) {
      (recommendations['suggestions'] as List<String>).add(
          'For code generation, consider using a system prompt that specifies the programming language and coding style.');
    }

    return recommendations;
  }

  /// Validate current settings for optimal performance
  bool validateSettingsForModel(String modelName) {
    final settingsService = OptimizedGenerationSettingsService();
    return settingsService.validateSettings(_settings.generationSettings);
  }

  /// Get recommended context length for a model
  int getRecommendedContextLength(String modelName) {
    final capabilities = ModelCapabilityService.getModelCapabilities(modelName);

    if (capabilities.supportsCode) {
      return 16384; // Code models benefit from larger contexts
    } else if (capabilities.supportsVision) {
      return 4096; // Vision models need moderate context for images
    } else if (modelName.toLowerCase().contains('llama3') ||
        modelName.toLowerCase().contains('qwen')) {
      return 8192; // Newer models support larger contexts
    }

    return 4096; // Safe default
  }

  void dispose() {
    _isDisposed = true;

    _client.close();
  }
}
