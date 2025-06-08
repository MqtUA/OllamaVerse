import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/ollama_model.dart';
import '../models/app_settings.dart';
import '../utils/file_utils.dart';
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
  // Changed from final to allow updating
  AppSettings settings;
  
  // For cancellation support
  http.Client? _activeClient;
  StreamSubscription? _activeStreamSubscription;
  bool _isCancelled = false;
  
  /// Creates a new OllamaService instance with the provided settings.
  /// 
  /// [settings] - The AppSettings object containing Ollama server configuration.
  OllamaService({required this.settings});
  
  /// Updates the service with new settings.
  /// 
  /// This method allows changing the Ollama server configuration dynamically
  /// without having to create a new OllamaService instance.
  /// 
  /// [newSettings] - The new AppSettings object to use for future API calls.
  void updateSettings(AppSettings newSettings) {
    settings = newSettings;
  }
  
  /// Cleans up resources after a request is completed or cancelled.
  /// 
  /// Releases the HTTP client and stream subscription to prevent memory leaks.
  void _cleanupAfterRequest() {
    _activeClient = null;
    _activeStreamSubscription = null;
  }
  
  /// Cancels the current ongoing generation request.
  /// 
  /// Sets the cancellation flag and closes any active connections.
  /// This method can be called to stop a streaming response that's in progress.
  void cancelGeneration() {
    _isCancelled = true;
    if (_activeStreamSubscription != null) {
      _activeStreamSubscription!.cancel();
    }
    if (_activeClient != null) {
      _activeClient!.close();
    }
    _cleanupAfterRequest();
  }

  /// Returns HTTP headers for API requests, including auth token if available.
  /// 
  /// @return A map of header key-value pairs for HTTP requests.
  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (settings.authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.authToken}';
    }
    return headers;
  }

  /// Tests the connection to the Ollama server.
  /// 
  /// Makes a lightweight request to verify if the server is reachable
  /// and responding with a valid status code.
  /// 
  /// @return A Future that resolves to true if connection is successful, false otherwise.
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${settings.ollamaUrl}/api/tags'),
        headers: _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Custom exceptions are now defined at the top level

  /// Fetches the list of available models from the Ollama server.
  /// 
  /// Makes an HTTP request to the Ollama API's /api/tags endpoint to retrieve
  /// all available models that can be used for generating responses.
  /// 
  /// Returns a Future that resolves to a List of [OllamaModel] objects.
  /// 
  /// Throws:
  /// - [OllamaApiException]: When the API returns an error status code or invalid format
  /// - [OllamaConnectionException]: When there's a network or connection error
  Future<List<OllamaModel>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('${settings.ollamaUrl}/api/tags'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> models = data['models'] ?? [];
        return models.map((model) => OllamaModel.fromJson(model)).toList();
      } else {
        throw OllamaApiException(
          'Failed to load models', 
          statusCode: response.statusCode
        );
      }
    } on http.ClientException catch (e) {
      throw OllamaConnectionException(
        'Error connecting to Ollama server', 
        originalError: e
      );
    } on FormatException catch (e) {
      throw OllamaApiException(
        'Invalid response format from Ollama server', 
        originalError: e
      );
    } catch (e) {
      throw OllamaConnectionException(
        'Unexpected error when connecting to Ollama', 
        originalError: e
      );
    }
  }

  /// Generates a response from the Ollama model based on the provided prompt.
  /// 
  /// Parameters:
  /// - [modelName]: The name of the Ollama model to use (e.g., 'llama2', 'mistral')
  /// - [prompt]: The text prompt to send to the model
  /// - [attachedFiles]: Optional list of file paths to include as context
  /// - [context]: Optional conversation context from previous interactions
  /// - [stream]: Whether to stream the response (true) or wait for complete response (false)
  /// - [onStreamResponse]: Callback function that receives chunks of streamed response
  /// 
  /// Returns a Future that resolves to the complete response string.
  /// 
  /// Throws:
  /// - [OllamaApiException]: When the API returns an error status code or invalid format
  /// - [OllamaConnectionException]: When there's a network or connection error
  /// 
  /// The method handles various file types differently:
  /// - Images: Converted to base64 and sent in the 'images' field
  /// - PDFs: Text is extracted and added to the prompt
  /// - Text files: Content is read and added to the prompt
  Future<String> generateResponse({
    required String modelName,
    required String prompt,
    List<String>? attachedFiles,
    List<dynamic>? context,
    bool stream = false,
    Function(String)? onStreamResponse,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'model': modelName,
        'prompt': prompt,
        'stream': stream,
      };

      // Add context if provided
      if (context != null && context.isNotEmpty) {
        // Filter out UI-only context elements (like our system message markers)
        final apiContext = context.where((item) {
          if (item is Map) {
            // Skip items marked as ui_only
            return item['ui_only'] != true;
          }
          return true;
        }).toList();
        
        // Only add context if we have valid API context elements
        if (apiContext.isNotEmpty) {
          requestBody['context'] = apiContext;
        } else {
          // If no valid context, set context_length from settings
          requestBody['options'] = {
            'num_ctx': settings.contextLength,
          };
        }
      } else {
        // If no context is provided, set context_length from settings
        requestBody['options'] = {
          'num_ctx': settings.contextLength,
        };
      }

      // Process attached files if any
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        List<String> imageBase64List = [];
        List<String> textContents = [];
        
        for (String filePath in attachedFiles) {
          if (FileUtils.isImageFile(filePath)) {
            // Handle image files - convert to base64
            final File file = File(filePath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final base64Image = base64Encode(bytes);
              imageBase64List.add(base64Image);
            }
          } else if (FileUtils.isPdfFile(filePath)) {
            // Handle PDF files - extract text
            try {
              final pdfText = await FileUtils.extractTextFromPdf(filePath);
              final fileName = path.basename(filePath);
              textContents.add('PDF File: $fileName\n\n$pdfText');
            } catch (e) {
              AppLogger.error('Error processing PDF file', e);
              final fileName = path.basename(filePath);
              textContents.add('PDF File: $fileName\n\n[Error extracting PDF content]');
            }
          } else {
            // Handle text files - read content
            final File file = File(filePath);
            if (await file.exists()) {
              try {
                final content = await file.readAsString();
                final fileName = path.basename(filePath);
                textContents.add('File: $fileName\n\n$content');
              } catch (e) {
                AppLogger.error('Error reading file', e);
              }
            }
          }
        }
        
        // Add images if any
        if (imageBase64List.isNotEmpty) {
          requestBody['images'] = imageBase64List;
        }
        
        // Add text content to prompt if any
        if (textContents.isNotEmpty) {
          final fileContexts = textContents.join('\n\n---\n\n');
          requestBody['prompt'] = '$prompt\n\nHere are the attached files for context:\n\n$fileContexts';
        }
      }

      if (stream && onStreamResponse != null) {
        // Reset cancellation state
        _isCancelled = false;
        
        // Handle streaming response
        final request = http.Request('POST', Uri.parse('${settings.ollamaUrl}/api/generate'));
        request.headers.addAll(_getHeaders());
        request.body = json.encode(requestBody);
        
        // Create a client that we can cancel later
        _activeClient = http.Client();
        final streamedResponse = await _activeClient!.send(request);
        
        if (streamedResponse.statusCode == 200) {
          String fullResponse = '';
          final completer = Completer<String>();
          
          // Store the subscription so we can cancel it
          _activeStreamSubscription = streamedResponse.stream.transform(utf8.decoder).listen(
            (chunk) {
              if (_isCancelled) return;
              
              // Each chunk might contain multiple JSON objects separated by newlines
              final lines = chunk.split('\n');
              
              for (var line in lines) {
                if (line.trim().isEmpty) continue;
                if (_isCancelled) break;
                
                try {
                  final Map<String, dynamic> data = json.decode(line);
                  if (data.containsKey('response')) {
                    final partialResponse = data['response'] as String;
                    fullResponse += partialResponse;
                    onStreamResponse(partialResponse);
                  }
                  
                  // Store context if available
                  if (data.containsKey('context')) {
                    requestBody['context'] = data['context'];
                  }
                  
                  // Check if this is the done message
                  if (data.containsKey('done') && data['done'] == true) {
                    if (!completer.isCompleted) {
                      // Return both the response and context
                      final result = {
                        'response': fullResponse,
                        'context': requestBody['context'],
                      };
                      completer.complete(result['response'] as String);
                    }
                    break;
                  }
                } catch (e) {
                  AppLogger.error('Error parsing streaming response', e);
                }
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete(fullResponse);
              }
              _cleanupAfterRequest();
            },
            onError: (e) {
              if (!completer.isCompleted) {
                completer.completeError(OllamaConnectionException(
                  'Failed to generate streaming response',
                  originalError: e
                ));
              }
              _cleanupAfterRequest();
            },
            cancelOnError: true,
          );
          
          return await completer.future;
        } else {
          // Get the error response body for more details
          final errorBody = await streamedResponse.stream.transform(utf8.decoder).join();
          _cleanupAfterRequest();
          
          // Try to parse the error response for more details
          String errorDetails = '';
          try {
            final errorJson = json.decode(errorBody);
            if (errorJson.containsKey('error')) {
              errorDetails = ': ${errorJson['error']}';
            }
          } catch (_) {
            // If we can't parse the JSON, use the raw body if it's not too long
            if (errorBody.length < 100) {
              errorDetails = ': $errorBody';
            }
          }
          
          throw OllamaApiException(
            'Failed to generate streaming response$errorDetails', 
            statusCode: streamedResponse.statusCode
          );
        }
      } else {
        // Reset cancellation state
        _isCancelled = false;
        
        // Handle non-streaming response with cancellation support
        _activeClient = http.Client();
        try {
          final response = await _activeClient!.post(
            Uri.parse('${settings.ollamaUrl}/api/generate'),
            headers: _getHeaders(),
            body: json.encode(requestBody),
          );
          
          _cleanupAfterRequest();

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            
            // Create a result object with both response and context
            Map<String, dynamic> result = {
              'response': data['response'] ?? '',
              'context': data['context'],
            };
            
            // Return just the response string as required by the API
            return result['response'] as String;
          } else {
            // Try to parse the error response for more details
            String errorDetails = '';
            try {
              final errorJson = json.decode(response.body);
              if (errorJson.containsKey('error')) {
                errorDetails = ': ${errorJson['error']}';
              }
            } catch (_) {
              // If we can't parse the JSON, use the raw body if it's not too long
              if (response.body.length < 100) {
                errorDetails = ': ${response.body}';
              }
            }
            
            throw OllamaApiException(
              'Failed to generate response$errorDetails', 
              statusCode: response.statusCode
            );
          }
        } catch (e) {
          _cleanupAfterRequest();
          if (_isCancelled) {
            return 'Request cancelled by user';
          }
          if (e is http.ClientException) {
            throw OllamaConnectionException(
              'Error connecting to Ollama server', 
              originalError: e
            );
          } else if (e is FormatException) {
            throw OllamaApiException(
              'Invalid response format from Ollama server', 
              originalError: e
            );
          } else {
            throw OllamaConnectionException(
              'Unexpected error when generating response', 
              originalError: e
            );
          }
        }
      }
    } catch (e) {
      if (e is OllamaApiException || e is OllamaConnectionException) {
        // Re-throw custom exceptions
        rethrow;
      } else {
        throw OllamaConnectionException(
          'Error connecting to Ollama', 
          originalError: e
        );
      }
    }
  }
}
