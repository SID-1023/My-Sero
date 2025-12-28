import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';
import 'chat_screen.dart';
import '../../core/ui/ui_preview.dart';
import '../../core/ui/sero_chat_tile.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Chats")),
      body: ListView.builder(
        itemCount: provider.chats.length,
        itemBuilder: (_, i) {
          final chat = provider.chats[i];

          // Use the new preview tile when preview is enabled; otherwise keep
          // the existing ListTile for backwards compatibility.
          if (kUseNewUIPreview) {
            return SeroChatTile(
              chat: chat,
              onTap: () {
                provider.openChat(chat);
                // Prevent IME from panicking during the route transition
                FocusScope.of(context).unfocus();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
              },
            );
          }

          return ListTile(
            title: Text(chat.title),
            onTap: () {
              provider.openChat(chat);
              // Prevent IME from panicking during the route transition
              FocusScope.of(context).unfocus();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          provider.createNewChat();
          // Prevent IME from panicking during the route transition
          FocusScope.of(context).unfocus();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
