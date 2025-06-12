import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'markdown_title.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final fontSize = settingsProvider.settings.fontSize;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'OllamaVerse',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chat History',
                  style: TextStyle(
                    color: Colors.white.withAlpha(204), // 0.8 * 255 ≈ 204
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 8),
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('New Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        onPressed: () {
                          final models = chatProvider.availableModels;
                          if (models.isNotEmpty) {
                            // Use createNewChat without parameters to let it use the last selected model
                            chatProvider.createNewChat();
                            Navigator.pop(context); // Close drawer
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No models available. Please check Ollama server connection.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = chatProvider.chats;
                if (chats.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: TextStyle(fontSize: fontSize, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final isActive = chatProvider.activeChat?.id == chat.id;

                    return Dismissible(
                      key: Key(chat.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: const Text(
                                'Are you sure you want to delete this chat?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        chatProvider.deleteChat(chat.id);
                      },
                      child: ListTile(
                        title: MarkdownTitle(
                          data: chat.title,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Model: ${chat.modelName}',
                          style: TextStyle(fontSize: fontSize - 2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          child: const Icon(Icons.chat, color: Colors.white),
                        ),
                        selected: isActive,
                        onTap: () {
                          chatProvider.setActiveChat(chat.id);
                          Navigator.pop(context); // Close drawer
                        },
                        onLongPress: () {
                          _showEditTitleDialog(context, chat.id, chat.title);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh Models'),
            onTap: () {
              final chatProvider = Provider.of<ChatProvider>(
                context,
                listen: false,
              );
              chatProvider.refreshModels();
              Navigator.pop(context); // Close drawer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing models...')),
              );
            },
          ),
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
    );
  }

  void _showEditTitleDialog(
    BuildContext context,
    String chatId,
    String currentTitle,
  ) {
    final TextEditingController controller = TextEditingController(
      text: currentTitle,
    );
    final ValueNotifier<String> titleNotifier = ValueNotifier<String>(
      currentTitle,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final fontSize = settingsProvider.settings.fontSize;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Chat Title'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  helperText: 'Supports markdown formatting',
                ),
                autofocus: true,
                onChanged: (value) {
                  titleNotifier.value = value;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Preview:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: titleNotifier,
                  builder: (context, value, child) {
                    return MarkdownTitle(
                      data: value,
                      style: TextStyle(fontSize: fontSize),
                    );
                  },
                ),
              ),
            ],
          ),
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
    ).then((_) {
      controller.dispose();
      titleNotifier.dispose();
    });
  }
}
