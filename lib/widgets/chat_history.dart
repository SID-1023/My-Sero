import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/ui/chat_message.dart';
import '../features/voice/voice_input.dart';

class ChatHistory extends StatelessWidget {
  const ChatHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<VoiceInputProvider>().messages;

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final msg = messages[messages.length - 1 - index];

        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: msg.isUser
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }
}
