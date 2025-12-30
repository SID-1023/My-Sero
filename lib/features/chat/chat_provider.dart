import 'package:flutter/material.dart';
import 'models/chat_message.dart';
import 'models/chat_session.dart';
import 'dart:math';

class ChatProvider extends ChangeNotifier {
  final List<ChatSession> _chats = [];
  ChatSession? _activeChat;

  // NEW: Track typing state
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  List<ChatSession> get chats => _chats;
  ChatSession? get activeChat => _activeChat;
  List<ChatMessage> get messages => _activeChat?.messages ?? [];

  void init() {
    if (_chats.isEmpty) {
      createNewChat();
    }
  }

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

  void openChat(ChatSession chat) {
    _activeChat = chat;
    notifyListeners();
  }

  /// Updated AddMessage with automatic AI response simulation
  Future<void> addMessage({
    required String text,
    required MessageSender sender,
  }) async {
    if (_activeChat == null) return;

    // 1. Add the actual message
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

      // Update the chat in the list
      final index = _chats.indexWhere((c) => c.id == _activeChat!.id);
      if (index != -1) _chats[index] = _activeChat!;
    }

    notifyListeners();

    // 2. If the user sent the message, trigger Sero's "Thinking" state
    if (sender == MessageSender.user) {
      await _simulateSeroResponse(text);
    }
  }

  /// NEW: Simulation logic for the Typing Indicator
  Future<void> _simulateSeroResponse(String userText) async {
    _isTyping = true;
    notifyListeners();

    // Wait 2 seconds to show off the cool Typing Indicator
    await Future.delayed(const Duration(seconds: 2));

    String response = _generateSimpleResponse(userText);

    _isTyping = false; // Hide indicator
    addMessage(text: response, sender: MessageSender.sero);
  }

  String _generateSimpleResponse(String input) {
    String lower = input.toLowerCase();
    if (lower.contains("hello") || lower.contains("hi"))
      return "Hello! I'm Sero. How are you feeling today?";
    if (lower.contains("sad") || lower.contains("bad"))
      return "I'm sorry you're feeling that way. I'm here to listen.";
    if (lower.contains("happy") || lower.contains("good"))
      return "That's wonderful! I love hearing positive news.";
    return "I hear you. Can you tell me more about that?";
  }

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
