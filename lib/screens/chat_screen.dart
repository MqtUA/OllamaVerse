import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/file_utils.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/custom_markdown_body.dart';
import '../widgets/model_selector.dart';
import '../widgets/typing_indicator.dart';

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

  @override
  void initState() {
    super.initState();
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
      } else if (event.logicalKey == LogicalKeyboardKey.enter && _isCtrlPressed) {
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
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
  Widget _getFileIcon(String fileType) {
    IconData iconData;
    Color iconColor;
    
    switch (fileType) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'word':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'excel':
        iconData = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case 'powerpoint':
        iconData = Icons.slideshow;
        iconColor = Colors.orange;
        break;
      case 'text':
        iconData = Icons.text_snippet;
        iconColor = Colors.grey;
        break;
      case 'archive':
        iconData = Icons.archive;
        iconColor = Colors.brown;
        break;
      case 'audio':
        iconData = Icons.audio_file;
        iconColor = Colors.purple;
        break;
      case 'video':
        iconData = Icons.video_file;
        iconColor = Colors.red.shade700;
        break;
      case 'code':
        iconData = Icons.code;
        iconColor = Colors.indigo;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900 
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: iconColor,
          size: 30,
        ),
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final activeChat = chatProvider.activeChat;

    if (activeChat == null) {
      // If no active chat, create one with the first available model
      final models = chatProvider.availableModels;
      if (models.isNotEmpty) {
        chatProvider.createNewChat(models.first.name).then((_) {
          chatProvider.sendMessage(message, attachedFiles: _attachedFiles);
          
          // Generate a name for the new chat based on the first message
          _generateChatName(message, models.first.name);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No models available. Please check Ollama server connection.')),
        );
      }
    } else {
      chatProvider.sendMessage(message, attachedFiles: _attachedFiles);
      
      // If this is the first message in the chat, generate a name
      if (activeChat.messages.isEmpty && activeChat.title == 'New Chat') {
        _generateChatName(message, activeChat.modelName);
      }
    }

    _messageController.clear();
    setState(() {
      _attachedFiles = [];
    });

    // Scroll to bottom after a short delay to ensure the new message is rendered
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }
  
  // Generate a name for the chat based on the first message
  void _generateChatName(String message, String modelName) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final activeChat = chatProvider.activeChat;
    if (activeChat == null) return;
    
    // Create a short title based on the first few words of the message
    String title;
    if (message.length > 40) {
      title = '${message.substring(0, 37)}...';
    } else {
      title = message;
    }
    
    chatProvider.updateChatTitle(activeChat.id, title);
  }
  
  // Show dialog to rename a chat
  void _showRenameChatDialog(String chatId, String currentTitle) {
    final TextEditingController controller = TextEditingController(text: currentTitle);
    
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
                Provider.of<ChatProvider>(context, listen: false)
                    .updateChatTitle(chatId, newTitle);
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
          content: const Text('Are you sure you want to delete this chat? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<ChatProvider>(context, listen: false).deleteChat(chatId);
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
            return Text(activeChat?.title ?? 'New Chat');
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
                          Text('Delete Chat', style: TextStyle(color: Colors.red)),
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
          
          // Model selector in the app bar
          const ModelSelector(),
          
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      drawer: const ChatDrawer(),
      body: Column(
        children: [
          // Error message display
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.error.isNotEmpty) {
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
                
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  // Add +1 to itemCount if generating to show typing indicator or streaming response
                  itemCount: activeChat.messages.length + (chatProvider.isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show typing indicator or streaming response as the last item when generating
                    if (index == activeChat.messages.length && chatProvider.isGenerating) {
                      final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
                      
                      if (settings.showLiveResponse && chatProvider.currentStreamingResponse.isNotEmpty) {
                        // Show streaming response
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            padding: const EdgeInsets.all(12.0),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(26), // 0.1 * 255 ≈ 26
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomMarkdownBody(
                                  data: chatProvider.currentStreamingResponse,
                                  fontSize: fontSize,
                                  selectable: true,
                                  onTapLink: (text, href, title) {
                                    if (href != null) {
                                      // Handle link taps
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Link tapped: $href')),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 4.0),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white70
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Generating...',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white70
                                            : Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Show typing indicator
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TypingIndicator(color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade300 
                                : Colors.grey.shade700),
                          ),
                        );
                      }
                    }
                    
                    final message = activeChat.messages[index];
                    return _buildMessageBubble(message, fontSize);
                  },
                );
              },
            ),
          ),
          
          // Attached files display
          if (_attachedFiles.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _attachedFiles.length,
                itemBuilder: (context, index) {
                  final fileName = FileUtils.getFileName(_attachedFiles[index]);
                  final fileIconName = FileUtils.getFileIconName(_attachedFiles[index]);
                  
                  return Container(
                    margin: const EdgeInsets.only(left: 8.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.shade800 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
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
                            : _getFileIcon(fileIconName),
                        const SizedBox(width: 8.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              fileName.length > 15
                                  ? '${fileName.substring(0, 12)}...'
                                  : fileName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            if (FileUtils.isPdfFile(_attachedFiles[index]))
                              Text(
                                'PDF File',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeAttachment(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          
          // Message input
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              return Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26), // 0.1 * 255 ≈ 26
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
                          hintText: 'Type a message... (Ctrl+Enter to send)',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isCtrlPressed 
                              ? const Icon(Icons.keyboard_return, color: Colors.green)
                              : null,
                        ),
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      icon: chatProvider.isGenerating
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                              // Make sure the icon is visible in both light and dark themes
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.lightBlueAccent
                                  : Theme.of(context).primaryColor,
                            ),
                      onPressed: () {
                        if (chatProvider.isGenerating) {
                          // Stop generation
                          chatProvider.cancelGeneration();
                        } else {
                          // Send message
                          _sendMessage();
                        }
                      },
                      tooltip: chatProvider.isGenerating ? 'Stop generation' : 'Send message',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, double fontSize) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).primaryColor.withAlpha(230) // 0.9 * 255 ≈ 230
              : Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor.withAlpha(230) // 0.9 * 255 ≈ 230
                  : Theme.of(context).cardColor,
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
                            color: Colors.grey.shade200,
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
                ? SelectableText(
                    message.content,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.white,
                    ),
                  )
                : CustomMarkdownBody(
                    data: message.content,
                    fontSize: fontSize,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        // Handle link taps - could open a browser or in-app webview
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Link tapped: $href')),
                        );
                      }
                    },
                  ),
            
            // Timestamp
            const SizedBox(height: 4.0),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
