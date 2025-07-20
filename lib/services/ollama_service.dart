import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/processed_file.dart';
import '../models/ollama_response.dart';
import '../models/message.dart';
import '../services/model_capability_service.dart';
import '../services/ollama_optimization_service.dart';
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

  /// Get optimized options using the optimization service
  Map<String, dynamic> _getOptimizedOptions({
    required String modelName,
    int? contextLength,
    bool isStreaming = false,
    String operationType = 'generate',
  }) {
    return OllamaOptimizationService.getOptimizedOptions(
      modelName: modelName,
      settings: _settings,
      isStreaming: isStreaming,
      operationType: operationType,
      contextLength: contextLength,
    );
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

      // Build the request body based on model capabilities
      final requestBody = <String, dynamic>{
        'model': modelName,
        'stream': false,
      };

      // Add optimized options
      final options = _getOptimizedOptions(
        modelName: modelName,
        contextLength: contextLength,
        isStreaming: false,
        operationType: capabilities.supportsVision ? 'chat' : 'generate',
      );
      if (options.isNotEmpty) {
        requestBody['options'] = options;
      }

      // Handle vision models with images
      final imageFiles = processedFiles
              ?.where((file) => file.type == FileType.image)
              .toList() ??
          [];

      if (capabilities.supportsVision || imageFiles.isNotEmpty) {
        // Use chat endpoint for vision models - build full conversation history
        final messages = <Map<String, dynamic>>[];

        // Add conversation history including system messages and file contexts
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            String role;
            switch (msg.role) {
              case MessageRole.system:
                role = 'system';
                break;
              case MessageRole.user:
                role = 'user';
                break;
              case MessageRole.assistant:
                role = 'assistant';
                break;
            }

            // Append file content to the message content for context
            String messageContentWithFiles = msg.content;
            if (msg.hasTextContent) {
              messageContentWithFiles += '\n\n--- Attached Files Context ---\n';
              for (final file in msg.textFiles) {
                messageContentWithFiles +=
                    'File: ${file.fileName}\n${file.textContent}\n\n';
              }
              messageContentWithFiles += '--- End of Attached Files ---\n';
            }

            final messageMap = <String, dynamic>{
              'role': role,
              'content': messageContentWithFiles,
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

        // The logic for adding the current message and its files is now handled
        // by the loop above, which iterates through the entire conversationHistory.
        // The `prompt` and `processedFiles` parameters are implicitly included
        // in the last message of the `conversationHistory`.
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

        // If we have conversation history, build the prompt from it
        if (conversationHistory != null && conversationHistory.isNotEmpty) {
          for (final msg in conversationHistory) {
            if (msg.role == MessageRole.system) {
              if (capabilities.supportsSystemPrompts) {
                finalPrompt += '${msg.content}\n\n';
              } else {
                finalPrompt +=
                    'Instructions: ${msg.content}\n\nPlease follow the above instructions when responding.\n\n';
              }
            } else {
              finalPrompt += '${msg.role.name.toUpperCase()}: ${msg.content}\n';
              if (msg.hasTextContent) {
                for (final file in msg.textFiles) {
                  finalPrompt +=
                      '--- Start of File: ${file.fileName} ---\n${file.textContent}\n--- End of File: ${file.fileName} ---\n';
                }
              }
              finalPrompt += '\n';
            }
          }

          // For the last user message (current), emphasize it to ensure it doesn't get lost
          if (conversationHistory.isNotEmpty) {
            final lastMessage = conversationHistory.last;
            if (lastMessage.role == MessageRole.user) {
              finalPrompt += '\n=== CURRENT USER REQUEST ===\n';
              finalPrompt += 'Please focus on this specific request:\n';
              finalPrompt += '${lastMessage.content}\n';
              finalPrompt += '=== END CURRENT REQUEST ===\n\n';
            }
          }
        } else {
          // Fallback for single prompts without history
          finalPrompt += prompt;
          if (processedFiles != null && processedFiles.isNotEmpty) {
            finalPrompt += '\n\n';
            for (final file in processedFiles) {
              if (file.hasTextContent) {
                finalPrompt +=
                    '--- Start of File: ${file.fileName} ---\n${file.textContent}\n--- End of File: ${file.fileName} ---\n';
              }
            }

            // Emphasize the user request
            finalPrompt += '\n=== USER REQUEST ===\n';
            finalPrompt +=
                'Please analyze the above file(s) and respond to this request:\n';
            finalPrompt += '$prompt\n';
            finalPrompt += '=== END REQUEST ===\n';
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
    bool Function()? isCancelled,
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

      http.Request request;
      Map<String, dynamic> requestBody;

      if (capabilities.supportsVision || imageFiles.isNotEmpty) {
        // Use chat endpoint for vision models with conversation history
        final messages = <Map<String, dynamic>>[];

        // Add conversation history (excluding system messages initially)
        if (conversationHistory != null) {
          for (final msg in conversationHistory) {
            String role;
            switch (msg.role) {
              case MessageRole.system:
                role = 'system';
                break;
              case MessageRole.user:
                role = 'user';
                break;
              case MessageRole.assistant:
                role = 'assistant';
                break;
            }

            // Append file content to the message content for context
            String messageContentWithFiles = msg.content;
            if (msg.hasTextContent) {
              messageContentWithFiles += '\n\n--- Attached Files Context ---\n';
              for (final file in msg.textFiles) {
                messageContentWithFiles +=
                    'File: ${file.fileName}\n${file.textContent}\n\n';
              }
              messageContentWithFiles += '--- End of Attached Files ---\n';
            }

            final messageMap = <String, dynamic>{
              'role': role,
              'content': messageContentWithFiles,
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

        requestBody = {
          'model': modelName,
          'messages': messages,
          'stream': true,
        };

        // Add optimized streaming options
        final options = _getOptimizedOptions(
          modelName: modelName,
          contextLength: contextLength,
          isStreaming: true,
          operationType: 'chat',
        );
        if (options.isNotEmpty) {
          requestBody['options'] = options;
        }

        request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'));
      } else {
        // Use generate endpoint for text-only models with context
        String finalPrompt = '';

        // If we have conversation history, build the prompt from it
        if (conversationHistory != null && conversationHistory.isNotEmpty) {
          for (final msg in conversationHistory) {
            if (msg.role == MessageRole.system) {
              if (capabilities.supportsSystemPrompts) {
                finalPrompt += '${msg.content}\n\n';
              } else {
                finalPrompt +=
                    'Instructions: ${msg.content}\n\nPlease follow the above instructions when responding.\n\n';
              }
            } else {
              finalPrompt += '${msg.role.name.toUpperCase()}: ${msg.content}\n';
              if (msg.hasTextContent) {
                for (final file in msg.textFiles) {
                  finalPrompt +=
                      '--- Start of File: ${file.fileName} ---\n${file.textContent}\n--- End of File: ${file.fileName} ---\n';
                }
              }
              finalPrompt += '\n';
            }
          }
        } else {
          // Fallback for single prompts without history
          finalPrompt += prompt;
          if (processedFiles != null && processedFiles.isNotEmpty) {
            finalPrompt += '\n\n';
            for (final file in processedFiles) {
              if (file.hasTextContent) {
                finalPrompt +=
                    '--- Start of File: ${file.fileName} ---\n${file.textContent}\n--- End of File: ${file.fileName} ---\n';
              }
            }
          }
        }

        requestBody = {
          'model': modelName,
          'prompt': finalPrompt,
          'stream': true,
        };

        // Add optimized generate options
        final options = _getOptimizedOptions(
          modelName: modelName,
          contextLength: contextLength,
          isStreaming: true,
          operationType: 'generate',
        );
        if (options.isNotEmpty) {
          requestBody['options'] = options;
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
          if (isCancelled?.call() ?? false) {
            AppLogger.info('Stream generation cancelled by user.');
            break;
          }
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
    return OllamaOptimizationService.getPerformanceRecommendations(
      modelName: modelName,
      settings: _settings,
    );
  }

  /// Validate current settings for optimal performance
  bool validateSettingsForModel(String modelName) {
    return OllamaOptimizationService.validateSettings(
      modelName: modelName,
      settings: _settings,
    );
  }

  /// Get recommended context length for a model
  int getRecommendedContextLength(String modelName) {
    return OllamaOptimizationService.getRecommendedContextLength(modelName);
  }

  void dispose() {
    _isDisposed = true;

    _client.close();
  }
}
