import 'streaming_state.dart';
import 'thinking_state.dart';
import '../services/file_content_processor.dart';

/// State container for all chat operations
/// Manages generation, file processing, title generation, and streaming states
class ChatOperationState {
  final bool isGenerating;
  final bool isSendingMessage;
  final bool isProcessingFiles;
  final String? currentGeneratingChatId;
  final StreamingState streamingState;
  final ThinkingState thinkingState;
  final TitleGenerationState titleState;
  final Map<String, FileProcessingProgress> fileProcessingProgress;
  final bool shouldScrollToBottomOnChatSwitch;

  const ChatOperationState({
    required this.isGenerating,
    required this.isSendingMessage,
    required this.isProcessingFiles,
    this.currentGeneratingChatId,
    required this.streamingState,
    required this.thinkingState,
    required this.titleState,
    required this.fileProcessingProgress,
    required this.shouldScrollToBottomOnChatSwitch,
  });

  /// Create initial operation state
  factory ChatOperationState.initial() {
    return ChatOperationState(
      isGenerating: false,
      isSendingMessage: false,
      isProcessingFiles: false,
      currentGeneratingChatId: null,
      streamingState: StreamingState.initial(),
      thinkingState: ThinkingState.initial(),
      titleState: TitleGenerationState.initial(),
      fileProcessingProgress: const {},
      shouldScrollToBottomOnChatSwitch: false,
    );
  }

  /// Create a copy with updated fields
  ChatOperationState copyWith({
    bool? isGenerating,
    bool? isSendingMessage,
    bool? isProcessingFiles,
    String? currentGeneratingChatId,
    StreamingState? streamingState,
    ThinkingState? thinkingState,
    TitleGenerationState? titleState,
    Map<String, FileProcessingProgress>? fileProcessingProgress,
    bool? shouldScrollToBottomOnChatSwitch,
    bool clearCurrentGeneratingChatId = false,
  }) {
    return ChatOperationState(
      isGenerating: isGenerating ?? this.isGenerating,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      isProcessingFiles: isProcessingFiles ?? this.isProcessingFiles,
      currentGeneratingChatId: clearCurrentGeneratingChatId
          ? null
          : (currentGeneratingChatId ?? this.currentGeneratingChatId),
      streamingState: streamingState ?? this.streamingState,
      thinkingState: thinkingState ?? this.thinkingState,
      titleState: titleState ?? this.titleState,
      fileProcessingProgress:
          fileProcessingProgress ?? this.fileProcessingProgress,
      shouldScrollToBottomOnChatSwitch:
          shouldScrollToBottomOnChatSwitch ?? this.shouldScrollToBottomOnChatSwitch,
    );
  }

  /// Check if any operation is in progress
  bool get isAnyOperationInProgress =>
      isGenerating || isSendingMessage || isProcessingFiles;

  /// Check if a specific chat is generating
  bool isChatGenerating(String chatId) =>
      isGenerating && currentGeneratingChatId == chatId;

  /// Check if title generation is in progress
  bool get isGeneratingTitle => titleState.isGeneratingTitle;

  /// Check if a specific chat is generating title
  bool isChatGeneratingTitle(String chatId) =>
      titleState.isChatGeneratingTitle(chatId);

  /// Reset all operation states
  ChatOperationState reset() {
    return ChatOperationState.initial();
  }

  /// Reset streaming and thinking states while keeping other operations
  ChatOperationState resetStreamingStates() {
    return copyWith(
      streamingState: StreamingState.initial(),
      thinkingState: ThinkingState.initial(),
      clearCurrentGeneratingChatId: true,
    );
  }

  /// Start generation for a specific chat
  ChatOperationState startGeneration(String chatId) {
    return copyWith(
      isGenerating: true,
      isSendingMessage: true,
      currentGeneratingChatId: chatId,
    );
  }

  /// Stop generation
  ChatOperationState stopGeneration() {
    return copyWith(
      isGenerating: false,
      isSendingMessage: false,
      clearCurrentGeneratingChatId: true,
      streamingState: StreamingState.initial(),
      thinkingState: thinkingState.clearCurrentThinking(),
    );
  }

  /// Start file processing
  ChatOperationState startFileProcessing() {
    return copyWith(isProcessingFiles: true);
  }

  /// Stop file processing
  ChatOperationState stopFileProcessing() {
    return copyWith(
      isProcessingFiles: false,
      fileProcessingProgress: const {},
    );
  }

  /// Update file processing progress
  ChatOperationState updateFileProgress(
      String fileName, FileProcessingProgress progress) {
    final newProgress = Map<String, FileProcessingProgress>.from(
        fileProcessingProgress);
    newProgress[fileName] = progress;
    return copyWith(fileProcessingProgress: newProgress);
  }

  /// Remove file processing progress
  ChatOperationState removeFileProgress(String fileName) {
    final newProgress = Map<String, FileProcessingProgress>.from(
        fileProcessingProgress);
    newProgress.remove(fileName);
    return copyWith(fileProcessingProgress: newProgress);
  }

  /// Validation
  bool get isValid => _validateState();

  bool _validateState() {
    // If generating, should have a chat ID
    if (isGenerating && currentGeneratingChatId == null) {
      return false;
    }

    // If not generating, shouldn't have a generating chat ID
    if (!isGenerating && currentGeneratingChatId != null) {
      return false;
    }

    // Validate nested states
    if (!streamingState.isValid || !thinkingState.isValid) {
      return false;
    }

    return true;
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'isGenerating': isGenerating,
      'isSendingMessage': isSendingMessage,
      'isProcessingFiles': isProcessingFiles,
      'currentGeneratingChatId': currentGeneratingChatId,
      'streamingState': streamingState.toJson(),
      'thinkingState': thinkingState.toJson(),
      'titleState': titleState.toJson(),
      'fileProcessingProgress': fileProcessingProgress
          .map((key, value) => MapEntry(key, value.toJson())),
      'shouldScrollToBottomOnChatSwitch': shouldScrollToBottomOnChatSwitch,
    };
  }

  /// Create from JSON
  factory ChatOperationState.fromJson(Map<String, dynamic> json) {
    final fileProgressMap = <String, FileProcessingProgress>{};
    if (json['fileProcessingProgress'] != null) {
      final progressJson =
          json['fileProcessingProgress'] as Map<String, dynamic>;
      for (final entry in progressJson.entries) {
        fileProgressMap[entry.key] =
            FileProcessingProgress.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return ChatOperationState(
      isGenerating: json['isGenerating'] as bool? ?? false,
      isSendingMessage: json['isSendingMessage'] as bool? ?? false,
      isProcessingFiles: json['isProcessingFiles'] as bool? ?? false,
      currentGeneratingChatId: json['currentGeneratingChatId'] as String?,
      streamingState: json['streamingState'] != null
          ? StreamingState.fromJson(
              json['streamingState'] as Map<String, dynamic>)
          : StreamingState.initial(),
      thinkingState: json['thinkingState'] != null
          ? ThinkingState.fromJson(
              json['thinkingState'] as Map<String, dynamic>)
          : ThinkingState.initial(),
      titleState: json['titleState'] != null
          ? TitleGenerationState.fromJson(
              json['titleState'] as Map<String, dynamic>)
          : TitleGenerationState.initial(),
      fileProcessingProgress: fileProgressMap,
      shouldScrollToBottomOnChatSwitch:
          json['shouldScrollToBottomOnChatSwitch'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ChatOperationState('
        'isGenerating: $isGenerating, '
        'isSendingMessage: $isSendingMessage, '
        'isProcessingFiles: $isProcessingFiles, '
        'currentGeneratingChatId: $currentGeneratingChatId, '
        'streamingState: $streamingState, '
        'thinkingState: $thinkingState'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatOperationState &&
        other.isGenerating == isGenerating &&
        other.isSendingMessage == isSendingMessage &&
        other.isProcessingFiles == isProcessingFiles &&
        other.currentGeneratingChatId == currentGeneratingChatId &&
        other.streamingState == streamingState &&
        other.thinkingState == thinkingState &&
        other.titleState == titleState &&
        other.shouldScrollToBottomOnChatSwitch == shouldScrollToBottomOnChatSwitch;
  }

  @override
  int get hashCode {
    return Object.hash(
      isGenerating,
      isSendingMessage,
      isProcessingFiles,
      currentGeneratingChatId,
      streamingState,
      thinkingState,
      titleState,
      shouldScrollToBottomOnChatSwitch,
    );
  }
}

/// State container for title generation operations
class TitleGenerationState {
  final bool isGeneratingTitle;
  final Set<String> chatsGeneratingTitle;

  const TitleGenerationState({
    required this.isGeneratingTitle,
    required this.chatsGeneratingTitle,
  });

  /// Create initial title generation state
  factory TitleGenerationState.initial() {
    return const TitleGenerationState(
      isGeneratingTitle: false,
      chatsGeneratingTitle: {},
    );
  }

  /// Create a copy with updated fields
  TitleGenerationState copyWith({
    bool? isGeneratingTitle,
    Set<String>? chatsGeneratingTitle,
  }) {
    return TitleGenerationState(
      isGeneratingTitle: isGeneratingTitle ?? this.isGeneratingTitle,
      chatsGeneratingTitle: chatsGeneratingTitle ?? this.chatsGeneratingTitle,
    );
  }

  /// Start title generation for a chat
  TitleGenerationState startTitleGeneration(String chatId) {
    final newChats = Set<String>.from(chatsGeneratingTitle);
    newChats.add(chatId);
    return copyWith(
      isGeneratingTitle: true,
      chatsGeneratingTitle: newChats,
    );
  }

  /// Stop title generation for a chat
  TitleGenerationState stopTitleGeneration(String chatId) {
    final newChats = Set<String>.from(chatsGeneratingTitle);
    newChats.remove(chatId);
    return copyWith(
      isGeneratingTitle: newChats.isNotEmpty,
      chatsGeneratingTitle: newChats,
    );
  }

  /// Check if a specific chat is generating title
  bool isChatGeneratingTitle(String chatId) {
    return chatsGeneratingTitle.contains(chatId);
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'isGeneratingTitle': isGeneratingTitle,
      'chatsGeneratingTitle': chatsGeneratingTitle.toList(),
    };
  }

  /// Create from JSON
  factory TitleGenerationState.fromJson(Map<String, dynamic> json) {
    return TitleGenerationState(
      isGeneratingTitle: json['isGeneratingTitle'] as bool? ?? false,
      chatsGeneratingTitle: Set<String>.from(
          json['chatsGeneratingTitle'] as List<dynamic>? ?? []),
    );
  }

  @override
  String toString() {
    return 'TitleGenerationState('
        'isGeneratingTitle: $isGeneratingTitle, '
        'chatsGeneratingTitle: ${chatsGeneratingTitle.length}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TitleGenerationState &&
        other.isGeneratingTitle == isGeneratingTitle &&
        _setEquals(other.chatsGeneratingTitle, chatsGeneratingTitle);
  }

  @override
  int get hashCode {
    return Object.hash(isGeneratingTitle, chatsGeneratingTitle.length);
  }

  /// Helper method to compare sets
  bool _setEquals(Set<String> set1, Set<String> set2) {
    if (set1.length != set2.length) return false;
    return set1.every(set2.contains);
  }
}