import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Defines who sent the message to handle UI alignment and logic.
enum MessageSender { user, sero }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  // --- UI HELPERS ---

  /// Returns true if the message was sent by the human user.
  bool get isUser => sender == MessageSender.user;

  /// Returns a formatted time string (e.g., 14:05) for the terminal UI.
  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // --- PERSISTENCE HELPERS (Back4app) ---

  /// Creates a ChatMessage from a Back4app ParseObject.
  /// Handles null safety for text and sender to ensure UI stability.
  factory ChatMessage.fromParse(ParseObject object) {
    // We check 'isSero' boolean or 'sender' string depending on your DB schema
    // Using your 'sender' string logic here:
    final senderString = object.get<String>('sender');

    return ChatMessage(
      id: object.objectId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      text: object.get<String>('text') ?? '',
      sender: senderString == 'user' ? MessageSender.user : MessageSender.sero,
      timestamp: object.createdAt ?? DateTime.now(),
    );
  }

  /// Converts the current message into a format ready for Back4app.
  /// This matches the columns you created in your Message class.
  Map<String, dynamic> toParseMap() {
    return {
      'text': text,
      'sender': sender == MessageSender.user ? 'user' : 'sero',
      // 'timestamp' and 'objectId' are automatically handled by Back4app
    };
  }

  // --- STATE HELPERS ---

  /// Allows creating a new instance with modified fields.
  /// Useful for optimistic UI updates in Flutter.
  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
