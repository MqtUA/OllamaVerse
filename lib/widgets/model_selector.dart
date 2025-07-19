import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

/// Helper widget to handle nullable ChatProvider
class SafeChatConsumer extends StatelessWidget {
  final Widget Function(
      BuildContext context, ChatProvider chatProvider, Widget? child) builder;
  final Widget? child;
  final Widget? loadingWidget;

  const SafeChatConsumer({
    super.key,
    required this.builder,
    this.child,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider?>(
      builder: (context, chatProvider, child) {
        if (chatProvider == null) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }
        return builder(context, chatProvider, child);
      },
      child: child,
    );
  }
}

class ModelSelector extends StatelessWidget {
  final bool compact;

  const ModelSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SafeChatConsumer(
      builder: (context, chatProvider, child) {
        final models = chatProvider.availableModels;
        final activeChat = chatProvider.activeChat;

        if (models.isEmpty) {
          return IconButton(
            icon: const Icon(Icons.model_training),
            tooltip: 'No models available',
            onPressed: () {
              chatProvider.refreshModels();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing models...')),
              );
            },
          );
        }

        // Use different UI for compact mode
        return PopupMenuButton<String>(
          icon: compact
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.model_training, size: 20),
                    if (activeChat != null) ...[
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          activeChat.modelName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14),
                    ],
                  ],
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.model_training),
                    // Add a small badge to indicate the current model is active
                    if (activeChat != null)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
          tooltip: activeChat != null
              ? 'Current model: ${activeChat.modelName}'
              : 'Select model',
          itemBuilder: (context) {
            return models.map((model) {
              return PopupMenuItem<String>(
                value: model,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeChat?.modelName == model
                            ? Theme.of(context).brightness == Brightness.dark
                                ? Colors.lightBlueAccent
                                : Theme.of(context).primaryColor
                            : Colors.transparent,
                      ),
                      child: activeChat?.modelName == model
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        model,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          onSelected: (modelName) {
            if (activeChat != null) {
              // Check if chat has messages (excluding system messages)
              final hasUserMessages =
                  activeChat.messages.where((msg) => !msg.isSystem).isNotEmpty;

              if (hasUserMessages) {
                // Show confirmation dialog for chats with messages
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Change Model'),
                      content: Text(
                          'Do you want to change the model to $modelName for this chat or create a new chat?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            chatProvider.createNewChat(modelName);
                          },
                          child: const Text('Create New Chat'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Update the model for the current chat
                            chatProvider.updateChatModel(
                                activeChat.id, modelName);
                          },
                          child: const Text('Change Model'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                );
              } else {
                // No user messages, directly update the model without confirmation
                chatProvider.updateChatModel(activeChat.id, modelName);
              }
            } else {
              // If no active chat, create a new one with the selected model
              chatProvider.createNewChat(modelName);
            }
          },
        );
      },
    );
  }
}
