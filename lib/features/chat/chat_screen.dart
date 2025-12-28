import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/chat_provider.dart';
import '../ui/keyboard_input_screen.dart';
import '../../../widgets/chat_bubble.dart';
import '../../../widgets/chat_composer.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;

      // Wait a short moment for layout to settle (especially on navigation)
      await Future.delayed(const Duration(milliseconds: 50));

      try {
        // For reversed lists the newest message is at offset 0.0
        final target = 0.0;
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Fallback to immediate jump
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final messages = provider.messages;

    // If message count increased, scroll to bottom so user sees latest reply
    if (messages.length != _prevMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _prevMessageCount = messages.length;
    }

    return Scaffold(
      // Prevent layout from jumping when IME hides/reopens during transitions
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(provider.activeChat?.title ?? 'Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: messages.isEmpty
            ? const Center(
                child: Text(
                  "Start a conversation with Sero",
                  style: TextStyle(color: Colors.white38, fontSize: 15),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                reverse: true,
                physics: const BouncingScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final msg = messages[messages.length - 1 - index];
                  return ChatBubble(message: msg);
                },
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
          child: ChatComposer(autoFocus: widget.focusComposer),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const KeyboardInputScreen())),
        child: const Icon(Icons.edit),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
