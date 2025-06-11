import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ModelSelector extends StatelessWidget {
  final bool compact;
  
  const ModelSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
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
                value: model.name,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeChat?.modelName == model.name
                            ? Theme.of(context).brightness == Brightness.dark
                                ? Colors.lightBlueAccent
                                : Theme.of(context).primaryColor
                            : Colors.transparent,
                      ),
                      child: activeChat?.modelName == model.name
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${(model.size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          onSelected: (modelName) {
            if (activeChat != null) {
              // Show a dialog to confirm changing the model for an existing chat
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Change Model'),
                    content: Text(
                      activeChat.messages.isEmpty
                          ? 'Do you want to use $modelName for this chat?'
                          : 'Do you want to change the model to $modelName for this chat or create a new chat?'
                    ),
                    actions: [
                      if (activeChat.messages.isNotEmpty)
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
                          chatProvider.updateChatModel(activeChat.id, modelName);
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
              // If no active chat, create a new one with the selected model
              chatProvider.createNewChat(modelName);
            }
          },
        );
      },
    );
  }
}
