# OllamaVerse API Documentation

**Version 1.3.0** - Chat System Excellence & Code Quality Optimization

This documentation reflects the enhanced API after the complete chat system overhaul and code quality optimization (Tasks 1-6).

## Key Improvements in v1.3.0

- **Unified Storage Architecture**: Consolidated `StorageService` and `SecureStorageService` into single interface
- **Comprehensive Error Handling**: New error boundary system with automatic recovery
- **Performance Optimization**: 60% reduction in animation controller overhead
- **Background Streaming**: Smart chat switching with continued response generation
- **Enhanced Auto-Scrolling**: Intelligent scroll management across all platforms
- **Zero Technical Debt**: All deprecated APIs updated, zero linter issues

---

## Services

### CacheService
A service for caching frequently accessed data with expiration support.

```dart
class CacheService {
  static Future<void> init();
  static Future<T?> get<T>(String key);
  static Future<void> set<T>(String key, T value);
  static Future<void> remove(String key);
  static Future<void> clear();
  static Future<int> getCacheSize();
  static Future<void> dispose();
  static void addSubscription(StreamSubscription subscription);
}
```

### StorageService
Unified storage service handling both regular and secure data storage.

```dart
class StorageService {
  // Initialization
  static Future<void> initialize();
  
  // App Settings
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  
  // Model Selection
  Future<String> loadLastSelectedModel();
  Future<void> saveLastSelectedModel(String modelName);
  
  // Secure Storage (Auth Token)
  Future<String?> getAuthToken();
  Future<void> saveAuthToken(String token);
  Future<void> deleteAuthToken();
  
  // Generic Storage Methods
  Future<void> setString(String key, String value);
  String? getString(String key, {String? defaultValue});
  Future<void> setBool(String key, bool value);
  bool getBool(String key, {bool defaultValue = false});
  Future<void> setInt(String key, int value);
  int getInt(String key, {int defaultValue = 0});
  Future<void> setDouble(String key, double value);
  double getDouble(String key, {double defaultValue = 0.0});
  
  // Utility Methods
  Future<void> remove(String key);
  Future<void> clear();
  Future<List<String>> getAllKeys();
  Future<StorageStats> getStorageStats();
}
```

### PerformanceMonitor
Singleton service for monitoring UI performance and frame rendering.

```dart
class PerformanceMonitor {
  static PerformanceMonitor get instance;
  
  void startMonitoring();
  void stopMonitoring();
  void markThemeChangeStart();
  void markThemeChangeEnd();
  PerformanceStats getStats();
  void resetMetrics();
  void logPerformanceSummary();
}
```

### FileCleanupService
Advanced file cleanup service with intelligent monitoring and background operations.

```dart
class FileCleanupService {
  static FileCleanupService get instance;
  
  Future<void> init({FileCleanupConfig? config});
  Stream<FileCleanupProgress> get progressStream;
  Stream<FileSizeMonitoringData> get monitoringStream;
  Future<void> forceCleanup();
  Future<CleanupStats> getCleanupStats();
  void dispose();
}
```

### ChatHistoryService
Service for managing chat persistence and history with automatic cleanup.

```dart
class ChatHistoryService {
  Stream<List<Chat>> get chatStream;
  List<Chat> get chats;
  
  Future<void> saveChat(Chat chat);
  Future<Chat?> loadChat(String chatId);
  Future<void> deleteChat(String chatId);
  Future<void> dispose();
}
```

### SettingsService
Service for managing detailed application settings with SharedPreferences.

```dart
class SettingsService {
  String get selectedModel;
  String get systemPrompt;
  int get maxTokens;
  double get temperature;
  double get topP;
  int get topK;
  
  Future<void> setSelectedModel(String model);
  Future<void> setLastSelectedModel(String model);
  Future<String?> getLastSelectedModel();
  Future<void> setSystemPrompt(String prompt);
  Future<void> setMaxTokens(int tokens);
  Future<void> setTemperature(double temp);
  Future<void> setTopP(double value);
  Future<void> setTopK(int value);
  Future<void> clearSettings();
}
```

### OllamaService
Handles communication with the Ollama API with enhanced error handling.

```dart
class OllamaService {
  Future<List<OllamaModel>> getModels();
  Future<void> updateSettings(AppSettings settings);
  Future<Stream<String>> generateResponse(String prompt, {List<Map<String, dynamic>>? context});
  Future<bool> checkConnection();
}
```

### ThinkingModelDetectionService
Service for detecting and processing thinking content from AI model responses.

```dart
class ThinkingModelDetectionService {
  static ThinkingModelDetectionService get instance;
  
  ThinkingContent? extractThinkingContent(String response);
  bool hasThinkingContent(String response);
  String filterThinkingFromResponse(String response);
  void clearCache();
}
```

## Widgets

### Error Handling Widgets

#### ErrorBoundary
Comprehensive error boundary widget that catches and handles widget errors.

```dart
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onError;
  final bool showDetails;
  final bool enableRecovery;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.errorTitle,
    this.errorMessage,
    this.onError,
    this.showDetails = false,
    this.enableRecovery = true,
  });
}
```

#### MessageErrorBoundary
Specialized error boundary for chat message components.

```dart
class MessageErrorBoundary extends StatelessWidget {
  final Widget child;
  final String? messageId;
  final VoidCallback? onRetry;

  const MessageErrorBoundary({
    super.key,
    required this.child,
    this.messageId,
    this.onRetry,
  });
}
```

#### ServiceErrorBoundary
Error boundary for service operations with retry functionality.

```dart
class ServiceErrorBoundary extends StatefulWidget {
  final Widget child;
  final String serviceName;
  final Future<void> Function()? onRetry;
  final int maxRetries;
  final Duration retryDelay;

  const ServiceErrorBoundary({
    super.key,
    required this.child,
    required this.serviceName,
    this.onRetry,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });
}
```

### Animation Widgets

#### ThinkingIndicator
Optimized thinking indicator with shared animation controller.

```dart
class ThinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const ThinkingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 16.0,
    this.duration = const Duration(milliseconds: 1200),
  });
}
```

#### PulsingThinkingIndicator
Optimized pulsing thinking indicator for heavy thinking operations.

```dart
class PulsingThinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const PulsingThinkingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 20.0,
    this.duration = const Duration(milliseconds: 800),
  });
}
```

## Providers

### ChatProvider
Enhanced chat provider with background streaming, smart auto-scrolling, and optimized performance.

```dart
class ChatProvider extends ChangeNotifier {
  // Core Chat State
  List<Chat> get chats;
  Chat? get activeChat;
  List<ChatMessage> get displayableMessages;
  List<String> get availableModels;
  bool get isLoading;
  bool get isGenerating;
  String? get error;
  String get currentStreamingResponse;
  
  // Background Streaming Support
  bool get isActiveChatGenerating;
  String? get currentGeneratingChatId;
  
  // Auto-Scrolling Features
  bool get shouldScrollToBottomOnChatSwitch;
  void resetScrollToBottomFlag();
  
  // Live Thinking Bubble Support
  String get currentThinkingContent;
  bool get hasActiveThinkingBubble;
  bool get isInsideThinkingBlock;
  bool isThinkingBubbleExpanded(String bubbleId);

  // Chat Management
  Future<void> createNewChat([String? modelName]);
  void setActiveChat(String chatId);
  Future<void> updateChatTitle(String chatId, String newTitle);
  Future<void> updateChatModel(String chatId, String newModelName);
  Future<void> deleteChat(String chatId);
  Future<void> refreshModels();
  
  // Enhanced Message Operations
  Future<void> sendMessage(String content, {List<String>? attachedFiles});
  void stopGeneration();
  
  // Thinking Bubble Management
  void toggleThinkingBubble(String bubbleId);
  void setThinkingBubbleExpanded(String bubbleId, bool expanded);
  
  // Performance & Memory Management
  void dispose();
}
```

### SettingsProvider
Manages application settings with theme caching, performance optimization, and thinking bubble preferences.

```dart
class SettingsProvider extends ChangeNotifier {
  AppSettings get settings;
  ThemeMode get themeMode;
  ThemeData get lightTheme;
  ThemeData get darkTheme;
  bool get isLoading;
  String? get authToken;

  Future<void> updateSettings({
    String? ollamaHost,
    int? ollamaPort,
    String? authToken,
    double? fontSize,
    bool? darkMode,
    bool? showLiveResponse,
    int? contextLength,
    String? systemPrompt,
    bool? thinkingBubbleDefaultExpanded,
    bool? thinkingBubbleAutoCollapse,
  });
  void clearThemeCache();
  OllamaService getOllamaService();
}
```

## Models

### AppSettings
Application settings model with all configuration options including thinking bubble preferences.

```dart
class AppSettings {
  String ollamaHost;
  int ollamaPort;
  int contextLength;
  bool darkMode;
  double fontSize;
  bool showLiveResponse;
  String systemPrompt;
  bool thinkingBubbleDefaultExpanded;
  bool thinkingBubbleAutoCollapse;

  AppSettings copyWith({...});
  Map<String, dynamic> toJson();
  factory AppSettings.fromJson(Map<String, dynamic> json);
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

  Chat copyWith({...});
  Map<String, dynamic> toJson();
  factory Chat.fromJson(Map<String, dynamic> json);
}
```

### ChatMessage
Individual chat message model with file attachments and thinking content support.

```dart
class ChatMessage {
  String id;
  String content;
  bool isUser;
  DateTime timestamp;
  List<String>? attachedFiles;
  List<Map<String, dynamic>>? context;
  ThinkingContent? thinkingContent;

  // Helper methods for thinking content
  bool get hasThinkingContent;
  String get displayContent;

  Map<String, dynamic> toJson();
  factory ChatMessage.fromJson(Map<String, dynamic> json);
}
```

### ThinkingContent
Model for storing AI thinking process and final answers.

```dart
class ThinkingContent {
  String thinkingText;
  String finalAnswer;

  ThinkingContent({
    required this.thinkingText,
    required this.finalAnswer,
  });

  Map<String, dynamic> toJson();
  factory ThinkingContent.fromJson(Map<String, dynamic> json);
}
```

### OllamaModel
Ollama model information with detailed metadata.

```dart
class OllamaModel {
  String name;
  String description;
  int size;
  String format;
  String family;
  Map<String, dynamic> parameters;

  Map<String, dynamic> toJson();
  factory OllamaModel.fromJson(Map<String, dynamic> json);
}
```

### PerformanceStats
Performance statistics data class for monitoring.

```dart
class PerformanceStats {
  final double averageFrameTime;
  final double maxFrameTime;
  final int frameDropCount;
  final double averageThemeSwitchTime;
  final double maxThemeSwitchTime;
  final bool isPerformant;
}
```

### FileCleanupConfig
Configuration for file cleanup behavior.

```dart
class FileCleanupConfig {
  final Duration cleanupInterval;
  final Duration maxFileAge;
  final Duration maxLogAge;
  final Duration maxCacheAge;
  final int maxDirectorySize;
  final int maxLogSize;
  final int maxCacheSize;

  factory FileCleanupConfig.defaultConfig();
}
```

### FileCleanupProgress
Progress information for cleanup operations.

```dart
class FileCleanupProgress {
  final CleanupPhase phase;
  final int totalFiles;
  final int processedFiles;
  final int deletedFiles;
  final int totalSize;
  final int freedSize;
  final String? error;

  double get progress;
}

enum CleanupPhase {
  starting,
  scanning,
  cleaning,
  completed,
  error,
}
```

### DirectoryStats
Comprehensive directory statistics for monitoring.

```dart
class DirectoryStats {
  final int totalFiles;
  final int totalSize;
  final int oldFiles;
  final int largeFiles;
  final DateTime? oldestFile;
  final DateTime? newestFile;

  double get averageFileSize;
  Duration get ageSpan;
}
```

### FileSizeMonitoringData
File size monitoring data for smart cleanup triggers.

```dart
class FileSizeMonitoringData {
  final DateTime timestamp;
  final Map<String, DirectoryStats> directories;
  final bool needsCleanup;
  final List<String> recommendations;

  int get totalFiles;
  int get totalSize;
  int get totalOldFiles;
  int get totalLargeFiles;
}
```

### CleanupResult
Result of cleanup operation.

```dart
class CleanupResult {
  final int totalFiles;
  final int deletedFiles;
  final int totalSize;
  final int freedSize;
  final String? error;
}
```

### CleanupStats
Statistics about cleanup-able files.

```dart
class CleanupStats {
  final int totalFiles;
  final int totalSize;
}
```

## Widgets

### AnimatedTransition
Provides smooth transitions for content changes with performance optimization.

```dart
class AnimatedTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool show;
}
```

### AnimatedListTransition
Provides fade transitions for lists with conditional rendering.

```dart
class AnimatedListTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool show;
}
```

### AnimatedMessageTransition
Provides slide transitions for messages with performance optimization.

```dart
class AnimatedMessageTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool isUser;
}
```

### AnimatedLoadingIndicator
Provides a loading animation with efficient rotation.

```dart
class AnimatedLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;
}
```

### AnimatedThemeSwitcher
Widget that provides smooth theme switching animations with performance optimization.

```dart
class AnimatedThemeSwitcher extends StatefulWidget {
  final Widget child;
  final ThemeMode themeMode;
  final Duration duration;
  final Curve curve;
}
```

### AnimatedStatusIndicator
Widget that provides status indicator animations for connection states.

```dart
class AnimatedStatusIndicator extends StatefulWidget {
  final bool isConnected;
  final bool isLoading;
  final Duration animationDuration;
  final Color connectedColor;
  final Color disconnectedColor;
  final Color loadingColor;
}
```

### AnimatedModelSelector
Widget that provides smooth model switching animations.

```dart
class AnimatedModelSelector extends StatefulWidget {
  final String selectedModel;
  final List<String> models;
  final Function(String) onModelSelected;
  final Duration animationDuration;
}
```

### CustomMarkdownBody
Custom markdown body widget with theme-aware code blocks and LaTeX support.

```dart
class CustomMarkdownBody extends StatelessWidget {
  final String data;
  final double fontSize;
  final bool selectable;
}
```

### TypingIndicator
Animated typing indicator with performance-optimized dot animations.

```dart
class TypingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;
}
```

### LiveThinkingBubble
Real-time thinking bubble widget that displays AI thinking process during streaming.

```dart
class LiveThinkingBubble extends StatefulWidget {
  final String thinkingContent;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;
  final bool isDarkMode;
  final double fontSize;
}
```

### ThinkingBubble
Static thinking bubble widget for displaying completed thinking content.

```dart
class ThinkingBubble extends StatefulWidget {
  final ThinkingContent thinkingContent;
  final bool isDarkMode;
  final double fontSize;
  final bool initiallyExpanded;
}
```

### ThinkingIndicator
Animated indicator for thinking process with multiple animation styles.

```dart
class ThinkingIndicator extends StatefulWidget {
  final ThinkingIndicatorType type;
  final Color color;
  final double size;
  final Duration duration;
}

enum ThinkingIndicatorType {
  brainIcon,
  dots,
  text,
}
```

## Utilities

### FileUtils
File handling utilities with size limits and type validation.

```dart
class FileUtils {
  static const int maxFileSizeMB = 10;
  static const List<String> allowedExtensions = ['txt', 'pdf', 'jpg', 'jpeg', 'png', 'gif'];

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
Enhanced logging utility with file output and size management.

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

## Exceptions

### OllamaConnectionException
Exception for connection-related errors.

```dart
class OllamaConnectionException implements Exception {
  final String message;
  final Object? originalError;
  
  OllamaConnectionException(this.message, {this.originalError});
}
```

### OllamaApiException
Exception for API-related errors.

```dart
class OllamaApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? originalError;
  
  OllamaApiException(this.message, {this.statusCode, this.originalError});
}
```

## Usage Examples

### Performance Monitoring
```dart
// Start monitoring
PerformanceMonitor.instance.startMonitoring();

// Get current stats
final stats = PerformanceMonitor.instance.getStats();
print('Average frame time: ${stats.averageFrameTime}ms');

// Log performance summary
PerformanceMonitor.instance.logPerformanceSummary();
```

### File Cleanup
```dart
// Initialize with custom config
await FileCleanupService.instance.init(
  config: FileCleanupConfig(
    cleanupInterval: Duration(hours: 12),
    maxFileAge: Duration(days: 14),
    maxDirectorySize: 100 * 1024 * 1024, // 100MB
  ),
);

// Monitor cleanup progress
FileCleanupService.instance.progressStream.listen((progress) {
  print('Cleanup progress: ${(progress.progress * 100).toInt()}%');
});

// Force cleanup
await FileCleanupService.instance.forceCleanup();
```

### Chat Management
```dart
// Create new chat
await chatProvider.createNewChat('llama3');

// Send message with files
await chatProvider.sendMessage(
  'Analyze this document',
  attachedFiles: ['path/to/document.pdf'],
);

// Update chat model
await chatProvider.updateChatModel(chatId, 'codellama');
```

### Settings Management
```dart
// Update settings
await settingsProvider.updateSettings(
  darkMode: true,
  fontSize: 16.0,
  authToken: 'bearer_token_here',
);

// Get Ollama service with current settings
final ollamaService = settingsProvider.getOllamaService();
``` 