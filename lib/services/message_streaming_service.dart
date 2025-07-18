import 'dart:async';
import '../models/message.dart';
import '../models/processed_file.dart';
import '../models/streaming_state.dart';
import '../models/thinking_state.dart';
import '../services/ollama_service.dart';
import '../services/thinking_content_processor.dart';
import '../utils/cancellation_token.dart';
import '../utils/logger.dart';

/// Service responsible for message generation coordination and streaming response handling
/// Manages streaming operations, cancellation, and response processing coordination
class MessageStreamingService {
  final OllamaService _ollamaService;
  
  // Current streaming state
  StreamingState _streamingState = StreamingState.initial();
  ThinkingState _thinkingState = ThinkingState.initial();
  
  // Stream management
  StreamSubscription? _streamSubscription;
  CancellationToken _cancellationToken = CancellationToken();
  
  // Callbacks for state updates
  void Function(StreamingState)? _onStreamingStateChanged;
  void Function(ThinkingState)? _onThinkingStateChanged;
  
  // ThinkingContentProcessor instance for processing thinking content
  final ThinkingContentProcessor _thinkingContentProcessor;
  
  MessageStreamingService({
    required OllamaService ollamaService,
    required ThinkingContentProcessor thinkingContentProcessor,
  }) : _ollamaService = ollamaService,
       _thinkingContentProcessor = thinkingContentProcessor;

  // Getters
  StreamingState get streamingState => _streamingState;
  ThinkingState get thinkingState => _thinkingState;
  bool get isStreaming => _streamingState.isStreaming;
  bool get isCancelled => _cancellationToken.isCancelled;

  /// Set callback for streaming state changes
  void setStreamingStateCallback(void Function(StreamingState) callback) {
    _onStreamingStateChanged = callback;
  }

  /// Set callback for thinking state changes
  void setThinkingStateCallback(void Function(ThinkingState) callback) {
    _onThinkingStateChanged = callback;
  }

  /// Start streaming message generation
  /// Returns a stream of response chunks and final context
  Stream<Map<String, dynamic>> generateStreamingMessage({
    required String content,
    required String model,
    required List<Message> conversationHistory,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    int? contextLength,
    bool showLiveResponse = true,
  }) async* {
    try {
      AppLogger.info('Starting streaming message generation with model: $model');
      
      // Reset states
      _resetStreamingStates();
      
      // Initialize thinking state for new generation using injected processor
      _thinkingState = _thinkingContentProcessor.initializeThinkingState();
      _notifyThinkingStateChanged();
      
      if (showLiveResponse) {
        // Use streaming response for live updates
        yield* _handleStreamingResponse(
          content: content,
          model: model,
          conversationHistory: conversationHistory,
          processedFiles: processedFiles,
          context: context,
          contextLength: contextLength,
        );
      } else {
        // Use non-streaming response for faster completion
        yield* _handleNonStreamingResponse(
          content: content,
          model: model,
          conversationHistory: conversationHistory,
          processedFiles: processedFiles,
          context: context,
          contextLength: contextLength,
        );
      }
    } catch (e) {
      AppLogger.error('Error in streaming message generation', e);
      
      // Reset states on error
      _resetStreamingStates();
      
      rethrow;
    }
  }

  /// Handle streaming response with live updates
  Stream<Map<String, dynamic>> _handleStreamingResponse({
    required String content,
    required String model,
    required List<Message> conversationHistory,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    int? contextLength,
  }) async* {
    try {
      // Start streaming state
      _streamingState = StreamingState.streaming(
        currentResponse: '',
        displayResponse: '',
      );
      _notifyStreamingStateChanged();
      
      String accumulatedResponse = '';
      List<int>? finalContext;
      
      await for (final streamResponse in _ollamaService.generateStreamingResponseWithContext(
        content,
        model: model,
        processedFiles: processedFiles,
        context: context,
        conversationHistory: conversationHistory,
        contextLength: contextLength,
        isCancelled: () => _cancellationToken.isCancelled,
      )) {
        // Check for cancellation
        if (_cancellationToken.isCancelled) {
          AppLogger.warning('Stream cancelled during generation');
          break;
        }
        
        // Process response chunk
        if (streamResponse.response.isNotEmpty) {
          accumulatedResponse += streamResponse.response;
          
          // Process thinking content and filter response using injected processor
          final processedResult = _thinkingContentProcessor.processStreamingResponse(
            fullResponse: accumulatedResponse,
            currentState: _thinkingState,
          );
          
          final filteredResponse = processedResult['filteredResponse'] as String;
          _thinkingState = processedResult['thinkingState'] as ThinkingState;
          
          // Update streaming state
          _streamingState = _streamingState.copyWith(
            currentResponse: accumulatedResponse,
            displayResponse: filteredResponse,
          );
          
          // Update thinking phase based on content
          _thinkingState = _thinkingContentProcessor.updateThinkingPhase(
            currentState: _thinkingState,
            displayResponse: filteredResponse,
          );
          
          // Notify state changes
          _notifyStreamingStateChanged();
          _notifyThinkingStateChanged();
          
          // Yield current state
          yield {
            'type': 'chunk',
            'response': filteredResponse,
            'fullResponse': accumulatedResponse,
            'streamingState': _streamingState,
            'thinkingState': _thinkingState,
          };
        }
        
        // Handle completion
        if (streamResponse.done) {
          finalContext = streamResponse.context;
          AppLogger.info('Streaming response completed');
          break;
        }
      }
      
      // Complete streaming
      _streamingState = StreamingState.completed(accumulatedResponse);
      _thinkingState = _thinkingContentProcessor.resetThinkingState(_thinkingState);
      
      _notifyStreamingStateChanged();
      _notifyThinkingStateChanged();
      
      // Yield final result
      yield {
        'type': 'complete',
        'response': _streamingState.displayResponse,
        'fullResponse': accumulatedResponse,
        'context': finalContext,
        'streamingState': _streamingState,
        'thinkingState': _thinkingState,
      };
      
    } catch (e) {
      AppLogger.error('Error in streaming response handling', e);
      rethrow;
    }
  }

  /// Handle non-streaming response for faster completion
  Stream<Map<String, dynamic>> _handleNonStreamingResponse({
    required String content,
    required String model,
    required List<Message> conversationHistory,
    List<ProcessedFile>? processedFiles,
    List<int>? context,
    int? contextLength,
  }) async* {
    try {
      AppLogger.info('Using non-streaming response for faster completion');
      
      // Generate complete response
      final response = await _ollamaService.generateResponseWithContext(
        content,
        model: model,
        processedFiles: processedFiles,
        context: context,
        conversationHistory: conversationHistory,
        contextLength: contextLength,
        isCancelled: () => _cancellationToken.isCancelled,
      );
      
      // Check for cancellation
      if (_cancellationToken.isCancelled) {
        AppLogger.warning('Non-streaming generation cancelled');
        return;
      }
      
      // Process thinking content using injected processor
      final processedResult = _thinkingContentProcessor.processStreamingResponse(
        fullResponse: response.response,
        currentState: _thinkingState,
      );
      
      final filteredResponse = processedResult['filteredResponse'] as String;
      _thinkingState = processedResult['thinkingState'] as ThinkingState;
      
      // Update states
      _streamingState = StreamingState.completed(response.response);
      _thinkingState = _thinkingContentProcessor.resetThinkingState(_thinkingState);
      
      _notifyStreamingStateChanged();
      _notifyThinkingStateChanged();
      
      // Yield complete result
      yield {
        'type': 'complete',
        'response': filteredResponse,
        'fullResponse': response.response,
        'context': response.context,
        'streamingState': _streamingState,
        'thinkingState': _thinkingState,
      };
      
    } catch (e) {
      AppLogger.error('Error in non-streaming response handling', e);
      rethrow;
    }
  }

  /// Cancel current streaming operation
  void cancelStreaming() {
    AppLogger.info('Cancelling streaming operation');
    
    _cancellationToken.cancel();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    
    // Reset states
    _resetStreamingStates();
  }

  /// Reset streaming and thinking states
  void _resetStreamingStates() {
    _streamingState = StreamingState.initial();
    _thinkingState = ThinkingState.initial();
    _cancellationToken = CancellationToken();
    
    _notifyStreamingStateChanged();
    _notifyThinkingStateChanged();
  }

  /// Notify streaming state change
  void _notifyStreamingStateChanged() {
    _onStreamingStateChanged?.call(_streamingState);
  }

  /// Notify thinking state change
  void _notifyThinkingStateChanged() {
    _onThinkingStateChanged?.call(_thinkingState);
  }

  /// Toggle thinking bubble expansion
  void toggleThinkingBubble(String messageId) {
    _thinkingState = _thinkingContentProcessor.toggleBubbleExpansion(
      currentState: _thinkingState,
      messageId: messageId,
    );
    _notifyThinkingStateChanged();
  }

  /// Check if thinking bubble is expanded
  bool isThinkingBubbleExpanded(String messageId) {
    return _thinkingContentProcessor.isBubbleExpanded(
      currentState: _thinkingState,
      messageId: messageId,
    );
  }

  /// Get current streaming statistics for debugging
  Map<String, dynamic> getStreamingStats() {
    return {
      'isStreaming': isStreaming,
      'isCancelled': isCancelled,
      'streamingState': _streamingState.toString(),
      'thinkingStats': _thinkingContentProcessor.getThinkingStats(_thinkingState),
      'hasActiveSubscription': _streamSubscription != null,
    };
  }

  /// Validate current state consistency
  bool validateState() {
    return _streamingState.isValid && _thinkingState.isValid;
  }

  /// Dispose resources
  void dispose() {
    AppLogger.info('Disposing MessageStreamingService');
    
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _cancellationToken.cancel();
    
    _onStreamingStateChanged = null;
    _onThinkingStateChanged = null;
  }
}