import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Since they are in the same folder, just use the filename
import 'chat_provider.dart';
import 'chat_screen.dart';

// These are likely in lib/core/ui/ (adjust if necessary)
import '../../core/ui/ui_preview.dart';
import '../../core/ui/sero_chat_tile.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  /// Helper to handle navigation and focus cleanup
  void _navigateToChat(BuildContext context) {
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // watch allows the UI to rebuild when notifyListeners() is called in the provider
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversations"),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            Colors.transparent, // Keeps the high-end Sero aesthetic
      ),
      body: provider.chats.isEmpty
          ? _buildEmptyState(context, provider)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.chats.length,
              itemBuilder: (_, i) {
                final chat = provider.chats[i];

                // Added Dismissible so you can delete chats (Standard Full Update)
                return Dismissible(
                  key: Key(chat.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent.withOpacity(0.2),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
                  onDismissed: (direction) {
                    // Logic to remove chat would go here in your provider
                    // provider.deleteChat(chat);
                  },
                  child: kUseNewUIPreview
                      ? SeroChatTile(
                          chat: chat,
                          onTap: () {
                            provider.openChat(chat);
                            _navigateToChat(context);
                          },
                        )
                      : ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            chat.messages.isNotEmpty
                                ? chat.messages.last.text
                                : "No messages yet",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            provider.openChat(chat);
                            _navigateToChat(context);
                          },
                        ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          provider.createNewChat();
          _navigateToChat(context);
        },
        label: const Text("New Chat"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            "No conversations yet",
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              provider.createNewChat();
              _navigateToChat(context);
            },
            child: const Text("Start your first chat"),
          ),
        ],
      ),
    );
  }
}
