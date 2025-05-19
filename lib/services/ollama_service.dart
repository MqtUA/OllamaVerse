import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/ollama_model.dart';
import '../models/app_settings.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

class OllamaService {
  final AppSettings settings;
  
  // For cancellation support
  http.Client? _activeClient;
  StreamSubscription? _activeStreamSubscription;
  bool _isCancelled = false;
  
  OllamaService({required this.settings});
  
  // Clean up resources after request
  void _cleanupAfterRequest() {
    _activeClient = null;
    _activeStreamSubscription = null;
  }
  
  // Cancel the current request
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

  // Get default headers with auth token if available
  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (settings.authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.authToken}';
    }
    return headers;
  }

  // Test connection to the Ollama server
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
        throw Exception('Failed to load models: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to Ollama: $e');
    }
  }

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
        requestBody['context'] = context;
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
                completer.completeError(Exception('Failed to generate streaming response: $e'));
              }
              _cleanupAfterRequest();
            },
            cancelOnError: true,
          );
          
          return await completer.future;
        } else {
          _cleanupAfterRequest();
          throw Exception('Failed to generate streaming response: ${streamedResponse.statusCode}');
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
            throw Exception('Failed to generate response: ${response.statusCode}');
          }
        } catch (e) {
          _cleanupAfterRequest();
          if (_isCancelled) {
            return 'Request cancelled by user';
          }
          throw Exception('Failed to generate response: $e');
        }
      }
    } catch (e) {
      throw Exception('Error connecting to Ollama: $e');
    }
  }
}
