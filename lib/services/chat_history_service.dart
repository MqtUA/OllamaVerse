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

  DateTime? _lastCleanup;
  Timer? _cleanupTimer;

  ChatHistoryService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadChats();
      _startCleanupTimer();
    } catch (e) {
      AppLogger.error('Error initializing chat history service', e);
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
        _chatController.add(_chats);
        return;
      }

      final List<Chat> loadedChats = [];
      final files = await chatsDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final chat = Chat.fromJson(jsonDecode(content));
            loadedChats.add(chat);
          } catch (e) {
            AppLogger.error('Error parsing chat file', e);
          }
        }
      }

      // Sort chats by most recent first
      loadedChats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

      // Limit the number of chats
      _chats = loadedChats.take(_maxChats).toList();
      _chatController.add(_chats);
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
      // Validate chat data
      if (!_isValidChat(chat)) {
        throw Exception('Invalid chat data');
      }

      final chatsDir = await _getChatsDirectory();
      final file = File('${chatsDir.path}/${chat.id}.json');

      // Ensure the chat directory exists
      if (!await chatsDir.exists()) {
        await chatsDir.create(recursive: true);
      }

      // Save the chat to file
      await file.writeAsString(jsonEncode(chat.toJson()));

      // Update in-memory list
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index >= 0) {
        _chats[index] = chat;
      } else {
        _chats.insert(0, chat);
        // Ensure we don't exceed the maximum number of chats
        if (_chats.length > _maxChats) {
          _chats = _chats.take(_maxChats).toList();
        }
      }

      // Sort chats by most recent first
      _chats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

      // Notify listeners
      _chatController.add(_chats);
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
        return Chat.fromJson(jsonDecode(chatJson));
      }

      return null;
    } catch (e) {
      AppLogger.error('Error loading chat', e);
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
      _chatController.add(_chats);
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
    return true;
  }

  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    await _chatController.close();
  }
}
