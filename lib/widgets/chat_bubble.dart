import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/chat/models/chat_message.dart';
import '../features/voice/voice_input.dart'; // To access the emotion color

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Note: Adjust 'message.isUser' or 'message.sender' based on your model field name
    final bool isUser = message.isUser;
    final voiceProvider = context.watch<VoiceInputProvider>();

    // Logic: User is dark obsidian, Sero is tinted with current emotion
    final Color bubbleColor = isUser
        ? const Color(0xFF14141B) // Deep space grey
        : voiceProvider.emotionColor.withOpacity(0.08);

    final Color borderColor = isUser
        ? Colors.white.withOpacity(0.05)
        : voiceProvider.emotionColor.withOpacity(0.2);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4), // Sharp "tail" for AI
            bottomRight: Radius.circular(
              isUser ? 4 : 20,
            ), // Sharp "tail" for User
          ),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            if (!isUser) // AI messages have a subtle "presence" glow
              BoxShadow(
                color: voiceProvider.emotionColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white.withOpacity(0.9) : Colors.white,
                fontSize: 15,
                height: 1.4,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timeLabel, // e.g., "12:45 PM"
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle_outline,
                    size: 10,
                    color: Colors.white.withOpacity(0.2),
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
