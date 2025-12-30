import 'chat_message.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  /// The copyWith method is the standard way in Flutter to "update"
  /// final fields. It returns a brand new object with the changes applied.
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      // The ?? operator means: "Use the new value if provided,
      // otherwise keep the current value."
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }
}
