import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Defines who sent the message to handle UI alignment and logic.
enum MessageSender { user, sero }

class ChatMessage {
  static const String keyClassName = 'Message'; // The class name in Back4app

  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  // ===== NEW FEATURE START =====
  final String? imageUrl; // Stores cloud URL for multimodal images
  // ===== NEW FEATURE END =====

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    // ===== NEW FEATURE START =====
    this.imageUrl,
    // ===== NEW FEATURE END =====
  });

  // --- UI HELPERS ---

  /// Returns true if the message was sent by the human user.
  bool get isUser => sender == MessageSender.user;

  // ===== NEW FEATURE START =====
  /// Returns true if the message contains an image for vision analysis.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  // ===== NEW FEATURE END =====

  /// Returns a formatted time string (e.g., 14:05) for the terminal UI.
  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // --- PERSISTENCE HELPERS (Back4app) ---

  /// Converts a Back4app ParseObject into a local ChatMessage object.
  /// Used when pulling history from the cloud.
  factory ChatMessage.fromParse(ParseObject object) {
    final senderString = object.get<String>('sender');

    return ChatMessage(
      id: object.objectId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      text: object.get<String>('text') ?? '',
      sender: senderString == 'user' ? MessageSender.user : MessageSender.sero,
      timestamp: object.createdAt ?? DateTime.now(),
      // ===== NEW FEATURE START =====
      imageUrl: object.get<ParseFileBase>('image')?.url,
      // ===== NEW FEATURE END =====
    );
  }

  /// Converts the current ChatMessage data into a Map for saving to Back4app.
  /// This corresponds to the columns 'text' and 'sender' in your database.
  Map<String, dynamic> toParseMap() {
    return {
      'text': text,
      'sender': sender == MessageSender.user ? 'user' : 'sero',
      // Note: 'user' pointer and 'createdAt' are usually handled in the Provider
    };
  }

  // --- STATE HELPERS ---

  /// Allows creating a new instance with modified fields.
  /// Essential for "Optimistic UI" updates where you show the message
  /// locally before the server confirms the save.
  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    // ===== NEW FEATURE START =====
    String? imageUrl,
    // ===== NEW FEATURE END =====
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      // ===== NEW FEATURE START =====
      imageUrl: imageUrl ?? this.imageUrl,
      // ===== NEW FEATURE END =====
    );
  }
}
