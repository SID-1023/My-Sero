import 'package:flutter/material.dart';
import '../../core/theme_tokens.dart';
import '../../core/ui/sero_avatar.dart';
import '../../core/ui/sero_timestamp.dart';
import '../../features/chat/models/chat_session.dart';

class SeroChatTile extends StatelessWidget {
  final ChatSession chat;
  final VoidCallback? onTap;

  const SeroChatTile({Key? key, required this.chat, this.onTap})
    : super(key: key);

  String _lastSnippet() {
    if (chat.messages.isEmpty) return 'No messages yet';
    final last = chat.messages.last.text;
    return last.length > 48 ? '${last.substring(0, 48)}...' : last;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SeroTokens.surface,
      elevation: SeroTokens.cardElevation,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SeroTokens.radiusLarge),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SeroTokens.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SeroAvatar(
                size: 48,
                initials: chat.title.isNotEmpty
                    ? chat.title[0].toUpperCase()
                    : 'S',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            chat.title,
                            style: SeroTokens.heading,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SeroTimestamp(timestamp: chat.createdAt),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _lastSnippet(),
                      style: SeroTokens.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
