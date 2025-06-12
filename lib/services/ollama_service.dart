import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
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

  Future<String> generateResponse(
    String prompt, {
    String? model,
    List<int>? context,
  }) async {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }

    return _makeRequest(() async {
      final requestBody = {
        'model': model ?? 'llama2',
        'prompt': prompt,
        'stream': false, // Explicitly request non-streaming response
      };

      // Only add context if it's not null and not empty
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

          // Check if response contains the expected fields
          if (data['response'] != null) {
            return data['response'] as String;
          } else {
            throw OllamaApiException(
              'Invalid response format: missing response field',
            );
          }
        } catch (e) {
          if (e is OllamaApiException) rethrow;

          // Log the raw response for debugging
          AppLogger.error('Raw response body: ${response.body}');
          throw OllamaApiException(
            'Invalid JSON response from generate endpoint',
            originalError: e,
          );
        }
      } else {
        throw OllamaApiException(
          'Failed to generate response',
          statusCode: response.statusCode,
        );
      }
    }, timeout: _receiveTimeout);
  }

  Stream<String> generateStreamingResponse(
    String prompt, {
    String? model,
    List<int>? context,
  }) async* {
    if (_isDisposed) {
      throw Exception('OllamaService has been disposed');
    }

    try {
      final requestBody = {
        'model': model ?? 'llama2',
        'prompt': prompt,
        'stream': true, // Explicitly request streaming response
      };

      // Only add context if it's not null and not empty
      if (context != null && context.isNotEmpty) {
        requestBody['context'] = context;
      }

      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/generate'),
      );
      request.headers.addAll(_headers);
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _client.send(request).timeout(
        _connectionTimeout,
        onTimeout: () {
          throw OllamaConnectionException(
            'Connection timed out while starting streaming response',
          );
        },
      );

      if (streamedResponse.statusCode == 200) {
        await for (final chunk
            in streamedResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              try {
                final data = jsonDecode(line.trim());
                if (data['response'] != null) {
                  yield data['response'] as String;
                }

                // Check if this is the final chunk
                if (data['done'] == true) {
                  return;
                }
              } catch (e) {
                AppLogger.error(
                    'Error parsing streaming response line: $line', e);
                // Continue processing other lines instead of failing completely
              }
            }
          }
        }
      } else {
        throw OllamaApiException(
          'Failed to generate streaming response',
          statusCode: streamedResponse.statusCode,
        );
      }
    } on OllamaApiException {
      rethrow;
    } on TimeoutException {
      throw OllamaConnectionException(
        'Streaming request timed out',
      );
    } catch (e) {
      AppLogger.error('Error in streaming response', e);
      throw OllamaConnectionException(
        'Failed to connect to Ollama server',
        originalError: e,
      );
    }
  }

  void dispose() {
    _isDisposed = true;
    _streamController?.close();
    _client.close();
  }
}
