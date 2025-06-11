import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/app_settings.dart';
import '../utils/logger.dart';

class StorageService {
  // Constants
  static const String settingsKey = 'app_settings';
  static const String chatsDir = 'chats';
  static const String lastSelectedModelKey = 'last_selected_model';

  // Save app settings
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  // Load app settings
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(settingsKey);
    
    if (settingsJson != null) {
      try {
        return AppSettings.fromJson(jsonDecode(settingsJson));
      } catch (e) {
        AppLogger.error('Error loading settings', e);
        return AppSettings();
      }
    }
    
    return AppSettings(); // Return default settings
  }
  
  // Save last selected model
  Future<void> saveLastSelectedModel(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastSelectedModelKey, modelName);
  }
  
  // Load last selected model
  Future<String> loadLastSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastSelectedModelKey) ?? '';
  }

  // Get chats directory
  Future<Directory> _getChatsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatsDirPath = Directory('${appDir.path}/${StorageService.chatsDir}');
    
    if (!await chatsDirPath.exists()) {
      await chatsDirPath.create(recursive: true);
    }
    
    return chatsDirPath;
  }

  // Save a chat
  Future<void> saveChat(Chat chat) async {
    final chatsDir = await _getChatsDirectory();
    final file = File('${chatsDir.path}/${chat.id}.json');
    await file.writeAsString(jsonEncode(chat.toJson()));
  }

  // Load a specific chat
  Future<Chat?> loadChat(String chatId) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final file = File('${chatsDir.path}/$chatId.json');
      
      if (await file.exists()) {
        final chatJson = await file.readAsString();
        try {
          return Chat.fromJson(jsonDecode(chatJson));
        } catch (e) {
          AppLogger.error('Error parsing chat file', e);
          return null;
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.error('Error loading chat', e);
      return null;
    }
  }

  // Load all chats
  Future<List<Chat>> loadAllChats() async {
    try {
      final chatsDir = await _getChatsDirectory();
      
      if (!await chatsDir.exists()) {
        return [];
      }
      
      final List<Chat> chats = [];
      final files = await chatsDir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final content = await file.readAsString();
          try {
            final chat = Chat.fromJson(jsonDecode(content));
            chats.add(chat);
          } catch (e) {
            AppLogger.error('Error parsing chat file', e);
          }
        }
      }
      
      // Sort chats by most recent first
      chats.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
      
      return chats;
    } catch (e) {
      AppLogger.error('Error loading chats', e);
      throw Exception('Failed to load chats: $e');
    }
  }

  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    try {
      final chatsDir = await _getChatsDirectory();
      final chatFile = File('${chatsDir.path}/$chatId.json');
      
      if (await chatFile.exists()) {
        await chatFile.delete();
      }
    } catch (e) {
      AppLogger.error('Error deleting chat', e);
      throw Exception('Failed to delete chat: $e');
    }
  }
}
