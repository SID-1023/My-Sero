import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as ai;
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'models/chat_message.dart';
import 'models/chat_session.dart';

class ChatProvider with ChangeNotifier {
  List<ChatSession> _chats = [];
  ChatSession? _activeChat;
  bool _isTyping = false;
  late final ai.GenerativeModel _model;

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _lastSpokenWords = "";

  ChatSession? get activeChat => _activeChat;
  List<ChatSession> get chats => _chats;
  bool get isTyping => _isTyping;
  bool get isListening => _isListening;
  List<ChatMessage> get messages => _activeChat?.messages ?? [];

  ChatProvider() {
    _initializeModel();
    _initTTS();
    loadChatHistory();
  }

  void init() {
    if (_chats.isEmpty) loadChatHistory();
  }

  void _initTTS() {
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.45);
  }

  // --- PERSISTENCE LOGIC (BACK4APP) ---

  Future<void> loadChatHistory() async {
    final currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser == null) return;

    final QueryBuilder<ParseObject> sessionQuery =
        QueryBuilder<ParseObject>(ParseObject('ChatSession'))
          ..whereEqualTo('user', currentUser.toPointer())
          ..orderByDescending('createdAt');

    final response = await sessionQuery.query();

    if (response.success && response.results != null) {
      _chats = response.results!.map((obj) {
        return ChatSession(
          id: obj.objectId!,
          title: obj.get<String>('title') ?? 'Untitled',
          createdAt: obj.createdAt!,
          messages: [],
        );
      }).toList();

      if (_chats.isNotEmpty && _activeChat == null) {
        _activeChat = _chats.first;
        await fetchMessagesForActiveChat();
      }
      notifyListeners();
    }
  }

  Future<void> fetchMessagesForActiveChat() async {
    if (_activeChat == null) return;

    final QueryBuilder<ParseObject> msgQuery =
        QueryBuilder<ParseObject>(ParseObject('Message'))
          ..whereEqualTo('sessionId', _activeChat!.id)
          ..orderByAscending('createdAt');

    final response = await msgQuery.query();

    if (response.success && response.results != null) {
      _activeChat!.messages.clear();
      for (var obj in response.results!) {
        _activeChat!.messages.add(
          ChatMessage(
            id: obj.objectId!,
            text: obj.get<String>('text') ?? '',
            sender: obj.get<String>('sender') == 'user'
                ? MessageSender.user
                : MessageSender.sero,
            timestamp: obj.createdAt!,
          ),
        );
      }
      notifyListeners();
    }
  }

  // --- NAVIGATION & ARCHIVE ---

  Future<void> openChat(ChatSession chat) async {
    _activeChat = chat;
    notifyListeners();
    await fetchMessagesForActiveChat();
  }

  // --- PURGE & DELETE LOGIC ---

  /// Purges all messages from the currently active session (Back4app + Local)
  Future<void> clear() async {
    if (_activeChat == null) return;
    try {
      final QueryBuilder<ParseObject> query = QueryBuilder<ParseObject>(
        ParseObject('Message'),
      )..whereEqualTo('sessionId', _activeChat!.id);

      final response = await query.query();
      if (response.success && response.results != null) {
        for (var obj in response.results!) {
          await obj.delete();
        }
      }
      _activeChat!.messages.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("Purge Error: $e");
    }
  }

  /// Deletes a whole chat session and all its messages
  Future<void> deleteChat(ChatSession session) async {
    try {
      // 1. Delete messages linked to session
      final QueryBuilder<ParseObject> query = QueryBuilder<ParseObject>(
        ParseObject('Message'),
      )..whereEqualTo('sessionId', session.id);
      final msgResponse = await query.query();
      if (msgResponse.results != null) {
        for (var m in msgResponse.results!) {
          await m.delete();
        }
      }

      // 2. Delete the session itself
      final sessionObj = ParseObject('ChatSession')..objectId = session.id;
      await sessionObj.delete();

      // 3. Update UI
      _chats.removeWhere((c) => c.id == session.id);
      if (_activeChat?.id == session.id) {
        _activeChat = _chats.isNotEmpty ? _chats.first : null;
        if (_activeChat != null) await fetchMessagesForActiveChat();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Session Error: $e");
    }
  }

  // --- MODEL & TOOLS ---

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

    final searchContactsTool = ai.FunctionDeclaration(
      'search_contacts',
      'Searches the device contacts for a name to find their phone number.',
      ai.Schema.object(
        properties: {
          'name': ai.Schema.string(
            description: 'The name of the person to search for.',
          ),
        },
        requiredProperties: ['name'],
      ),
    );

    final dialNumberTool = ai.FunctionDeclaration(
      'dial_number',
      'Opens the phone dialer with a specific phone number.',
      ai.Schema.object(
        properties: {
          'phoneNumber': ai.Schema.string(
            description: 'The phone number to dial.',
          ),
        },
        requiredProperties: ['phoneNumber'],
      ),
    );

    _model = ai.GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      tools: [
        ai.Tool(
          functionDeclarations: [
            openAppTool,
            searchContactsTool,
            dialNumberTool,
          ],
        ),
      ],
      systemInstruction: ai.Content.system(
        "You are Sero, a helpful assistant. Use open_app to launch apps. "
        "To call someone, first use search_contacts to find their number, then use dial_number. "
        "Keep responses short and empathetic. If successful, use a terminal-style [SUCCESS] tag.",
      ),
    );
  }

  Future<void> createNewChat() async {
    final currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser == null) return;

    final sessionObj = ParseObject('ChatSession')
      ..set('title', 'NEW TERMINAL')
      ..set('user', currentUser.toPointer());

    final response = await sessionObj.save();

    if (response.success) {
      final chat = ChatSession(
        id: sessionObj.objectId!,
        title: 'NEW TERMINAL',
        createdAt: DateTime.now(),
        messages: [],
      );
      _chats.insert(0, chat);
      _activeChat = chat;
      notifyListeners();
    }
  }

  Future<void> addMessage({
    required String text,
    required MessageSender sender,
  }) async {
    if (_activeChat == null) await createNewChat();

    final msgObj = ParseObject('Message')
      ..set('text', text)
      ..set('sender', sender == MessageSender.user ? 'user' : 'sero')
      ..set('sessionId', _activeChat!.id);

    await msgObj.save();

    final msg = ChatMessage(
      id: msgObj.objectId ?? _id(),
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
      final history = _activeChat!.messages
          .take(_activeChat!.messages.length - 1)
          .map(
            (m) => m.sender == MessageSender.user
                ? ai.Content.text(m.text)
                : ai.Content.model([ai.TextPart(m.text)]),
          )
          .toList();

      final aiChat = _model.startChat(history: history);
      var response = await aiChat.sendMessage(ai.Content.text(userText));

      if (_activeChat!.messages.length <= 2) _generateSmartTitle(userText);

      while (response.functionCalls.isNotEmpty) {
        final List<ai.FunctionResponse> functionResponses = [];
        for (final call in response.functionCalls) {
          if (call.name == 'open_app') {
            final appName = call.args['appName'] as String;
            final success = await _launchAppLogic(appName);
            functionResponses.add(
              ai.FunctionResponse(call.name, {
                'status': success ? 'success' : 'failed',
              }),
            );
          } else if (call.name == 'search_contacts') {
            final contactName = call.args['name'] as String;
            final number = await _internalSearchContacts(contactName);
            functionResponses.add(
              ai.FunctionResponse(call.name, {'phoneNumber': number}),
            );
          } else if (call.name == 'dial_number') {
            final phone = call.args['phoneNumber'] as String;
            final success = await _internalDialNumber(phone);
            functionResponses.add(
              ai.FunctionResponse(call.name, {
                'status': success ? 'dialing' : 'failed',
              }),
            );
          }
        }
        response = await aiChat.sendMessage(
          ai.Content.functionResponses(functionResponses),
        );
      }

      if (response.text != null) {
        await addMessage(text: response.text!, sender: MessageSender.sero);
        await _flutterTts.speak(response.text!);
      }
    } catch (e) {
      await addMessage(
        text: "CRITICAL ERROR: Uplink interrupted.",
        sender: MessageSender.sero,
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // --- INTERNAL TOOL HELPERS ---

  Future<String> _internalSearchContacts(String name) async {
    if (await Permission.contacts.request().isGranted) {
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      try {
        final match = contacts.firstWhere(
          (c) => (c.displayName).toLowerCase().contains(name.toLowerCase()),
        );
        if (match.phones.isNotEmpty) {
          final String? phoneNumber = match.phones.first.number;
          if (phoneNumber != null) return phoneNumber;
        }
        return "not found";
      } catch (e) {
        return "not found";
      }
    }
    return "permission denied";
  }

  Future<bool> _internalDialNumber(String number) async {
    final Uri telUri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(telUri)) {
      return await launchUrl(telUri);
    }
    return false;
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
        final String? pkg = match.packageName;
        if (pkg != null) {
          return await FlutterDeviceApps.openApp(pkg);
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- VOICE LOGIC ---

  Future<void> toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      notifyListeners();
      return;
    }
    if (await Permission.microphone.request().isGranted) {
      if (await _speechToText.initialize()) {
        _isListening = true;
        _speechToText.listen(
          onResult: (val) {
            if (val.finalResult) {
              addMessage(text: val.recognizedWords, sender: MessageSender.user);
              _isListening = false;
              notifyListeners();
            }
          },
        );
      }
    }
  }

  void _generateSmartTitle(String text) async {
    String cleanTitle = text.trim().toUpperCase();
    if (cleanTitle.length > 20)
      cleanTitle = "${cleanTitle.substring(0, 17)}...";
    _activeChat = _activeChat!.copyWith(title: cleanTitle);
    final session = ParseObject('ChatSession')
      ..objectId = _activeChat!.id
      ..set('title', cleanTitle);
    await session.save();
    notifyListeners();
  }

  String _id() => Random().nextInt(999999).toString();

  // ===== NEW FEATURE START =====

  /// Analyzes an image using Gemini Vision and adds the insight to the chat.
  /// This integrates multimodal support into Sero's pipeline.
  Future<void> analyzeImage(Uint8List imageBytes, String prompt) async {
    _isTyping = true;
    notifyListeners();

    try {
      // 1. Optimistically show user intent in UI
      final userMsg = ChatMessage(
        id: "temp_${_id()}",
        text: "[ANALYZING IMAGE] $prompt",
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      );
      _activeChat?.messages.add(userMsg);
      notifyListeners();

      // 2. Multimodal processing
      final content = [
        ai.Content.multi([
          ai.TextPart(prompt),
          ai.DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await _model.generateContent(content);

      if (response.text != null) {
        await addMessage(text: response.text!, sender: MessageSender.sero);
        await _flutterTts.speak(response.text!);
      }
    } catch (e) {
      debugPrint("Vision Error: $e");
      await addMessage(
        text: "VISION ERROR: Sensory input failed.",
        sender: MessageSender.sero,
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Refreshes the active session to pull any new messages from other devices.
  Future<void> refreshActiveChat() async {
    if (_activeChat == null) return;
    await fetchMessagesForActiveChat();
  }

  // ===== NEW FEATURE END =====
}
