import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat.dart';
import '../utils/logger.dart';

class ChatHistoryService {
  static const String _chatsDir = 'chats';
  static const int _maxChats = 100; // Maximum number of chats to keep
  static const Duration _cleanupInterval = Duration(hours: 24);
  static const int _maxMessageLength =
      100000; // Maximum length of a single message

  final _chatController = StreamController<List<Chat>>.broadcast();
  Stream<List<Chat>> get chatStream => _chatController.stream;

  List<Chat> _chats = [];
  List<Chat> get chats => List.unmodifiable(_chats);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool _disposed = false;

  DateTime? _lastCleanup;
  Timer? _cleanupTimer;

  ChatHistoryService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadChats();
      _startCleanupTimer();
      _isInitialized = true;
      AppLogger.info(
          'ChatHistoryService initialized successfully with ${_chats.length} chats');
    } catch (e) {
      AppLogger.error('Error initializing chat history service', e);
      _isInitialized =
          true; // Mark as initialized even if failed to prevent infinite waiting
      rethrow;
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _cleanupOldChats());
  }

  Future<void> _loadChats() async {
    try {
      final chatsDir = await _getChatsDirectory();

      if (!await chatsDir.exists()) {
        await chatsDir.create(recursive: true);
        _chats = [];
        _notifyListeners();
        return;
      }

      final List<Chat> loadedChats = [];
      final files = await chatsDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final chatData = jsonDecode(content) as Map<String, dynamic>;
            
            // Handle migration for chats without customGenerationSettings
            final migratedChatData = _migrateChatDataIfNeeded(chatData);
            
            final chat = Chat.fromJson(migratedChatData);
            loadedChats.add(chat);
          } catch (e) {
            AppLogger.error('Error parsing chat file ${file.path}', e);
            // Try to backup corrupted chat file
            await _backupCorruptedChatFile(file);
          }
        }
      }

      // Sort chats by most recent first
      loadedChats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

      // Limit the number of chats
      _chats = loadedChats.take(_maxChats).toList();
      _notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading chats', e);
      rethrow;
    }
  }

  Future<Directory> _getChatsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_chatsDir');
  }

  Future<void> saveChat(Chat chat) async {
    try {
      // Sanitize chat data before validation and saving
      final sanitizedChat = _sanitizeChatForSaving(chat);
      
      // Validate sanitized chat data
      if (!_isValidChat(sanitizedChat)) {
        throw Exception('Invalid chat data after sanitization');
      }

      final chatsDir = await _getChatsDirectory();
      final file = File('${chatsDir.path}/${sanitizedChat.id}.json');

      // Ensure the chat directory exists
      if (!await chatsDir.exists()) {
        await chatsDir.create(recursive: true);
      }

      // Save the sanitized chat to file
      await file.writeAsString(jsonEncode(sanitizedChat.toJson()));

      // Update in-memory list with sanitized chat
      final index = _chats.indexWhere((c) => c.id == sanitizedChat.id);
      if (index >= 0) {
        _chats[index] = sanitizedChat;
      } else {
        _chats.insert(0, sanitizedChat);
        // Ensure we don't exceed the maximum number of chats
        if (_chats.length > _maxChats) {
          _chats = _chats.take(_maxChats).toList();
        }
      }

      // Sort chats by most recent first
      _chats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

      // Notify listeners
      _notifyListeners();
    } catch (e) {
      AppLogger.error('Error saving chat', e);
      rethrow;
    }
  }

  Future<Chat?> loadChat(String chatId) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final file = File('${chatsDir.path}/$chatId.json');

      if (await file.exists()) {
        final chatJson = await file.readAsString();
        final chatData = jsonDecode(chatJson) as Map<String, dynamic>;
        
        // Handle migration for chat without customGenerationSettings
        final migratedChatData = _migrateChatDataIfNeeded(chatData);
        
        return Chat.fromJson(migratedChatData);
      }

      return null;
    } catch (e) {
      AppLogger.error('Error loading chat $chatId', e);
      
      // Try to backup corrupted file if it exists
      final file = File('${(await _getChatsDirectory()).path}/$chatId.json');
      if (await file.exists()) {
        await _backupCorruptedChatFile(file);
      }
      
      return null;
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final chatFile = File('${chatsDir.path}/$chatId.json');

      if (await chatFile.exists()) {
        await chatFile.delete();
      }

      // Update in-memory list
      _chats.removeWhere((c) => c.id == chatId);
      _notifyListeners();
    } catch (e) {
      AppLogger.error('Error deleting chat', e);
      rethrow;
    }
  }

  Future<void> _cleanupOldChats() async {
    try {
      final now = DateTime.now();
      if (_lastCleanup != null &&
          now.difference(_lastCleanup!) < _cleanupInterval) {
        return;
      }

      _lastCleanup = now;

      // Remove chats that exceed the maximum limit
      if (_chats.length > _maxChats) {
        final chatsToRemove = _chats.sublist(_maxChats);
        for (final chat in chatsToRemove) {
          await deleteChat(chat.id);
        }
      }

      // Clean up any orphaned files
      final chatsDir = await _getChatsDirectory();
      if (await chatsDir.exists()) {
        final files = await chatsDir.list().toList();
        for (final file in files) {
          if (file is File && file.path.endsWith('.json')) {
            final chatId = file.path.split('/').last.replaceAll('.json', '');
            if (!_chats.any((c) => c.id == chatId)) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error cleaning up old chats', e);
    }
  }

  bool _isValidChat(Chat chat) {
    // Check if all messages are valid
    for (final message in chat.messages) {
      if (message.content.length > _maxMessageLength) {
        return false;
      }
    }
    
    // Validate custom generation settings if present
    if (chat.customGenerationSettings != null) {
      if (!_isValidGenerationSettings(chat.customGenerationSettings!)) {
        AppLogger.warning('Invalid custom generation settings for chat ${chat.id}');
        return false;
      }
    }
    
    return true;
  }

  /// Validate generation settings values
  bool _isValidGenerationSettings(dynamic settings) {
    try {
      // If it's already a GenerationSettings object, it should be valid
      if (settings.runtimeType.toString() == 'GenerationSettings') {
        return true;
      }
      
      // If it's a Map, validate the values
      if (settings is Map<String, dynamic>) {
        final temperature = settings['temperature'];
        if (temperature != null && temperature is num) {
          final temp = temperature.toDouble();
          if (temp < 0.0 || temp > 2.0) return false;
        }
        
        final topP = settings['topP'];
        if (topP != null && topP is num) {
          final tp = topP.toDouble();
          if (tp < 0.0 || tp > 1.0) return false;
        }
        
        final topK = settings['topK'];
        if (topK != null && topK is num) {
          final tk = topK.toInt();
          if (tk < 1 || tk > 100) return false;
        }
        
        final repeatPenalty = settings['repeatPenalty'];
        if (repeatPenalty != null && repeatPenalty is num) {
          final rp = repeatPenalty.toDouble();
          if (rp < 0.5 || rp > 2.0) return false;
        }
        
        final maxTokens = settings['maxTokens'];
        if (maxTokens != null && maxTokens is num) {
          final mt = maxTokens.toInt();
          if (mt < -1 || mt > 4096) return false;
        }
        
        final numThread = settings['numThread'];
        if (numThread != null && numThread is num) {
          final nt = numThread.toInt();
          if (nt < 1 || nt > 16) return false;
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Error validating generation settings', e);
      return false;
    }
  }

  /// Migrate chat data to include customGenerationSettings field if needed
  Map<String, dynamic> _migrateChatDataIfNeeded(Map<String, dynamic> chatData) {
    try {
      // Check if customGenerationSettings field exists
      if (!chatData.containsKey('customGenerationSettings')) {
        // Add null customGenerationSettings for backward compatibility
        chatData['customGenerationSettings'] = null;
        AppLogger.debug('Migrated chat data to include customGenerationSettings field');
      } else {
        // Validate existing customGenerationSettings
        final customSettings = chatData['customGenerationSettings'];
        if (customSettings != null && !_isValidGenerationSettings(customSettings)) {
          AppLogger.warning('Invalid customGenerationSettings found, setting to null');
          chatData['customGenerationSettings'] = null;
        }
      }
      
      return chatData;
    } catch (e) {
      AppLogger.error('Error migrating chat data', e);
      // Ensure customGenerationSettings field exists even if migration fails
      chatData['customGenerationSettings'] = null;
      return chatData;
    }
  }

  /// Backup corrupted chat file for debugging
  Future<void> _backupCorruptedChatFile(File corruptedFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${corruptedFile.path}.corrupted_$timestamp';
      await corruptedFile.copy(backupPath);
      AppLogger.info('Backed up corrupted chat file to $backupPath');
      
      // Delete the corrupted original file
      await corruptedFile.delete();
      AppLogger.info('Deleted corrupted chat file ${corruptedFile.path}');
    } catch (e) {
      AppLogger.error('Error backing up corrupted chat file', e);
    }
  }

  /// Validate and sanitize chat before saving
  Chat _sanitizeChatForSaving(Chat chat) {
    try {
      // If chat has invalid custom generation settings, remove them
      if (chat.customGenerationSettings != null && 
          !_isValidGenerationSettings(chat.customGenerationSettings)) {
        AppLogger.warning('Removing invalid custom generation settings from chat ${chat.id}');
        return chat.copyWith(customGenerationSettings: null);
      }
      
      return chat;
    } catch (e) {
      AppLogger.error('Error sanitizing chat for saving', e);
      // Return chat without custom settings if sanitization fails
      return chat.copyWith(customGenerationSettings: null);
    }
  }

  /// Get statistics about chats with custom generation settings
  Map<String, dynamic> getCustomSettingsStats() {
    try {
      int chatsWithCustomSettings = 0;
      int totalChats = _chats.length;
      
      for (final chat in _chats) {
        if (chat.hasCustomGenerationSettings) {
          chatsWithCustomSettings++;
        }
      }
      
      return {
        'totalChats': totalChats,
        'chatsWithCustomSettings': chatsWithCustomSettings,
        'percentageWithCustomSettings': totalChats > 0 
            ? (chatsWithCustomSettings / totalChats * 100).toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      AppLogger.error('Error getting custom settings stats', e);
      return {
        'error': e.toString(),
        'totalChats': _chats.length,
        'chatsWithCustomSettings': 0,
        'percentageWithCustomSettings': '0.0',
      };
    }
  }

  /// Notify listeners of chat list changes
  void _notifyListeners() {
    if (!_disposed && !_chatController.isClosed) {
      _chatController.add(_chats);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    if (!_chatController.isClosed) {
      await _chatController.close();
    }
  }
}
