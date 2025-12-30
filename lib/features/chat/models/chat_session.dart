import 'chat_message.dart';

class ChatSession {
  final String id;
  // REMOVED 'final' so this can be updated by setters in ChatProvider
  String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  /// The copyWith method remains useful for creating new instances
  /// with multiple changes at once.
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
