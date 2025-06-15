import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/processed_file.dart';
import '../models/ollama_response.dart';
import '../models/message.dart';
import '../services/model_capability_service.dart';
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
  StreamController<String>? _streamController;
  bool _isDisposed = false;

  // Connection timeout for Android devices
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 60);

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
      'Content-Type': 'application/json',
    };

    // Add auth token if provided
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
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
  }) async {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }

    return _makeRequest(() async {
      final modelName = model ?? 'llama2';
      final capabilities =
          ModelCapabilityService.getModelCapabilities(modelName);

      // Build the request body based on model capabilities
      final requestBody = <String, dynamic>{
        'model': modelName,
        'stream': false,
      };

      // Add context length if specified
      if (contextLength != null && contextLength > 0) {
        requestBody['options'] = {
          'num_ctx': contextLength,
        };
      }

      // Handle vision models with images
      final imageFiles = processedFiles
              ?.where((file) => file.type == FileType.image)
              .toList() ??
          [];
      final textFiles = processedFiles
              ?.where((file) => file.type != FileType.image)
              .toList() ??
          [];

      if (capabilities.supportsVision || imageFiles.isNotEmpty) {
        // Use chat endpoint for vision models - build full conversation history
        final messages = <Map<String, dynamic>>[];

        // Add conversation history including system messages
        if (conversationHistory != null) {
          int systemMessageCount = 0;
          for (final msg in conversationHistory) {
            String role;
            switch (msg.role) {
              case MessageRole.system:
                role = 'system';
                systemMessageCount++;
                break;
              case MessageRole.user:
                role = 'user';
                break;
              case MessageRole.assistant:
                role = 'assistant';
                break;
            }

            final messageMap = <String, dynamic>{
              'role': role,
              'content': msg.content,
            };

            // Add images if this was a user message with images
            if (msg.hasImages && msg.role == MessageRole.user) {
              final images =
                  msg.imageFiles.map((f) => f.base64Content!).toList();
              if (images.isNotEmpty) {
                messageMap['images'] = images;
              }
            }
            messages.add(messageMap);
          }

          if (systemMessageCount > 0) {
            AppLogger.info(
                'Chat endpoint: Including $systemMessageCount system message(s) in conversation');
          }
        }

        // Handle system prompts based on model capabilities
        String systemPromptContent = '';
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            if (msg.role == MessageRole.system) {
              systemPromptContent = msg.content;
              break;
            }
          }
        }

        // Build current message content with text files
        String content = prompt;
        if (textFiles.isNotEmpty) {
          content += '\n\n';
          for (final file in textFiles) {
            if (file.hasTextContent) {
              content += 'File: ${file.fileName}\n${file.textContent}\n\n';
            }
          }
        }

        // Add system prompt handling based on model capabilities
        if (systemPromptContent.isNotEmpty) {
          if (capabilities.supportsSystemPrompts) {
            // Add system message at the beginning for models that support it
            messages.insert(0, {
              'role': 'system',
              'content': systemPromptContent,
            });
            AppLogger.info(
                'Chat endpoint (non-streaming): Including system message (${systemPromptContent.length} chars) - Model supports system prompts');
          } else {
            // For models with limited system prompt support, prepend to user message
            content =
                'Instructions: $systemPromptContent\n\nPlease follow the above instructions when responding.\n\n$content';
            AppLogger.info(
                'Chat endpoint (non-streaming): Converting system prompt to instruction (${systemPromptContent.length} chars) - Model has limited system prompt support');
          }
        }

        final currentMessage = <String, dynamic>{
          'role': 'user',
          'content': content,
        };

        // Add images to the current message
        if (imageFiles.isNotEmpty) {
          final imageList = imageFiles.map((f) => f.base64Content!).toList();
          currentMessage['images'] = imageList;
        }

        messages.add(currentMessage);
        requestBody['messages'] = messages;

        final response = await _client.post(
          Uri.parse('$_baseUrl/api/chat'),
          headers: _headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            if (data['message'] != null && data['message']['content'] != null) {
              return OllamaResponse(
                response: data['message']['content'] as String,
                context:
                    null, // Chat API doesn't return context, but maintains it internally
              );
            } else {
              throw OllamaApiException(
                  'Invalid response format: missing message content');
            }
          } catch (e) {
            AppLogger.error('Raw response body: ${response.body}');
            throw OllamaApiException('Invalid JSON response from chat endpoint',
                originalError: e);
          }
        } else {
          throw OllamaApiException('Failed to generate response with vision',
              statusCode: response.statusCode);
        }
      } else {
        // Use generate endpoint for text-only models with context
        String finalPrompt = '';

        // Add system prompt first if available and supported by the model
        String systemPrompt = '';
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            if (msg.role == MessageRole.system) {
              systemPrompt = msg.content;

              // Check if model supports system prompts
              if (capabilities.supportsSystemPrompts) {
                finalPrompt += '${msg.content}\n\n';
                AppLogger.info(
                    'Generate endpoint (streaming): Including system prompt (${systemPrompt.length} chars) - Model supports system prompts');
              } else {
                // For models that don't support system prompts, prepend as instruction
                finalPrompt +=
                    'Instructions: ${msg.content}\n\nPlease follow the above instructions when responding.\n\n';
                AppLogger.info(
                    'Generate endpoint (streaming): Converting system prompt to instruction (${systemPrompt.length} chars) - Model has limited system prompt support');
              }
              break; // Only use the first system message
            }
          }
        }

        // Add the current user prompt
        finalPrompt += prompt;

        // Include text file content in the prompt
        if (processedFiles != null && processedFiles.isNotEmpty) {
          finalPrompt += '\n\n';
          for (final file in processedFiles) {
            if (file.hasTextContent) {
              finalPrompt += 'File: ${file.fileName}\n${file.textContent}\n\n';
            }
          }
        }

        requestBody['prompt'] = finalPrompt;

        // Add context if available for conversation memory
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
            final data = jsonDecode(response.body);
            return OllamaResponse.fromJson(data);
          } catch (e) {
            if (e is OllamaApiException) rethrow;
            AppLogger.error('Raw response body: ${response.body}');
            throw OllamaApiException(
                'Invalid JSON response from generate endpoint',
                originalError: e);
          }
        } else {
          throw OllamaApiException('Failed to generate response',
              statusCode: response.statusCode);
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
  }) async* {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }

    try {
      final modelName = model ?? 'llama2';
      final capabilities =
          ModelCapabilityService.getModelCapabilities(modelName);

      // Handle vision models with images
      final imageFiles = processedFiles
              ?.where((file) => file.type == FileType.image)
              .toList() ??
          [];
      final textFiles = processedFiles
              ?.where((file) => file.type != FileType.image)
              .toList() ??
          [];

      http.Request request;
      Map<String, dynamic> requestBody;

      if (capabilities.supportsVision || imageFiles.isNotEmpty) {
        // Use chat endpoint for vision models with conversation history
        final messages = <Map<String, dynamic>>[];

        // Add conversation history (excluding system messages initially)
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            if (msg.role != MessageRole.system) {
              String role;
              switch (msg.role) {
                case MessageRole.user:
                  role = 'user';
                  break;
                case MessageRole.assistant:
                  role = 'assistant';
                  break;
                case MessageRole.system:
                  role =
                      'system'; // This won't be reached due to the if condition
                  break;
              }

              final messageMap = <String, dynamic>{
                'role': role,
                'content': msg.content,
              };

              // Add images if this was a user message with images
              if (msg.hasImages && msg.role == MessageRole.user) {
                final images =
                    msg.imageFiles.map((f) => f.base64Content!).toList();
                if (images.isNotEmpty) {
                  messageMap['images'] = images;
                }
              }
              messages.add(messageMap);
            }
          }
        }

        // Handle system prompts based on model capabilities
        String systemPromptContent = '';
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            if (msg.role == MessageRole.system) {
              systemPromptContent = msg.content;
              break;
            }
          }
        }

        String content = prompt;
        if (textFiles.isNotEmpty) {
          content += '\n\n';
          for (final file in textFiles) {
            if (file.hasTextContent) {
              content += 'File: ${file.fileName}\n${file.textContent}\n\n';
            }
          }
        }

        // Add system prompt handling based on model capabilities
        if (systemPromptContent.isNotEmpty) {
          if (capabilities.supportsSystemPrompts) {
            // Add system message at the beginning for models that support it
            messages.insert(0, {
              'role': 'system',
              'content': systemPromptContent,
            });
            AppLogger.info(
                'Chat endpoint (streaming): Including system message (${systemPromptContent.length} chars) - Model supports system prompts');
          } else {
            // For models with limited system prompt support, prepend to user message
            content =
                'Instructions: $systemPromptContent\n\nPlease follow the above instructions when responding.\n\n$content';
            AppLogger.info(
                'Chat endpoint (streaming): Converting system prompt to instruction (${systemPromptContent.length} chars) - Model has limited system prompt support');
          }
        }

        final currentMessage = <String, dynamic>{
          'role': 'user',
          'content': content,
        };

        // Add images to the current message
        if (imageFiles.isNotEmpty) {
          final imageList = imageFiles.map((f) => f.base64Content!).toList();
          currentMessage['images'] = imageList;
        }

        messages.add(currentMessage);

        requestBody = {
          'model': modelName,
          'messages': messages,
          'stream': true,
        };

        // Add context length if specified
        if (contextLength != null && contextLength > 0) {
          requestBody['options'] = {
            'num_ctx': contextLength,
          };
        }

        request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'));
      } else {
        // Use generate endpoint for text-only models with context
        String finalPrompt = '';

        // Add system prompt first if available and supported by the model
        String systemPrompt = '';
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            if (msg.role == MessageRole.system) {
              systemPrompt = msg.content;

              // Check if model supports system prompts
              if (capabilities.supportsSystemPrompts) {
                finalPrompt += '${msg.content}\n\n';
                AppLogger.info(
                    'Generate endpoint (streaming): Including system prompt (${systemPrompt.length} chars) - Model supports system prompts');
              } else {
                // For models that don't support system prompts, prepend as instruction
                finalPrompt +=
                    'Instructions: ${msg.content}\n\nPlease follow the above instructions when responding.\n\n';
                AppLogger.info(
                    'Generate endpoint (streaming): Converting system prompt to instruction (${systemPrompt.length} chars) - Model has limited system prompt support');
              }
              break; // Only use the first system message
            }
          }
        }

        // Add the current user prompt
        finalPrompt += prompt;

        // Include text file content in the prompt
        if (processedFiles != null && processedFiles.isNotEmpty) {
          finalPrompt += '\n\n';
          for (final file in processedFiles) {
            if (file.hasTextContent) {
              finalPrompt += 'File: ${file.fileName}\n${file.textContent}\n\n';
            }
          }
        }

        requestBody = {
          'model': modelName,
          'prompt': finalPrompt,
          'stream': true,
        };

        // Add context length if specified
        if (contextLength != null && contextLength > 0) {
          requestBody['options'] = {
            'num_ctx': contextLength,
          };
        }

        // Add context if available for conversation memory
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
          line = line.trim();
          if (line.isNotEmpty) {
            try {
              final data = jsonDecode(line);
              final streamResponse = OllamaStreamResponse.fromJson(data);
              yield streamResponse;

              // Break if done
              if (streamResponse.done) {
                break;
              }
            } catch (e) {
              AppLogger.error('Error parsing streaming response', e);
            }
          }
        }
      } else {
        throw OllamaApiException('Failed to start streaming response',
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

  /// Legacy method for backward compatibility - delegates to the file-enabled version
  @Deprecated('Use generateResponseWithFiles instead for better functionality')
  Future<String> generateResponse(
    String prompt, {
    String? model,
    List<int>? context,
  }) async {
    return generateResponseWithFiles(
      prompt,
      model: model,
      context: context,
      processedFiles: null,
    );
  }

  /// Legacy method for backward compatibility - delegates to the file-enabled version
  @Deprecated(
      'Use generateStreamingResponseWithFiles instead for better functionality')
  Stream<String> generateStreamingResponse(
    String prompt, {
    String? model,
    List<int>? context,
  }) async* {
    yield* generateStreamingResponseWithFiles(
      prompt,
      model: model,
      context: context,
      processedFiles: null,
    );
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

  void dispose() {
    _isDisposed = true;
    _streamController?.close();
    _client.close();
  }
}
