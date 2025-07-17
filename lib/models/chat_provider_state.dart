import 'chat.dart';
import 'chat_operation_state.dart';

/// Main state container for the ChatProvider
/// Contains all the high-level state information needed by the UI
class ChatProviderState {
  final List<Chat> chats;
  final Chat? activeChat;
  final List<String> availableModels;
  final bool isLoading;
  final String? error;
  final String lastSelectedModel;
  final ChatOperationState operationState;

  const ChatProviderState({
    required this.chats,
    this.activeChat,
    required this.availableModels,
    required this.isLoading,
    this.error,
    required this.lastSelectedModel,
    required this.operationState,
  });

  /// Create initial state
  factory ChatProviderState.initial() {
    return ChatProviderState(
      chats: const [],
      activeChat: null,
      availableModels: const [],
      isLoading: true,
      error: null,
      lastSelectedModel: '',
      operationState: ChatOperationState.initial(),
    );
  }

  /// Create a copy with updated fields
  ChatProviderState copyWith({
    List<Chat>? chats,
    Chat? activeChat,
    List<String>? availableModels,
    bool? isLoading,
    String? error,
    String? lastSelectedModel,
    ChatOperationState? operationState,
    bool clearError = false,
    bool clearActiveChat = false,
  }) {
    return ChatProviderState(
      chats: chats ?? this.chats,
      activeChat: clearActiveChat ? null : (activeChat ?? this.activeChat),
      availableModels: availableModels ?? this.availableModels,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastSelectedModel: lastSelectedModel ?? this.lastSelectedModel,
      operationState: operationState ?? this.operationState,
    );
  }

  /// Check if any operation is in progress
  bool get isAnyOperationInProgress => operationState.isAnyOperationInProgress;

  /// Check if the currently active chat is the one that's generating
  bool get isActiveChatGenerating =>
      operationState.isGenerating &&
      operationState.currentGeneratingChatId == activeChat?.id;

  /// Check if the active chat has any operation in progress
  bool get isActiveChatBusy =>
      isAnyOperationInProgress &&
      operationState.currentGeneratingChatId == activeChat?.id;

  /// Validation methods
  bool get isValid => _validateState();

  bool _validateState() {
    // Basic validation rules
    if (chats.isEmpty && activeChat != null) {
      return false; // Can't have active chat without any chats
    }

    if (activeChat != null && !chats.contains(activeChat)) {
      return false; // Active chat must be in the chats list
    }

    if (availableModels.isNotEmpty &&
        lastSelectedModel.isNotEmpty &&
        !availableModels.contains(lastSelectedModel)) {
      return false; // Last selected model should be available
    }

    return true;
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'chats': chats.map((chat) => chat.toJson()).toList(),
      'activeChat': activeChat?.toJson(),
      'availableModels': availableModels,
      'isLoading': isLoading,
      'error': error,
      'lastSelectedModel': lastSelectedModel,
      'operationState': operationState.toJson(),
    };
  }

  /// Create from JSON
  factory ChatProviderState.fromJson(Map<String, dynamic> json) {
    final chats = (json['chats'] as List<dynamic>?)
            ?.map((chatJson) => Chat.fromJson(chatJson as Map<String, dynamic>))
            .toList() ??
        [];

    Chat? activeChat;
    if (json['activeChat'] != null) {
      activeChat = Chat.fromJson(json['activeChat'] as Map<String, dynamic>);
    }

    return ChatProviderState(
      chats: chats,
      activeChat: activeChat,
      availableModels: List<String>.from(json['availableModels'] ?? []),
      isLoading: json['isLoading'] as bool? ?? true,
      error: json['error'] as String?,
      lastSelectedModel: json['lastSelectedModel'] as String? ?? '',
      operationState: json['operationState'] != null
          ? ChatOperationState.fromJson(
              json['operationState'] as Map<String, dynamic>)
          : ChatOperationState.initial(),
    );
  }

  @override
  String toString() {
    return 'ChatProviderState('
        'chats: ${chats.length}, '
        'activeChat: ${activeChat?.id}, '
        'isLoading: $isLoading, '
        'error: $error, '
        'operationState: $operationState'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatProviderState &&
        other.chats.length == chats.length &&
        other.activeChat?.id == activeChat?.id &&
        other.availableModels.length == availableModels.length &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.lastSelectedModel == lastSelectedModel &&
        other.operationState == operationState;
  }

  @override
  int get hashCode {
    return Object.hash(
      chats.length,
      activeChat?.id,
      availableModels.length,
      isLoading,
      error,
      lastSelectedModel,
      operationState,
    );
  }
}