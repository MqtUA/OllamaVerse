# OllamaVerse API Documentation

## Services

### CacheService
A service for caching frequently accessed data with expiration support.

```dart
class CacheService {
  Future<T?> get<T>(String key, T Function(Map<String, dynamic>) fromJson);
  Future<void> set<T>(String key, T data, Map<String, dynamic> Function(T) toJson, {Duration expiration});
  Future<void> remove(String key);
  Future<void> clear();
}
```

### StorageService
Handles non-sensitive data storage using SharedPreferences.

```dart
class StorageService {
  Future<void> saveSettings(AppSettings settings);
  Future<AppSettings> loadSettings();
  Future<void> saveLastSelectedModel(String modelName);
  Future<String> loadLastSelectedModel();
  Future<void> saveChat(Chat chat);
  Future<Chat?> loadChat(String chatId);
  Future<List<Chat>> loadAllChats();
  Future<void> deleteChat(String chatId);
}
```

### SecureStorageService
Handles sensitive data storage using flutter_secure_storage.

```dart
class SecureStorageService {
  Future<void> saveAuthToken(String token);
  Future<String?> getAuthToken();
  Future<void> deleteAuthToken();
}
```

### OllamaService
Handles communication with the Ollama API.

```dart
class OllamaService {
  Future<List<OllamaModel>> getModels();
  Future<void> updateSettings(AppSettings settings);
  Future<Stream<String>> generateResponse(String prompt, {List<Map<String, dynamic>>? context});
}
```

## Providers

### ChatProvider
Manages chat state and operations.

```dart
class ChatProvider extends ChangeNotifier {
  List<Chat> get chats;
  Chat? get activeChat;
  List<ChatMessage> get displayableMessages;
  List<OllamaModel> get availableModels;
  bool get isLoading;
  bool get isGenerating;
  String get error;

  Future<void> createNewChat([String? modelName]);
  void setActiveChat(String chatId);
  Future<void> updateChatTitle(String chatId, String newTitle);
  Future<void> updateChatModel(String chatId, String newModelName);
  Future<void> deleteChat(String chatId);
  Future<void> refreshModels();
  Future<void> sendMessage(String content, {List<String>? attachedFiles});
}
```

### SettingsProvider
Manages application settings.

```dart
class SettingsProvider extends ChangeNotifier {
  AppSettings get settings;
  ThemeMode get themeMode;

  Future<void> updateSettings(AppSettings newSettings);
  Future<void> updateThemeMode(ThemeMode mode);
  OllamaService getOllamaService();
}
```

## Models

### AppSettings
Application settings model.

```dart
class AppSettings {
  String ollamaHost;
  int ollamaPort;
  int contextLength;
  bool darkMode;
  double fontSize;
  bool showLiveResponse;
  String systemPrompt;
}
```

### Chat
Chat model with messages and metadata.

```dart
class Chat {
  String id;
  String title;
  String modelName;
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime lastUpdatedAt;
}
```

### ChatMessage
Individual chat message model.

```dart
class ChatMessage {
  String id;
  String content;
  bool isUser;
  DateTime timestamp;
  List<String>? attachedFiles;
  List<Map<String, dynamic>>? context;
}
```

### OllamaModel
Ollama model information.

```dart
class OllamaModel {
  String name;
  String description;
  int size;
  String format;
  String family;
  Map<String, dynamic> parameters;
}
```

## Widgets

### AnimatedTransition
Provides smooth transitions for content changes.

```dart
class AnimatedTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool show;
}
```

### AnimatedListTransition
Provides fade transitions for lists.

```dart
class AnimatedListTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool show;
}
```

### AnimatedMessageTransition
Provides slide transitions for messages.

```dart
class AnimatedMessageTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool isUser;
}
```

### AnimatedLoadingIndicator
Provides a loading animation.

```dart
class AnimatedLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;
}
```

## Utilities

### FileUtils
File handling utilities.

```dart
class FileUtils {
  static Future<List<String>> pickFiles();
  static Future<String?> saveFileToAppDirectory(File file, String fileName);
  static Future<void> cleanupOldFiles({Duration maxAge});
  static String getFileName(String filePath);
  static String getFileExtension(String filePath);
  static String getFileIconName(String filePath);
  static bool isImageFile(String filePath);
  static bool isPdfFile(String filePath);
  static bool isTextFile(String filePath);
  static Future<String?> extractTextFromPdf(String filePath);
}
```

### AppLogger
Logging utility.

```dart
class AppLogger {
  static Future<void> init();
  static void info(String message);
  static void warning(String message);
  static void error(String message, [Object? error, StackTrace? stackTrace]);
  static void debug(String message);
  static Future<void> clearLogs();
  static Future<int> getLogsSize();
}
``` 