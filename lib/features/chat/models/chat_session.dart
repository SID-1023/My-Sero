import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'chat_message.dart';

class ChatSession {
  final String id;
  final String
  title; // Restored 'final' for immutability/Provider best practices
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  // --- PERSISTENCE HELPERS ---

  /// Creates a ChatSession from a Back4app ParseObject.
  /// Used when pulling your "Terminal" history from the cloud.
  factory ChatSession.fromParse(ParseObject object) {
    return ChatSession(
      id: object.objectId!,
      title: object.get<String>('title') ?? 'NEW TERMINAL',
      createdAt: object.createdAt ?? DateTime.now(),
      messages:
          [], // Populated separately via ChatProvider.fetchMessagesForActiveChat()
    );
  }

  // --- LOGIC HELPERS ---

  /// Creates a copy of this session with updated fields.
  /// Use this to update the title or add messages while keeping the object immutable.
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }
}
