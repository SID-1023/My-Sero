import 'package:flutter/material.dart';

/// Identifies who sent the message
enum MessageSender { user, sero }

/// Immutable chat message model
class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  /// Convenience getter used by UI
  bool get isUser => sender == MessageSender.user;

  /// Serialize for persistence (SharedPreferences / DB / API)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Restore message from storage
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      sender: MessageSender.values.firstWhere(
        (e) => e.name == map['sender'],
        orElse: () => MessageSender.sero,
      ),
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  /// Useful for debugging
  @override
  String toString() {
    return '[${sender.name}] $text';
  }
}
