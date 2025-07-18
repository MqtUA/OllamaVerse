import '../providers/settings_provider.dart';
import '../services/chat_history_service.dart';
import '../services/model_manager.dart';
import '../services/chat_state_manager.dart';
import '../services/message_streaming_service.dart';
import '../services/chat_title_generator.dart';
import '../services/file_processing_manager.dart';
import '../services/thinking_content_processor.dart';
import '../services/file_content_processor.dart';
import '../utils/logger.dart';

/// Service locator for managing dependency injection and service lifecycle
/// Provides centralized service registration, initialization, and disposal
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  static ServiceLocator get instance => _instance;

  // Service instances
  ChatHistoryService? _chatHistoryService;
  ModelManager? _modelManager;
  ChatStateManager? _chatStateManager;
  MessageStreamingService? _messageStreamingService;
  ChatTitleGenerator? _chatTitleGenerator;
  FileProcessingManager? _fileProcessingManager;
  ThinkingContentProcessor? _thinkingContentProcessor;
  FileContentProcessor? _fileContentProcessor;

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
  
  // Track initialization errors for debugging
  String? _lastInitializationError;

  /// Initialize all services with their dependencies
  Future<void> initialize(SettingsProvider settingsProvider) async {
    if (_isInitialized) {
      AppLogger.info('ServiceLocator already initialized');
      return;
    }

    // Prevent concurrent initialization attempts
    if (_isInitializing) {
      AppLogger.info('ServiceLocator initialization already in progress, waiting...');
      // Wait for initialization to complete
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_isInitialized) return;
      if (_lastInitializationError != null) {
        throw StateError('Previous initialization failed: $_lastInitializationError');
      }
    }

    _isInitializing = true;
    _lastInitializationError = null;

    try {
      AppLogger.info('Initializing ServiceLocator...');

      // Validate input
      if (settingsProvider.isLoading) {
        throw StateError('SettingsProvider is still loading, cannot initialize services');
      }

      // Initialize services in dependency order
      _chatHistoryService = ChatHistoryService();
      
      _fileContentProcessor = FileContentProcessor();
      
      _fileProcessingManager = FileProcessingManager(
        fileContentProcessor: _fileContentProcessor!
      );
      
      _modelManager = ModelManager(
        settingsProvider: settingsProvider
      );
      
      _thinkingContentProcessor = ThinkingContentProcessor();
      
      _messageStreamingService = MessageStreamingService(
        ollamaService: settingsProvider.getOllamaService(),
        thinkingContentProcessor: _thinkingContentProcessor!
      );
      
      _chatTitleGenerator = ChatTitleGenerator(
        ollamaService: settingsProvider.getOllamaService(),
        modelManager: _modelManager!
      );
      
      _chatStateManager = ChatStateManager(
        chatHistoryService: _chatHistoryService!
      );

      // Initialize services that require async initialization
      await _initializeAsyncServices();

      _isInitialized = true;
      _isInitializing = false;
      AppLogger.info('ServiceLocator initialized successfully');
    } catch (e, stackTrace) {
      _lastInitializationError = e.toString();
      _isInitializing = false;
      
      // Clean up partially initialized services
      await _cleanupPartialInitialization();
      
      AppLogger.error('Failed to initialize ServiceLocator', e, stackTrace);
      rethrow;
    }
  }

  /// Initialize services that require async setup
  Future<void> _initializeAsyncServices() async {
    try {
      // Initialize model manager first as other services may depend on it
      if (_modelManager != null) {
        await _modelManager!.initialize();
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('Error during async service initialization', e, stackTrace);
      rethrow;
    }
  }

  /// Clean up partially initialized services on initialization failure
  Future<void> _cleanupPartialInitialization() async {
    try {
      AppLogger.info('Cleaning up partially initialized services...');
      
      // Dispose services that may have been partially initialized
      _fileProcessingManager?.dispose();
      _messageStreamingService?.dispose();
      _chatStateManager?.dispose();
      await _chatHistoryService?.dispose();

      // Clear all references
      _fileProcessingManager = null;
      _chatTitleGenerator = null;
      _messageStreamingService = null;
      _thinkingContentProcessor = null;
      _chatStateManager = null;
      _modelManager = null;
      _fileContentProcessor = null;
      _chatHistoryService = null;
      
      AppLogger.info('Partial initialization cleanup completed');
    } catch (e, stackTrace) {
      AppLogger.error('Error during partial initialization cleanup', e, stackTrace);
    }
  }

  /// Get ChatHistoryService instance
  ChatHistoryService get chatHistoryService {
    _ensureInitialized();
    return _chatHistoryService!;
  }

  /// Get ModelManager instance
  ModelManager get modelManager {
    _ensureInitialized();
    return _modelManager!;
  }

  /// Get ChatStateManager instance
  ChatStateManager get chatStateManager {
    _ensureInitialized();
    return _chatStateManager!;
  }

  /// Get MessageStreamingService instance
  MessageStreamingService get messageStreamingService {
    _ensureInitialized();
    return _messageStreamingService!;
  }

  /// Get ChatTitleGenerator instance
  ChatTitleGenerator get chatTitleGenerator {
    _ensureInitialized();
    return _chatTitleGenerator!;
  }

  /// Get FileProcessingManager instance
  FileProcessingManager get fileProcessingManager {
    _ensureInitialized();
    return _fileProcessingManager!;
  }

  /// Get ThinkingContentProcessor instance
  ThinkingContentProcessor get thinkingContentProcessor {
    _ensureInitialized();
    return _thinkingContentProcessor!;
  }
  
  /// Get FileContentProcessor instance
  FileContentProcessor get fileContentProcessor {
    _ensureInitialized();
    return _fileContentProcessor!;
  }

  /// Check if services are initialized
  bool get isInitialized => _isInitialized;

  /// Check if a service is registered
  bool isServiceRegistered<T>() {
    if (!_isInitialized) return false;
    
    if (T == ChatHistoryService) return _chatHistoryService != null;
    if (T == ModelManager) return _modelManager != null;
    if (T == ChatStateManager) return _chatStateManager != null;
    if (T == MessageStreamingService) return _messageStreamingService != null;
    if (T == ChatTitleGenerator) return _chatTitleGenerator != null;
    if (T == FileProcessingManager) return _fileProcessingManager != null;
    if (T == ThinkingContentProcessor) return _thinkingContentProcessor != null;
    if (T == FileContentProcessor) return _fileContentProcessor != null;
    
    return false;
  }
  
  /// Get service lifecycle status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isDisposed': _isDisposed,
      'registeredServices': {
        'ChatHistoryService': _chatHistoryService != null,
        'ModelManager': _modelManager != null,
        'ChatStateManager': _chatStateManager != null,
        'MessageStreamingService': _messageStreamingService != null,
        'ChatTitleGenerator': _chatTitleGenerator != null,
        'FileProcessingManager': _fileProcessingManager != null,
        'ThinkingContentProcessor': _thinkingContentProcessor != null,
        'FileContentProcessor': _fileContentProcessor != null,
      }
    };
  }

  /// Dispose all services and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) {
      AppLogger.info('ServiceLocator already disposed');
      return;
    }

    try {
      AppLogger.info('Disposing ServiceLocator...');

      // Dispose services in reverse dependency order
      // Only call dispose on services that have the method
      _fileProcessingManager?.dispose();
      _messageStreamingService?.dispose();
      _chatStateManager?.dispose();
      await _chatHistoryService?.dispose();

      // Clear references
      _fileProcessingManager = null;
      _chatTitleGenerator = null;
      _messageStreamingService = null;
      _thinkingContentProcessor = null;
      _chatStateManager = null;
      _modelManager = null;
      _fileContentProcessor = null;
      _chatHistoryService = null;

      _isInitialized = false;
      _isDisposed = true;
      
      AppLogger.info('ServiceLocator disposed successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Error disposing ServiceLocator', e, stackTrace);
    }
  }

  /// Reset the service locator (for testing purposes)
  Future<void> reset() async {
    await dispose();
    _isDisposed = false;
  }

  /// Ensure services are initialized before access
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ServiceLocator not initialized. Call initialize() first.');
    }
    if (_isDisposed) {
      throw StateError('ServiceLocator has been disposed.');
    }
  }
}