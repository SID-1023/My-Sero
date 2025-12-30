import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as ai;
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'models/chat_message.dart';
import 'models/chat_session.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatSession> _chats = [];
  ChatSession? _activeChat;
  bool _isTyping = false;
  late final ai.GenerativeModel _model;

  // --- GETTERS ---
  ChatSession? get activeChat => _activeChat;
  List<ChatSession> get chats => _chats;
  bool get isTyping => _isTyping;
  List<ChatMessage> get messages => _activeChat?.messages ?? [];

  ChatProvider() {
    final openAppTool = ai.FunctionDeclaration(
      'open_app',
      'Searches for and opens an installed application on the device.',
      ai.Schema.object(
        properties: {
          'appName': ai.Schema.string(
            description:
                'The name of the app to open (e.g., Spotify, WhatsApp, Camera)',
          ),
        },
        requiredProperties: ['appName'],
      ),
    );

    _model = ai.GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'YOUR_GEMINI_API_KEY', // Replace with your key
      tools: [
        ai.Tool(functionDeclarations: [openAppTool]),
      ],
      systemInstruction: ai.Content.system(
        "You are Sero, a helpful, emotion-aware assistant. "
        "You can help users by opening apps on their phone. "
        "If they ask to open an app, use the open_app tool. "
        "Keep your responses empathetic and concise.",
      ),
    );
  }

  void init() {
    if (_chats.isEmpty) createNewChat();
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

  Future<void> addMessage({
    required String text,
    required MessageSender sender,
  }) async {
    if (_activeChat == null) return;

    // 1. Add the user message
    final userMsg = ChatMessage(
      id: _id(),
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
    );
    _activeChat!.messages.add(userMsg);

    // 2. FIXED: Use copyWith to update the title
    if (_activeChat!.messages.length == 1 && sender == MessageSender.user) {
      final newTitle = text.length > 25 ? '${text.substring(0, 25)}...' : text;

      // Update the active chat object
      _activeChat = _activeChat!.copyWith(title: newTitle);

      // Update the chat in the main list so the Sidebar/List updates
      final index = _chats.indexWhere((c) => c.id == _activeChat!.id);
      if (index != -1) {
        _chats[index] = _activeChat!;
      }
    }

    notifyListeners();
    if (sender == MessageSender.user) await _handleAIRelationship(text);
  }

  Future<void> _handleAIRelationship(String userText) async {
    _isTyping = true;
    notifyListeners();

    try {
      final history = _activeChat!.messages.map((m) {
        return m.sender == MessageSender.user
            ? ai.Content.text(m.text)
            : ai.Content.model([ai.TextPart(m.text)]);
      }).toList();

      final aiChat = _model.startChat(
        history: history.sublist(0, history.length - 1),
      );
      var response = await aiChat.sendMessage(ai.Content.text(userText));

      final functionCalls = response.functionCalls.toList();
      if (functionCalls.isNotEmpty) {
        for (final call in functionCalls) {
          if (call.name == 'open_app') {
            final appName = call.args['appName'] as String;
            final bool success = await _launchAppLogic(appName);

            response = await aiChat.sendMessage(
              ai.Content.functionResponses([
                ai.FunctionResponse(call.name, {
                  'status': success ? 'success' : 'failed',
                  'message': success ? 'App opened' : 'App not found',
                }),
              ]),
            );
          }
        }
      }

      if (response.text != null) {
        _activeChat!.messages.add(
          ChatMessage(
            id: _id(),
            text: response.text!,
            sender: MessageSender.sero,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint("Sero Error: $e");
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  Future<bool> _launchAppLogic(String name) async {
    try {
      final List<AppInfo> apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
      );

      final match = apps.firstWhere(
        (app) => (app.appName ?? "").toLowerCase().contains(name.toLowerCase()),
      );

      return await FlutterDeviceApps.openApp(match.packageName ?? "");
    } catch (e) {
      return false;
    }
  }

  void clear() {
    if (_activeChat == null) return;

    // FIXED: Use copyWith to clear messages and reset title
    _activeChat = _activeChat!.copyWith(title: 'New Chat', messages: []);

    final index = _chats.indexWhere((c) => c.id == _activeChat!.id);
    if (index != -1) {
      _chats[index] = _activeChat!;
    }

    notifyListeners();
  }

  String _id() => Random().nextInt(999999).toString();
}
