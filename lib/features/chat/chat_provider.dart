import 'package:flutter/material.dart';
import 'models/chat_message.dart';
import 'models/chat_session.dart';
import 'dart:math';

class ChatProvider extends ChangeNotifier {
  final List<ChatSession> _chats = [];
  ChatSession? _activeChat;

  List<ChatSession> get chats => _chats;
  ChatSession? get activeChat => _activeChat;

  List<ChatMessage> get messages => _activeChat?.messages ?? [];

  /// Create first chat if app opens fresh
  void init() {
    if (_chats.isEmpty) {
      createNewChat();
    }
  }

  /// Create new chat (ChatGPT-style)
  void createNewChat() {
    final chat = ChatSession(
      id: _id(),
      title: 'New Chat',
      createdAt: DateTime.now(),
      messages: [],
    );

    _chats.insert(0, chat);
    _activeChat = chat;
    notifyListeners();
  }

  /// Switch chat
  void openChat(ChatSession chat) {
    _activeChat = chat;
    notifyListeners();
  }

  /// Add message
  void addMessage({required String text, required MessageSender sender}) {
    if (_activeChat == null) return;

    _activeChat!.messages.add(
      ChatMessage(
        id: _id(),
        text: text,
        sender: sender,
        timestamp: DateTime.now(),
      ),
    );

    // Auto rename chat using first user message
    if (_activeChat!.messages.length == 1 && sender == MessageSender.user) {
      _activeChat = ChatSession(
        id: _activeChat!.id,
        title: text.length > 20 ? '${text.substring(0, 20)}...' : text,
        createdAt: _activeChat!.createdAt,
        messages: _activeChat!.messages,
      );
      _chats[0] = _activeChat!;
    }

    notifyListeners();
  }

  /// Clear messages in the active chat (keeps the session but resets title/messages)
  void clear() {
    if (_activeChat == null) return;

    _activeChat = ChatSession(
      id: _activeChat!.id,
      title: 'New Chat',
      createdAt: _activeChat!.createdAt,
      messages: [],
    );

    final idx = _chats.indexWhere((c) => c.id == _activeChat!.id);
    if (idx >= 0) _chats[idx] = _activeChat!;

    notifyListeners();
  }

  String _id() => Random().nextInt(999999).toString();
}
