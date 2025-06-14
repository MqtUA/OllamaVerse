import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/file_utils.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/custom_markdown_body.dart';
import '../widgets/markdown_title.dart';
import '../widgets/model_selector.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/thinking_bubble.dart';
import '../widgets/thinking_indicator.dart';
import '../widgets/live_thinking_bubble.dart';
import '../theme/dracula_theme.dart';
import '../theme/material_light_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  List<String> _attachedFiles = [];
  bool _isCtrlPressed = false;
  bool _userHasScrolled = false;
  bool _isSendingMessage = false; // Prevent duplicate sends

  // Cache provider reference to avoid unsafe lookups during dispose
  ChatProvider? _chatProvider;

  @override
  void initState() {
    super.initState();

    // Add a scroll listener to detect when the user has manually scrolled
    _scrollController.addListener(_onScrollChange);

    // Add a listener to the chat provider to handle autoscrolling during message generation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatProvider = Provider.of<ChatProvider>(context, listen: false);
        _chatProvider?.addListener(_handleChatProviderChanges);
      }
    });
    // Add keyboard listener for Ctrl+Enter
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        ServicesBinding.instance.keyboard.addHandler(_handleKeyPress);
      } else {
        ServicesBinding.instance.keyboard.removeHandler(_handleKeyPress);
      }
    });
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight) {
        setState(() {
          _isCtrlPressed = true;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter &&
          _isCtrlPressed) {
        // Only handle if the message field has focus
        if (_messageFocusNode.hasFocus) {
          _sendMessage();
          return true;
        }
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight) {
        setState(() {
          _isCtrlPressed = false;
        });
      }
    }
    return false;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyPress);

    // Safe disposal - use cached provider reference
    _chatProvider?.removeListener(_handleChatProviderChanges);
    _chatProvider = null;

    super.dispose();
  }

  // Handle changes in the chat provider for autoscrolling during message generation
  void _handleChatProviderChanges() {
    // Use cached provider reference to avoid unsafe lookups
    final chatProvider = _chatProvider;
    if (chatProvider == null || !mounted) return;

    // Check if we should scroll to bottom due to chat switching
    if (chatProvider.shouldScrollToBottomOnChatSwitch) {
      // Reset user scroll flag since we're switching chats
      setState(() {
        _userHasScrolled = false;
      });

      // Scroll to bottom with a delay to ensure UI is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add extra delay for startup case to ensure full rendering
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scrollController.hasClients) {
            // Use jumpTo for immediate positioning when switching chats
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
            // Reset the flag after scrolling
            chatProvider.resetScrollToBottomFlag();
          }
        });
      });
    }

    // Simple auto-scroll during generation: if generating and user hasn't scrolled, scroll to bottom
    if (chatProvider.isActiveChatGenerating && !_userHasScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scrollController.hasClients &&
            chatProvider.isActiveChatGenerating &&
            !_userHasScrolled) {
          final position = _scrollController.position;
          final maxExtent = position.maxScrollExtent;
          if (maxExtent > 0) {
            _scrollController.jumpTo(maxExtent);
          }
        }
      });
    }
  }

  // Improved scroll detection with auto-scroll interference prevention
  void _onScrollChange() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent == 0) return; // No content to scroll

    // Check if we're near the bottom (reduced threshold for better precision)
    final threshold = 20.0; // Reduced from 50px for better precision
    final isNearBottom =
        position.pixels >= (position.maxScrollExtent - threshold);

    // Only update state if there's a meaningful change and we're not auto-scrolling
    if (!isNearBottom && !_userHasScrolled) {
      // User scrolled up from bottom
      setState(() {
        _userHasScrolled = true;
      });
    } else if (isNearBottom && _userHasScrolled) {
      // User scrolled back to bottom
      setState(() {
        _userHasScrolled = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    final pickedFiles = await FileUtils.pickFiles();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _attachedFiles.addAll(pickedFiles);
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  // Helper method to get appropriate file icon based on file type
  Widget _getFileIcon(IconData icon) {
    return Icon(
      icon,
      size: 24,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade300
          : Colors.grey.shade700,
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSendingMessage) return;

    // Prevent duplicate sends
    setState(() {
      _isSendingMessage = true;
    });

    // Use cached provider reference or get fresh one if needed
    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    // Use the new method that handles chat creation if needed
    chatProvider
        .sendMessageWithOptionalChatCreation(
      message,
      attachedFiles: _attachedFiles,
    )
        .then((_) {
      // Success case - reset sending flag
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }).catchError((error) {
      // Reset sending flag on error
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });

        // Show error message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    });

    // Clear the input field and attachments
    _messageController.clear();
    setState(() {
      _attachedFiles = [];
      // Reset user scroll flag when sending a new message to ensure auto-scroll works
      _userHasScrolled = false;
    });

    // Immediately scroll to show the user's message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // Show dialog to rename a chat
  void _showRenameChatDialog(String chatId, String currentTitle) {
    final TextEditingController controller = TextEditingController(
      text: currentTitle,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Chat Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Provider.of<ChatProvider>(
                  context,
                  listen: false,
                ).updateChatTitle(chatId, newTitle);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  // Show dialog to confirm chat deletion
  void _showDeleteChatDialog(String chatId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
            'Are you sure you want to delete this chat? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<ChatProvider>(
                  context,
                  listen: false,
                ).deleteChat(chatId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final fontSize = settingsProvider.settings.fontSize;

    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            final activeChat = chatProvider.activeChat;
            return MarkdownTitle(
              data: activeChat?.title ?? 'New Chat',
              style: Theme.of(context).appBarTheme.titleTextStyle ??
                  Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          // Chat options menu (rename, delete)
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final activeChat = chatProvider.activeChat;
              if (activeChat != null) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Chat options',
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Rename Chat'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Delete Chat',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') {
                      _showRenameChatDialog(activeChat.id, activeChat.title);
                    } else if (value == 'delete') {
                      _showDeleteChatDialog(activeChat.id);
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Model selector in the app bar - only show on larger screens
          if (MediaQuery.of(context).size.width > 600) const ModelSelector(),

          // Settings button or menu button based on screen size
          if (MediaQuery.of(context).size.width > 600)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            )
          else
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ),
        ],
      ),
      drawer: const ChatDrawer(),
      endDrawer: MediaQuery.of(context).size.width <= 600
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Model'),
                      trailing: const ModelSelector(compact: true),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Main content column
          Column(
            children: [
              // Error message display
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  if (chatProvider.error?.isNotEmpty ?? false) {
                    return Container(
                      color: Colors.red.shade100,
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      child: Text(
                        'Error: ${chatProvider.error}',
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Chat messages
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    final activeChat = chatProvider.activeChat;

                    if (activeChat == null) {
                      return const Center(
                        child: Text('Select or create a new chat to start'),
                      );
                    }

                    if (activeChat.messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start a conversation with ${activeChat.modelName}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Use the displayableMessages getter from ChatProvider
                    final displayMessages = chatProvider.displayableMessages;

                    return RepaintBoundary(
                        child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 16.0,
                        bottom:
                            80.0, // Add bottom padding to account for message input
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: displayMessages.length +
                          (chatProvider.isActiveChatGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show typing indicator or streaming response as the last item when generating
                        if (index == displayMessages.length &&
                            chatProvider.isActiveChatGenerating) {
                          final settings = Provider.of<SettingsProvider>(
                            context,
                            listen: false,
                          ).settings;

                          if (settings.showLiveResponse &&
                              (chatProvider.currentDisplayResponse.isNotEmpty ||
                                  chatProvider.hasActiveThinkingBubble)) {
                            // Show live thinking bubble and/or filtered streaming response
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Live thinking bubble (appears when thinking content is detected)
                                RepaintBoundary(
                                  key: const ValueKey('live_thinking_bubble'),
                                  child: LiveThinkingBubble(
                                    fontSize: fontSize,
                                    showThinkingIndicator:
                                        chatProvider.isActiveChatGenerating,
                                  ),
                                ),

                                // Streaming response content (filtered, without thinking)
                                if (chatProvider
                                    .currentDisplayResponse.isNotEmpty)
                                  RepaintBoundary(
                                    key: const ValueKey('streaming_message'),
                                    child: _buildMessageBubble(
                                      Message(
                                        id: 'streaming',
                                        content:
                                            chatProvider.currentDisplayResponse,
                                        role: MessageRole.assistant,
                                        timestamp: DateTime.now(),
                                      ),
                                      fontSize,
                                      isStreaming:
                                          true, // Add flag to disable selection
                                    ),
                                  ),
                              ],
                            );
                          } else {
                            // Show thinking or typing indicator
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: chatProvider.isThinkingPhase
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ThinkingIndicator(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.purple.shade300
                                                    : Colors.blue.shade600,
                                            size: 20.0,
                                          ),
                                          const SizedBox(width: 8.0),
                                          Text(
                                            'Thinking...',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.purple.shade300
                                                  : Colors.blue.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      )
                                    : TypingIndicator(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                      ),
                              ),
                            );
                          }
                        }

                        final message = displayMessages[index];
                        return _buildMessageBubble(message, fontSize);
                      },
                    ));
                  },
                ),
              ),
            ],
          ),

          // Attached files display
          if (_attachedFiles.isNotEmpty)
            Positioned(
              bottom: 80, // Position above the message input
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _attachedFiles.length,
                  itemBuilder: (context, index) {
                    final fileName = FileUtils.getFileName(
                      _attachedFiles[index],
                    );
                    final fileIcon = FileUtils.getFileIcon(
                      _attachedFiles[index],
                    );

                    return Container(
                      margin: const EdgeInsets.only(left: 8.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : MaterialLightColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade700
                              : MaterialLightColors.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          FileUtils.isImageFile(_attachedFiles[index])
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: Image.file(
                                    File(_attachedFiles[index]),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : _getFileIcon(fileIcon),
                          const SizedBox(width: 8.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => _removeAttachment(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Message input
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                return Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _pickFiles,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: const OutlineInputBorder(),
                            suffixIcon: _isCtrlPressed
                                ? const Icon(
                                    Icons.keyboard_return,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      IconButton(
                        icon: chatProvider.isActiveChatGenerating
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              )
                            : Icon(
                                Icons.send,
                                color: _isSendingMessage
                                    ? Colors.grey
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.lightBlueAccent
                                        : Theme.of(context).primaryColor,
                              ),
                        onPressed: _isSendingMessage
                            ? null
                            : () {
                                if (chatProvider.isActiveChatGenerating) {
                                  chatProvider.cancelGeneration();
                                } else {
                                  _sendMessage();
                                }
                              },
                        tooltip: chatProvider.isActiveChatGenerating
                            ? 'Stop generation'
                            : _isSendingMessage
                                ? 'Sending...'
                                : 'Send message',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, double fontSize,
      {bool isStreaming = false}) {
    final isUser = message.isUser;
    final isSmallScreen = MediaQuery.of(context).size.width <= 600;

    return RepaintBoundary(
        child: Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * (isSmallScreen ? 0.9 : 0.8),
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).brightness == Brightness.dark
                  ? DraculaColors.userBubble // Dracula user bubble color
                  : MaterialLightColors.userBubble // Material light theme
              : Theme.of(context).brightness == Brightness.dark
                  ? DraculaColors.aiBubble // Dracula AI bubble color
                  : MaterialLightColors.aiBubble, // Material light theme
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51), // 0.2 * 255 ≈ 51
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display thinking bubble for AI messages with thinking content
            if (!isUser && message.hasThinking)
              Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  return ThinkingBubble(
                    message: message,
                    fontSize: fontSize,
                    isExpanded:
                        chatProvider.isThinkingBubbleExpanded(message.id),
                    onToggleExpanded: () =>
                        chatProvider.toggleThinkingBubble(message.id),
                    showThinkingIndicator: chatProvider.isThinkingPhase &&
                        message.id == 'streaming',
                  );
                },
              ),

            // Display attached files if any
            if (message.attachedFiles.isNotEmpty) ...[
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: message.attachedFiles.map((filePath) {
                  final fileName = FileUtils.getFileName(filePath);
                  return FileUtils.isImageFile(filePath)
                      ? Image.file(
                          File(filePath),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? DraculaColors.selection
                                    : MaterialLightColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file, size: 16),
                              const SizedBox(width: 4.0),
                              Text(
                                fileName.length > 20
                                    ? '${fileName.substring(0, 17)}...'
                                    : fileName,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                }).toList(),
              ),
              const SizedBox(height: 8.0),
            ],

            // Message content with selectable text
            isUser
                ? Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor: Colors.white,
                        selectionColor: Colors.white.withValues(
                            alpha: 0.3), // White selection on blue background
                        selectionHandleColor: Colors.white,
                      ),
                    ),
                    child: SelectableText(
                      message.content,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: Colors.white, // White text on blue user bubble
                      ),
                    ),
                  )
                : CustomMarkdownBody(
                    // Use displayContent which returns finalAnswer for thinking messages
                    data: message.displayContent,
                    fontSize: fontSize,
                    selectable: !isStreaming,
                  ),

            // Timestamp
            const SizedBox(height: 4.0),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).brightness == Brightness.dark
                        ? DraculaColors.foreground.withAlpha(
                            179,
                          ) // 0.7 opacity
                        : MaterialLightColors.onPrimary.withValues(alpha: 0.8)
                    : Theme.of(context).brightness == Brightness.dark
                        ? DraculaColors.comment
                        : MaterialLightColors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
