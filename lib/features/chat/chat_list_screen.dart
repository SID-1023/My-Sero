import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';

import 'chat_provider.dart';
import 'chat_screen.dart';

// Assuming these exist in your project structure
import '../../core/ui/ui_preview.dart';
import '../../core/ui/sero_chat_tile.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Default to your Supernova Pink or a neutral grey until loaded
  Color _accentColor = const Color(0xFFFF006A);

  @override
  void initState() {
    super.initState();
    _loadNeuralColor();
  }

  /// Syncs the color with your Settings/Back4app
  Future<void> _loadNeuralColor() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user != null) {
      final colorHex = user.get<String>('accentColor');
      if (colorHex != null) {
        setState(() {
          _accentColor = Color(int.parse(colorHex));
        });
      }
    }
  }

  void _navigateToChat(BuildContext context) {
    FocusScope.of(context).unfocus();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChatScreen()))
        .then((_) => _loadNeuralColor()); // Refresh color when coming back
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF080101), // Pure "Void" Black
      appBar: AppBar(
        title: Text(
          "NEURAL ARCHIVE",
          style: TextStyle(
            color: _accentColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: provider.chats.isEmpty
          ? _buildEmptyState(context, provider)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: provider.chats.length,
              itemBuilder: (_, i) {
                final chat = provider.chats[i];
                return _buildGhostTile(chat, provider, context);
              },
            ),

      // ================= TOP-NOTCH FAB =================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          provider.createNewChat();
          _navigateToChat(context);
        },
        backgroundColor: _accentColor,
        elevation: 20,
        // Adding a slight glow to the button
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_circle_outline, color: Colors.black),
        label: const Text(
          "NEW EXCHANGE",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildGhostTile(
    dynamic chat,
    ChatProvider provider,
    BuildContext context,
  ) {
    return Dismissible(
      key: Key(chat.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.redAccent),
      ),
      onDismissed: (_) {
        // provider.deleteChat(chat);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentColor.withOpacity(0.1), width: 0.5),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: CircleAvatar(
            backgroundColor: _accentColor.withOpacity(0.1),
            child: Icon(Icons.bubble_chart, color: _accentColor, size: 20),
          ),
          title: Text(
            chat.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          subtitle: Text(
            chat.messages.isNotEmpty
                ? chat.messages.last.text
                : "Empty transmission...",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: _accentColor.withOpacity(0.2),
            size: 14,
          ),
          onTap: () {
            provider.openChat(chat);
            _navigateToChat(context);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.blur_on, size: 80, color: _accentColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            "NO NEURAL RECORDS",
            style: TextStyle(
              color: _accentColor.withOpacity(0.3),
              letterSpacing: 4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 30),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _accentColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              provider.createNewChat();
              _navigateToChat(context);
            },
            child: Text(
              "INITIALIZE LINK",
              style: TextStyle(color: _accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
