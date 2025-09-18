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
import '../services/error_reporting_service.dart';
import '../utils/logger.dart';

/// Custom exception for Ollama API errors with enhanced error details
class OllamaApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? originalError;
  final String? requestUrl;
  final Map<String, dynamic>? requestBody;
  final String? responseBody;
  final DateTime timestamp;

  OllamaApiException(
    this.message, {
    this.statusCode,
    this.originalError,
    this.requestUrl,
    this.requestBody,
    this.responseBody,
  }) : timestamp = DateTime.now();

  /// Get user-friendly error message based on status code and context
  String get userFriendlyMessage {
    if (statusCode != null) {
      switch (statusCode!) {
        case 400:
          return 'Invalid request format. Please check your input and try again.';
        case 401:
          return 'Authentication failed. Please check your API credentials.';
        case 403:
          return 'Access denied. You may not have permission to use this model.';
        case 404:
          return 'Model not found. Please select a different model or check if it\'s installed.';
        case 408:
          return 'Request timeout. The server took too long to respond.';
        case 413:
          return 'Request too large. Try reducing the size of your input or attachments.';
        case 429:
          return 'Too many requests. Please wait a moment before trying again.';
        case 500:
          return 'Server error. The Ollama service encountered an internal problem.';
        case 502:
          return 'Bad gateway. The Ollama service may be temporarily unavailable.';
        case 503:
          return 'Service unavailable. The Ollama service is temporarily down.';
        case 504:
          return 'Gateway timeout. The Ollama service is taking too long to respond.';
        default:
          return statusCode! >= 500
              ? 'Server error occurred. Please try again later.'
              : 'Request failed. Please check your input and try again.';
      }
    }
    return message;
  }

  /// Get error category for handling logic
  String get errorCategory {
    if (statusCode != null) {
      if (statusCode! >= 500) return 'server_error';
      if (statusCode! >= 400) return 'client_error';
    }
    return 'api_error';
  }

  /// Check if this error is retryable
  bool get isRetryable {
    if (statusCode != null) {
      // Retry on server errors (5xx) and rate limiting (429)
      return statusCode! >= 500 || statusCode! == 429 || statusCode! == 408;
    }
    // API exceptions without status codes are generally retryable (network issues, etc.)
    return true;
  }

  @override
  String toString() {
    final buffer = StringBuffer('OllamaApiException: $message');
    if (statusCode != null) buffer.write(' (Status: $statusCode)');
    if (requestUrl != null) buffer.write(' [URL: $requestUrl]');
    if (originalError != null) buffer.write(' [Cause: $originalError]');
    return buffer.toString();
  }

  /// Get detailed error information for logging
  Map<String, dynamic> toLogMap() {
    return {
      'message': message,
      'statusCode': statusCode,
      'requestUrl': requestUrl,
      'requestBodySize': requestBody?.toString().length,
      'responseBodySize': responseBody?.length,
      'timestamp': timestamp.toIso8601String(),
      'errorCategory': errorCategory,
      'isRetryable': isRetryable,
      'originalError': originalError?.toString(),
    };
  }
}

/// Custom exception for connection errors with enhanced diagnostics
class OllamaConnectionException implements Exception {
  final String message;
  final Object? originalError;
  final String? serverUrl;
  final Duration? timeout;
  final DateTime timestamp;

  OllamaConnectionException(
    this.message, {
    this.originalError,
    this.serverUrl,
    this.timeout,
  }) : timestamp = DateTime.now();

  /// Get user-friendly error message
  String get userFriendlyMessage {
    if (originalError != null) {
      final errorStr = originalError.toString().toLowerCase();
      if (errorStr.contains('connection refused')) {
        return 'Cannot connect to Ollama server. Please ensure Ollama is running and accessible.';
      } else if (errorStr.contains('timeout')) {
        return 'Connection timed out. Please check your network connection and server status.';
      } else if (errorStr.contains('host lookup failed') || errorStr.contains('name resolution')) {
        return 'Cannot resolve server address. Please check your server URL settings.';
      } else if (errorStr.contains('network unreachable')) {
        return 'Network unreachable. Please check your internet connection.';
      }
    }
    return message;
  }

  /// Get connection error category
  String get errorCategory {
    if (originalError != null) {
      final errorStr = originalError.toString().toLowerCase();
      if (errorStr.contains('timeout')) return 'timeout';
      if (errorStr.contains('connection refused')) return 'connection_refused';
      if (errorStr.contains('host lookup') || errorStr.contains('name resolution')) return 'dns_error';
      if (errorStr.contains('network unreachable')) return 'network_error';
    }
    return 'connection_error';
  }

  @override
  String toString() {
    final buffer = StringBuffer('OllamaConnectionException: $message');
    if (serverUrl != null) buffer.write(' [Server: $serverUrl]');
    if (timeout != null) buffer.write(' [Timeout: ${timeout!.inSeconds}s]');
    if (originalError != null) buffer.write(' [Cause: $originalError]');
    return buffer.toString();
  }

  /// Get detailed error information for logging
  Map<String, dynamic> toLogMap() {
    return {
      'message': message,
      'serverUrl': serverUrl,
      'timeoutSeconds': timeout?.inSeconds,
      'timestamp': timestamp.toIso8601String(),
      'errorCategory': errorCategory,
      'originalError': originalError?.toString(),
    };
  }
}

class OllamaService {
  final http.Client _client;
  final AppSettings _settings;
  final String? _authToken;
  final ErrorReportingService _errorReporting = ErrorReportingService();

  bool _isDisposed = false;

  // Connection timeout for Android devices - optimized for better responsiveness
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 120);
  
  // Retry configuration
  static const int _maxRetries = 2;
  static const Duration _baseRetryDelay = Duration(seconds: 1);

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
    // Validate inputs to prevent null pointer exceptions
    if (content.isEmpty && textFiles.isEmpty && imageFiles.isEmpty) {
      throw ArgumentError('Message must have content, text files, or image files');
    }

    final message = <String, dynamic>{
      'role': _mapRoleToApiRole(role),
    };

    // Build text content (including text files)
    final textContent = _buildFallbackChatContent(
      content: content,
      textFiles: textFiles,
      imageFiles: [], // Don't include image descriptions in text content
    );
    
    message['content'] = textContent.isNotEmpty 
        ? textContent 
        : (content.isNotEmpty ? content : 'Please analyze the provided images.');

    // Add images separately if we have them and vision is supported
    if (allowImages && imageFiles.isNotEmpty) {
      final images = <String>[];
      for (final file in imageFiles) {
        try {
          final base64 = file.base64Content;
          if (base64 != null && base64.isNotEmpty) {
            // Validate base64 format
            if (base64.length > 50 && (base64.contains('/') || base64.contains('+'))) {
              images.add(base64);
            } else {
              AppLogger.warning('Invalid base64 image data for file: ${file.fileName}');
            }
          }
        } catch (e) {
          AppLogger.error('Error processing image file: ${file.fileName}', e);
        }
      }
      
      if (images.isNotEmpty) {
        message['images'] = images;
        AppLogger.debug('Added ${images.length} images to message');
      }
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

  /// Determines if an error is retryable based on its type and characteristics
  bool _isRetryableError(Object error) {
    // Don't retry if service is disposed
    if (_isDisposed) return false;
    
    // Retry on connection errors and timeouts
    if (error is OllamaConnectionException) {
      return true;
    }
    
    // Retry on timeout exceptions
    if (error is TimeoutException) {
      return true;
    }
    
    // Retry on HTTP client exceptions (network issues)
    if (error is http.ClientException) {
      return true;
    }
    
    // Retry on specific HTTP status codes (server errors, rate limiting)
    if (error is OllamaApiException) {
      final statusCode = error.statusCode;
      if (statusCode != null) {
        // Don't retry on client errors (4xx) except rate limiting (429) and timeout (408)
        if (statusCode >= 400 && statusCode < 500) {
          return statusCode == 429 || statusCode == 408;
        }
        // Retry on server errors (5xx)
        return statusCode >= 500;
      }
    }
    
    return false;
  }

  /// Executes an operation with retry logic and exponential backoff
  /// 
  /// This method implements retry logic for API calls to handle transient failures
  /// such as network issues, server overload, or temporary service unavailability.
  /// 
  /// [operation] - The async operation to execute with retry logic
  /// [maxRetries] - Maximum number of retry attempts (defaults to _maxRetries)
  /// 
  /// Returns the result of the successful operation
  /// Throws the last encountered error if all retries are exhausted
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int? maxRetries,
  }) async {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }
    
    final retryLimit = maxRetries ?? _maxRetries;
    Object? lastError;
    
    for (int attempt = 0; attempt <= retryLimit; attempt++) {
      // Check if service was disposed during retry loop
      if (_isDisposed) {
        throw Exception('OllamaService was disposed during retry operation');
      }
      
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        
        // Don't retry if this is the last attempt or error is not retryable
        if (attempt == retryLimit || !_isRetryableError(e)) {
          // Report final failure to error reporting service
          try {
            _errorReporting.reportError(
              e,
              operation: 'API retry operation',
              context: {
                'attempts': attempt + 1,
                'maxRetries': retryLimit,
                'isRetryable': _isRetryableError(e),
                'isDisposed': _isDisposed,
              },
            );
          } catch (reportingError) {
            AppLogger.error('Error reporting retry failure', reportingError);
          }
          
          AppLogger.error('Operation failed after ${attempt + 1} attempts', e);
          rethrow;
        }
        
        // Calculate exponential backoff delay with jitter to prevent thundering herd
        final baseDelay = _baseRetryDelay.inSeconds * (1 << attempt); // 2^attempt
        final jitter = (baseDelay * 0.1 * (DateTime.now().millisecond % 100) / 100).round();
        final delay = Duration(seconds: baseDelay + jitter);
        
        AppLogger.warning(
          'Attempt ${attempt + 1}/${retryLimit + 1} failed, retrying in ${delay.inSeconds}s: $e'
        );
        
        // Wait before retrying, but check for disposal during wait
        final delayFuture = Future.delayed(delay);
        await delayFuture;
      }
    }
    
    // This should never be reached due to the rethrow above, but provide fallback
    throw lastError ?? StateError('Retry logic error: should not reach this point');
  }

  /// Enhanced request wrapper with detailed logging and error handling
  Future<T> _makeRequest<T>(
    Future<T> Function() request, {
    Duration? timeout,
    String? operationName,
    String? requestUrl,
    Map<String, dynamic>? requestBody,
  }) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final effectiveTimeout = timeout ?? _connectionTimeout;
    
    // Log request start (with sanitized body for security)
    AppLogger.info(
      'API Request [$requestId] ${operationName ?? 'Unknown'}: '
      '${requestUrl ?? 'Unknown URL'} (timeout: ${effectiveTimeout.inSeconds}s)'
    );
    
    if (requestBody != null) {
      final sanitizedBody = _sanitizeRequestBodyForLogging(requestBody);
      AppLogger.debug('Request [$requestId] body: $sanitizedBody');
    }

    final startTime = DateTime.now();
    
    try {
      final result = await request().timeout(
        effectiveTimeout,
        onTimeout: () {
          final duration = DateTime.now().difference(startTime);
          AppLogger.warning(
            'Request [$requestId] timed out after ${duration.inMilliseconds}ms '
            '(timeout: ${effectiveTimeout.inSeconds}s)'
          );
          throw OllamaConnectionException(
            'Connection timed out after ${effectiveTimeout.inSeconds}s. '
            'Please check your network connection and server settings.',
            serverUrl: requestUrl,
            timeout: effectiveTimeout,
          );
        },
      );
      
      final duration = DateTime.now().difference(startTime);
      AppLogger.info(
        'Request [$requestId] completed successfully in ${duration.inMilliseconds}ms'
      );
      
      return result;
    } on TimeoutException catch (e) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.error(
        'Request [$requestId] timeout after ${duration.inMilliseconds}ms', e
      );
      throw OllamaConnectionException(
        'Request timed out after ${duration.inMilliseconds}ms. '
        'The server may be unreachable or overloaded.',
        originalError: e,
        serverUrl: requestUrl,
        timeout: effectiveTimeout,
      );
    } on http.ClientException catch (e) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.error(
        'Request [$requestId] network error after ${duration.inMilliseconds}ms', e
      );
      throw OllamaConnectionException(
        'Network error occurred: ${e.message}',
        originalError: e,
        serverUrl: requestUrl,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.error(
        'Request [$requestId] failed after ${duration.inMilliseconds}ms', e
      );
      
      // Report error to error reporting service
      _errorReporting.reportError(
        e,
        operation: operationName ?? 'API request',
        context: {
          'requestId': requestId,
          'requestUrl': requestUrl,
          'durationMs': duration.inMilliseconds,
          'timeoutMs': effectiveTimeout.inMilliseconds,
        },
        correlationId: requestId,
      );
      
      if (e is OllamaConnectionException || e is OllamaApiException) {
        rethrow;
      }
      throw OllamaConnectionException(
        'Failed to connect to Ollama server',
        originalError: e,
        serverUrl: requestUrl,
      );
    }
  }

  /// Sanitize request body for logging to prevent sensitive data leaks
  Map<String, dynamic> _sanitizeRequestBodyForLogging(Map<String, dynamic> body) {
    final sanitized = Map<String, dynamic>.from(body);
    
    // Remove or truncate sensitive/large data
    if (sanitized.containsKey('messages')) {
      final messages = sanitized['messages'] as List?;
      if (messages != null) {
        sanitized['messages'] = messages.map((msg) {
          if (msg is Map<String, dynamic>) {
            final sanitizedMsg = Map<String, dynamic>.from(msg);
            
            // Truncate long text content
            if (sanitizedMsg['content'] is String) {
              final content = sanitizedMsg['content'] as String;
              if (content.length > 200) {
                sanitizedMsg['content'] = '${content.substring(0, 200)}... [truncated ${content.length - 200} chars]';
              }
            } else if (sanitizedMsg['content'] is List) {
              // Handle structured content (multimodal)
              final contentList = sanitizedMsg['content'] as List;
              sanitizedMsg['content'] = contentList.map((item) {
                if (item is Map<String, dynamic>) {
                  final sanitizedItem = Map<String, dynamic>.from(item);
                  if (sanitizedItem['type'] == 'image' && sanitizedItem['image'] is String) {
                    final imageData = sanitizedItem['image'] as String;
                    sanitizedItem['image'] = '[base64 image data: ${imageData.length} chars]';
                  } else if (sanitizedItem['type'] == 'text' && sanitizedItem['text'] is String) {
                    final text = sanitizedItem['text'] as String;
                    if (text.length > 200) {
                      sanitizedItem['text'] = '${text.substring(0, 200)}... [truncated ${text.length - 200} chars]';
                    }
                  }
                  return sanitizedItem;
                }
                return item;
              }).toList();
            }
            
            return sanitizedMsg;
          }
          return msg;
        }).toList();
      }
    }
    
    // Truncate long prompt content
    if (sanitized.containsKey('prompt') && sanitized['prompt'] is String) {
      final prompt = sanitized['prompt'] as String;
      if (prompt.length > 200) {
        sanitized['prompt'] = '${prompt.substring(0, 200)}... [truncated ${prompt.length - 200} chars]';
      }
    }
    
    return sanitized;
  }

  Future<Map<String, dynamic>> _fetchModelDetails(String modelName) {
    return _executeWithRetry(() => _makeRequest(() async {
      final requestUrl = '$_baseUrl/api/show';
      final requestBody = {'name': modelName};
      
      final response = await _client.post(
        Uri.parse(requestUrl),
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      AppLogger.debug('Model details response [$modelName]: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          AppLogger.debug('Successfully fetched model details for $modelName');
          return data;
        } catch (e) {
          AppLogger.error('Failed to parse model details response for $modelName', e);
          throw OllamaApiException(
            'Invalid JSON response for model $modelName',
            statusCode: response.statusCode,
            originalError: e,
            requestUrl: requestUrl,
            requestBody: requestBody,
            responseBody: response.body,
          );
        }
      }

      final errorMessage = response.body.trim().isNotEmpty 
          ? response.body.trim()
          : 'Failed to fetch model metadata for $modelName';
          
      AppLogger.error(
        'Model details request failed for $modelName: ${response.statusCode} - $errorMessage'
      );

      throw OllamaApiException(
        errorMessage,
        statusCode: response.statusCode,
        requestUrl: requestUrl,
        requestBody: requestBody,
        responseBody: response.body,
      );
    }, 
    operationName: 'Fetch model details',
    requestUrl: '$_baseUrl/api/show',
    requestBody: {'name': modelName},
    ));
  }

  Future<List<String>> getModels() async {
    return _executeWithRetry(() => _makeRequest(() async {
      final requestUrl = '$_baseUrl/api/tags';
      
      final response = await _client.get(
        Uri.parse(requestUrl),
        headers: _headers,
      );

      AppLogger.debug('Get models response: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['models'] != null) {
            final models = (data['models'] as List)
                .map((model) => model['name'] as String)
                .toList();
            AppLogger.info('Successfully loaded ${models.length} models');
            return models;
          } else {
            AppLogger.warning('No models found in response');
            return [];
          }
        } catch (e) {
          AppLogger.error('Failed to parse models response', e);
          throw OllamaApiException(
            'Invalid JSON response from models endpoint',
            originalError: e,
            statusCode: response.statusCode,
            requestUrl: requestUrl,
            responseBody: response.body,
          );
        }
      } else {
        final errorMessage = response.body.trim().isNotEmpty 
            ? response.body.trim()
            : 'Failed to load models';
            
        AppLogger.error('Get models request failed: ${response.statusCode} - $errorMessage');
        
        throw OllamaApiException(
          errorMessage,
          statusCode: response.statusCode,
          requestUrl: requestUrl,
          responseBody: response.body,
        );
      }
    },
    operationName: 'Get models',
    requestUrl: '$_baseUrl/api/tags',
    ));
  }

  Future<bool> testConnection() async {
    try {
      return await _executeWithRetry(() => _makeRequest(() async {
        final requestUrl = '$_baseUrl/api/tags';
        
        final response = await _client.get(
          Uri.parse(requestUrl),
          headers: _headers,
        );
        
        final isConnected = response.statusCode == 200;
        
        if (isConnected) {
          AppLogger.info('Connection test successful');
        } else {
          AppLogger.warning('Connection test failed: ${response.statusCode}');
        }
        
        return isConnected;
      },
      operationName: 'Test connection',
      requestUrl: '$_baseUrl/api/tags',
      ));
    } catch (e) {
      AppLogger.error('Connection test failed with exception', e);
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

    return _executeWithRetry(() => _makeRequest(() async {
      final modelName = model ?? 'llama2';
      final capabilities =
          await ModelCapabilityService.getModelCapabilitiesViaApi(
        modelName,
        fetchModelDetails: () => _fetchModelDetails(modelName),
      );

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
      
      // Use chat endpoint for vision-capable models or when we have image attachments
      final useChatEndpoint = capabilities.supportsVision || hasImageAttachments;

      // Warn if user tries to send images to non-vision model
      if (hasImageAttachments && !capabilities.supportsVision) {
        AppLogger.warning(
          'Model $modelName does not support vision. Image attachments will be ignored. '
          'Consider using a vision-capable model like llava or bakllava.'
        );
      }

      if (useChatEndpoint) {
        requestBody['messages'] = _buildChatMessages(
          conversationHistory: conversationHistory,
          prompt: prompt,
          processedFiles: processedFiles,
          allowImages: capabilities.supportsVision || hasImageAttachments,
        );

        AppLogger.debug(
          'Using chat endpoint for $modelName: '
          'vision=${capabilities.supportsVision}, '
          'hasImages=$hasImageAttachments, '
          'allowImages=${capabilities.supportsVision || hasImageAttachments}'
        );

        final requestUrl = '$_baseUrl/api/chat';
        
        final response = await _client.post(
          Uri.parse(requestUrl),
          headers: _headers,
          body: jsonEncode(requestBody),
        );

        AppLogger.debug('Chat API response: ${response.statusCode}');

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final message = data['message'] as Map<String, dynamic>?;
            if (message == null || message['content'] == null) {
              AppLogger.error('Invalid chat response format: missing message content');
              throw OllamaApiException(
                'Invalid response format: missing message content',
                statusCode: response.statusCode,
                requestUrl: requestUrl,
                requestBody: requestBody,
                responseBody: response.body,
              );
            }
            
            AppLogger.info('Chat response generated successfully');
            return OllamaResponse.fromJson(data);
          } catch (e) {
            if (e is OllamaApiException) rethrow;
            
            AppLogger.error('Failed to parse chat response JSON', e);
            AppLogger.debug('Raw response body: ${response.body}');
            throw OllamaApiException(
              'Invalid JSON response from chat endpoint',
              originalError: e,
              statusCode: response.statusCode,
              requestUrl: requestUrl,
              requestBody: requestBody,
              responseBody: response.body,
            );
          }
        } else {
          final errorBody = response.body.trim();
          
          // Check for structured content error and retry with string content
          if (response.statusCode == 400 && 
              errorBody.contains('cannot unmarshal array into Go struct field') &&
              errorBody.contains('content of type string')) {
            
            AppLogger.warning('Model $modelName requires string content format, retrying with fallback');
            
            // Retry with string-only content
            requestBody['messages'] = _buildChatMessages(
              conversationHistory: conversationHistory,
              prompt: prompt,
              processedFiles: processedFiles,
              allowImages: false, // Force string content
            );
            
            final retryResponse = await _client.post(
              Uri.parse(requestUrl),
              headers: _headers,
              body: jsonEncode(requestBody),
            );
            
            if (retryResponse.statusCode == 200) {
              try {
                final data = jsonDecode(retryResponse.body) as Map<String, dynamic>;
                AppLogger.info('Chat response generated successfully with string content fallback');
                return OllamaResponse.fromJson(data);
              } catch (e) {
                AppLogger.error('Failed to parse retry response JSON', e);
                throw OllamaApiException(
                  'Invalid JSON response from chat endpoint (retry)',
                  originalError: e,
                  statusCode: retryResponse.statusCode,
                  requestUrl: requestUrl,
                  requestBody: requestBody,
                  responseBody: retryResponse.body,
                );
              }
            }
          }
          
          final message = errorBody.isNotEmpty
              ? 'Chat generation failed: $errorBody'
              : 'Chat generation failed with no error details';
              
          AppLogger.error('Chat API error: ${response.statusCode} - $message');
          
          throw OllamaApiException(
            message,
            statusCode: response.statusCode,
            requestUrl: requestUrl,
            requestBody: requestBody,
            responseBody: response.body,
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

        final requestUrl = '$_baseUrl/api/generate';
        
        final response = await _client.post(
          Uri.parse(requestUrl),
          headers: _headers,
          body: jsonEncode(requestBody),
        );

        AppLogger.debug('Generate API response: ${response.statusCode}');

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            AppLogger.info('Generate response completed successfully');
            return OllamaResponse.fromJson(data);
          } catch (e) {
            if (e is OllamaApiException) rethrow;
            
            AppLogger.error('Failed to parse generate response JSON', e);
            AppLogger.debug('Raw response body: ${response.body}');
            throw OllamaApiException(
              'Invalid JSON response from generate endpoint',
              originalError: e,
              statusCode: response.statusCode,
              requestUrl: requestUrl,
              requestBody: requestBody,
              responseBody: response.body,
            );
          }
        } else {
          final errorBody = response.body.trim();
          final message = errorBody.isNotEmpty
              ? 'Text generation failed: $errorBody'
              : 'Text generation failed with no error details';
              
          AppLogger.error('Generate API error: ${response.statusCode} - $message');
          
          throw OllamaApiException(
            message,
            statusCode: response.statusCode,
            requestUrl: requestUrl,
            requestBody: requestBody,
            responseBody: response.body,
          );
        }
      }
    }, timeout: _receiveTimeout));
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

    // Use retry logic for establishing the streaming connection
    final streamedResponse = await _executeWithRetry(() async {
      final modelName = model ?? 'llama2';
      final capabilities =
          await ModelCapabilityService.getModelCapabilitiesViaApi(
        modelName,
        fetchModelDetails: () => _fetchModelDetails(modelName),
      );

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
      
      // Use chat endpoint for vision-capable models or when we have image attachments
      final useChatEndpoint = capabilities.supportsVision || hasImageAttachments;

      // Warn if user tries to send images to non-vision model
      if (hasImageAttachments && !capabilities.supportsVision) {
        AppLogger.warning(
          'Model $modelName does not support vision. Image attachments will be ignored. '
          'Consider using a vision-capable model like llava or bakllava.'
        );
      }

      http.Request request;

      if (useChatEndpoint) {
        requestBody['messages'] = _buildChatMessages(
          conversationHistory: conversationHistory,
          prompt: prompt,
          processedFiles: processedFiles,
          allowImages: capabilities.supportsVision || hasImageAttachments,
        );
        
        AppLogger.debug(
          'Using chat endpoint for streaming $modelName: '
          'vision=${capabilities.supportsVision}, '
          'hasImages=$hasImageAttachments, '
          'allowImages=${capabilities.supportsVision || hasImageAttachments}'
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

      return await _client.send(request);
    });

    try {
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

        // Check for structured content error - for streaming, we'll throw a more specific error
        // The retry logic should be handled at a higher level
        if (streamedResponse.statusCode == 400 && 
            errorBody != null &&
            errorBody.contains('cannot unmarshal array into Go struct field') &&
            errorBody.contains('content of type string')) {
          
          AppLogger.warning('Model requires string content format for streaming. This model may not support structured content.');
          throw OllamaApiException(
            'Model does not support structured content format. Try using a different model or remove image attachments.',
            statusCode: streamedResponse.statusCode,
          );
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
          await ModelCapabilityService.getModelCapabilitiesViaApi(
        modelName,
        fetchModelDetails: () => _fetchModelDetails(modelName),
      );

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
    if (_isDisposed) return;
    
    AppLogger.info('Disposing OllamaService');
    _isDisposed = true;

    try {
      _client.close();
    } catch (e) {
      AppLogger.error('Error closing HTTP client', e);
    }

    AppLogger.info('OllamaService disposed successfully');
  }
}
