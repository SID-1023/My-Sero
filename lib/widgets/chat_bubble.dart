import 'package:flutter/material.dart';
import '../features/chat/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Color accentColor;

  const ChatBubble({
    super.key,
    required this.message,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;

    // Logic: Both bubbles now sync with the accentColor for a unified theme
    final Color bubbleColor = isUser
        ? accentColor.withOpacity(0.12) // Glowing tint for User
        : const Color(0xFF14141B); // Deep space (Obsidian) for AI

    final Color borderColor = isUser
        ? accentColor.withOpacity(0.4) // Strong neon border for User
        : accentColor.withOpacity(0.12); // Subtle accent-colored border for AI

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 22),
          ),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            // User messages have a vibrant Neon Glow
            if (isUser)
              BoxShadow(
                color: accentColor.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: -2,
              ),
            // AI messages now have a subtle matching color glow instead of mood-based
            if (!isUser)
              BoxShadow(color: accentColor.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timeLabel,
                  style: TextStyle(
                    color: isUser
                        ? accentColor.withOpacity(0.6)
                        : Colors.white.withOpacity(0.2),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 11,
                    color: accentColor.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
