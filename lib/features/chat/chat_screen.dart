import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/chat_provider.dart';
import '../ui/keyboard_input_screen.dart';
import '../../../widgets/chat_bubble.dart';
import '../../../widgets/chat_composer.dart';
import '../../../widgets/typing_indicator.dart'; // Ensure you created this file

class ChatScreen extends StatefulWidget {
  final bool focusComposer;

  const ChatScreen({super.key, this.focusComposer = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  int _prevMessageCount = 0;

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    // In a reversed list, the newest message is at offset 0.0
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    // We get the list of messages.
    // We DON'T need to .reversed.toList() here because ListView(reverse: true)
    // handles the visual reversal. We just need to manage the logic index.
    final messages = provider.messages;
    final bool isTyping = provider.isTyping;

    // Auto-scroll logic
    if (messages.length != _prevMessageCount) {
      _prevMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          provider.activeChat?.title ?? 'Sero Chat',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => _showClearDialog(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !isTyping
                ? const Center(
                    child: Text(
                      "Start a conversation with Sero",
                      style: TextStyle(color: Colors.white38, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    reverse: true, // Newest messages at the bottom
                    physics: const BouncingScrollPhysics(),
                    // Add 1 to itemCount if Sero is typing to make room for the indicator
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 1. If typing is active, the very first item (index 0) is the indicator
                      if (isTyping && index == 0) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: TypingIndicator(),
                          ),
                        );
                      }

                      // 2. Calculate the correct message index
                      // If typing is showing, we subtract 1 from the index to get the message
                      final messageIndex = isTyping ? index - 1 : index;

                      // Since the list is reversed, the latest message in the list
                      // is at the END of the provider's array.
                      final message =
                          messages[messages.length - 1 - messageIndex];

                      return ChatBubble(message: message);
                    },
                  ),
          ),

          // Input Area
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20,
              left: 12,
              right: 12,
              top: 8,
            ),
            child: ChatComposer(autoFocus: widget.focusComposer),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text("Clear Chat", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Do you want to delete all messages in this session?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              provider.clear();
              Navigator.pop(context);
            },
            child: const Text(
              "Clear",
              style: TextStyle(color: Color(0xFFB11226)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
