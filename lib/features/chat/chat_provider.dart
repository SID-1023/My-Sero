import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_generative_ai/google_generative_ai.dart' as ai;
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/chat_message.dart';
import 'models/chat_session.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatSession> _chats = [];
  ChatSession? _activeChat;
  bool _isTyping = false;
  late final ai.GenerativeModel _model;

  // VOICE ENGINES
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _lastSpokenWords = "";

  // GETTERS
  ChatSession? get activeChat => _activeChat;
  List<ChatSession> get chats => _chats;
  bool get isTyping => _isTyping;
  bool get isListening => _isListening;
  List<ChatMessage> get messages => _activeChat?.messages ?? [];

  ChatProvider() {
    _initializeModel();
    _initTTS();
  }

  void _initTTS() {
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.45); // Slightly slower for a "calm" Sero voice
  }

  /// Toggles microphone and provides haptic feedback
  Future<void> toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      HapticFeedback.mediumImpact();
      notifyListeners();
      return;
    }

    var micStatus = await Permission.microphone.request();
    if (micStatus.isGranted) {
      bool available = await _speechToText.initialize(
        onError: (e) => debugPrint('STT Error: $e'),
      );

      if (available) {
        HapticFeedback.heavyImpact(); // Signal start
        _isListening = true;
        _lastSpokenWords = "";
        notifyListeners();

        _speechToText.listen(
          onResult: (val) {
            _lastSpokenWords = val.recognizedWords;
            if (val.finalResult) {
              _isListening = false;
              HapticFeedback.lightImpact();
              addMessage(text: _lastSpokenWords, sender: MessageSender.user);
              notifyListeners();
            }
          },
        );
      }
    }
  }

  void _initializeModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'YOUR_API_KEY';

    final openAppTool = ai.FunctionDeclaration(
      'open_app',
      'Searches for and opens an installed application on the device.',
      ai.Schema.object(
        properties: {
          'appName': ai.Schema.string(
            description: 'Name of the app (e.g. Spotify)',
          ),
        },
        requiredProperties: ['appName'],
      ),
    );

    _model = ai.GenerativeModel(
      model: 'gemini-2.0-flash', // Optimized for 2025 performance
      apiKey: apiKey,
      tools: [
        ai.Tool(functionDeclarations: [openAppTool]),
      ],
      systemInstruction: ai.Content.system(
        "You are Sero, a helpful assistant. Use open_app to launch apps. "
        "Keep responses short and empathetic. If successful, use a terminal-style [SUCCESS] tag.",
      ),
    );
  }

  void init() {
    if (_chats.isEmpty) createNewChat();
  }

  void createNewChat() {
    final chat = ChatSession(
      id: _id(),
      title: 'NEW TERMINAL',
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

    final msg = ChatMessage(
      id: _id(),
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
    );
    _activeChat!.messages.add(msg);
    notifyListeners();

    if (sender == MessageSender.user) {
      await _handleAIRelationship(text);
    }
  }

  Future<void> _handleAIRelationship(String userText) async {
    _isTyping = true;
    notifyListeners();

    try {
      // Map history correctly for the model
      final history = _activeChat!.messages
          .take(_activeChat!.messages.length - 1)
          .map((m) {
            return m.sender == MessageSender.user
                ? ai.Content.text(m.text)
                : ai.Content.model([ai.TextPart(m.text)]);
          })
          .toList();

      final aiChat = _model.startChat(history: history);
      var response = await aiChat.sendMessage(ai.Content.text(userText));

      // 1. Automatic smarter title generation for first message
      if (_activeChat!.messages.length <= 2) {
        _generateSmartTitle(userText);
      }

      // 2. Handle Tool Usage
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
                  'message': success
                      ? 'App $appName launched.'
                      : 'App not found.',
                }),
              ]),
            );
          }
        }
      }

      // 3. Final Text Response
      if (response.text != null) {
        final aiMsg = ChatMessage(
          id: _id(),
          text: response.text!,
          sender: MessageSender.sero,
          timestamp: DateTime.now(),
        );
        _activeChat!.messages.add(aiMsg);
        await _flutterTts.speak(response.text!);
      }
    } catch (e) {
      // THE FIX: Robust error catching for "Uplink" issues
      debugPrint("Sero Error: $e");
      final errorMsg = ChatMessage(
        id: _id(),
        text: "CRITICAL ERROR: Uplink interrupted. System standby.",
        sender: MessageSender.sero,
        timestamp: DateTime.now(),
      );
      _activeChat!.messages.add(errorMsg);
      await _flutterTts.speak("Uplink interrupted. System standby.");
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Smarter title generator using simple logic (avoiding extra AI calls to save quota)
  void _generateSmartTitle(String text) {
    String cleanTitle = text.trim().toUpperCase();
    if (cleanTitle.length > 20) {
      cleanTitle = "${cleanTitle.substring(0, 17)}...";
    }
    _activeChat = _activeChat!.copyWith(title: cleanTitle);
    final index = _chats.indexWhere((c) => c.id == _activeChat!.id);
    if (index != -1) _chats[index] = _activeChat!;
  }

  Future<bool> _launchAppLogic(String name) async {
    try {
      final List<AppInfo> apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
      );

      final match = apps.cast<AppInfo?>().firstWhere(
        (app) =>
            (app?.appName ?? "").toLowerCase().contains(name.toLowerCase()),
        orElse: () => null,
      );

      if (match != null) {
        return await FlutterDeviceApps.openApp(match.packageName!);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void clear() {
    if (_activeChat == null) return;
    _activeChat = _activeChat!.copyWith(title: 'PURGED', messages: []);
    final index = _chats.indexWhere((c) => c.id == _activeChat!.id);
    if (index != -1) _chats[index] = _activeChat!;
    notifyListeners();
  }

  String _id() => Random().nextInt(999999).toString();
}
