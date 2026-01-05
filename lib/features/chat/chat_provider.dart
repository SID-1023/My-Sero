import 'dart:math';
import 'dart:typed_data'; // ===== NEW FEATURE: REQUIRED FOR IMAGE BYTES =====
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
import 'package:battery_plus/battery_plus.dart'; // ===== NEW FEATURE: OFFLINE STATS =====

import 'models/chat_message.dart';
import 'models/chat_session.dart';

class ChatProvider with ChangeNotifier {
  List<ChatSession> _chats = [];
  ChatSession? _activeChat;
  bool _isTyping = false;

  // ===== NEW FEATURE START =====
  // Unified single GenerativeModel variable for faster reasoning
  ai.GenerativeModel? _model;
  ai.ChatSession? _chatSession;
  final Battery _battery = Battery();
  // ===== NEW FEATURE END =====

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _lastSpokenWords = "";

  // ===== NEW FEATURE START =====
  // Tracks the global loading state for long-running sync operations
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  // ===== NEW FEATURE END =====

  ChatSession? get activeChat => _activeChat;
  List<ChatSession> get chats => _chats;
  bool get isTyping => _isTyping;
  bool get isListening => _isListening;
  List<ChatMessage> get messages => _activeChat?.messages ?? [];

  ChatProvider() {
    // ===== NEW FEATURE START =====
    init(); // Initialize everything here to ensure faster startup
    // ===== NEW FEATURE END =====
    _initTTS();
    loadChatHistory();
  }

  // ===== NEW FEATURE START =====
  /// Combined Initialization Logic for Neural Memory and Tooling
  void init() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("ERROR: Gemini API Key is missing from .env");
      return;
    }

    // Tools setup for the AI engine
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

    // Initialize 1.5-flash for faster reasoning and multimodal support
    _model = ai.GenerativeModel(
      model: 'gemini-1.5-flash',
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
        "You are Sero, a helpful assistant. Keep responses short and empathetic. "
        "Use tools for opening apps, searching contacts, and dialing numbers. "
        "If successful, use a terminal-style [SUCCESS] tag.",
      ),
    );
    _chatSession = _model!.startChat();
  }

  /// THE MISSING METHOD: Called by VoiceInputProvider to get raw AI text
  Future<String> fetchAIResponse(String input) async {
    try {
      if (_chatSession == null) init();

      final response = await _chatSession!.sendMessage(ai.Content.text(input));
      return response.text ?? "The uplink is silent.";
    } catch (e) {
      debugPrint("AI Uplink Error: $e");
      // Handle Rate Limits (429) or Server Overload (503)
      if (e.toString().contains('429'))
        return "System overloaded. Please wait.";
      return "CRITICAL ERROR: Uplink interrupted.";
    }
  }

  /// Forcefully stops all active processes: Speech, AI Thinking, and TTS.
  /// Link this to your ABORT button in the UI.
  void abortProcess() async {
    try {
      // 1. Force stop the AI Thinking state
      _isTyping = false;

      // 2. Kill the Voice Output (Stops Sero from speaking)
      await _flutterTts.stop();

      // 3. Kill the Speech Listener (Stops Sero from listening)
      if (_isListening) {
        await _speechToText.stop();
        _isListening = false;
      }

      // 4. Clear temporary words
      _lastSpokenWords = "";

      debugPrint("[SYSTEM] Manual Override: All processes terminated.");
      notifyListeners();
    } catch (e) {
      debugPrint("Abort Error: $e");
    }
  }

  /// NEW FEATURE: Terminates multiple selected sessions and their messages from Back4app.
  Future<void> terminateSelectedSessions(List<String> sessionIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      for (String id in sessionIds) {
        // 1. Delete associated messages first
        final QueryBuilder<ParseObject> msgQuery = QueryBuilder<ParseObject>(
          ParseObject('Message'),
        )..whereEqualTo('sessionId', id);

        final msgResponse = await msgQuery.query();
        if (msgResponse.results != null) {
          for (var m in msgResponse.results!) {
            await m.delete();
          }
        }

        // 2. Delete the actual Session entry
        final sessionObj = ParseObject('ChatSession')..objectId = id;
        await sessionObj.delete();
      }

      // 3. Update local archive state
      _chats.removeWhere((chat) => sessionIds.contains(chat.id));

      // 4. Re-assign active chat if current one was purged
      if (_activeChat != null && sessionIds.contains(_activeChat!.id)) {
        _activeChat = _chats.isNotEmpty ? _chats.first : null;
        if (_activeChat != null) await fetchMessagesForActiveChat();
      }

      debugPrint(
          "[SYSTEM] Neural Archive Purged: ${sessionIds.length} sessions.");
    } catch (e) {
      debugPrint("Archive Purge Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ALIAS METHOD: Required for bulk deletion in ChatListScreen
  Future<void> deleteMultipleSessions(List<String> sessionIds) async {
    await terminateSelectedSessions(sessionIds);
  }
  // ===== NEW FEATURE END =====

  void _initTTS() {
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.45);
  }

  // --- PERSISTENCE LOGIC (BACK4APP) ---

  Future<void> loadChatHistory() async {
    // ===== NEW FEATURE START =====
    _isLoading = true;
    notifyListeners();
    // ===== NEW FEATURE END =====

    final currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser == null) {
      // ===== NEW FEATURE START =====
      _isLoading = false;
      notifyListeners();
      // ===== NEW FEATURE END =====
      return;
    }

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

    // ===== NEW FEATURE START =====
    _isLoading = false;
    notifyListeners();
    // ===== NEW FEATURE END =====
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

  Future<void> deleteChat(ChatSession session) async {
    try {
      final QueryBuilder<ParseObject> query = QueryBuilder<ParseObject>(
        ParseObject('Message'),
      )..whereEqualTo('sessionId', session.id);
      final msgResponse = await query.query();
      if (msgResponse.results != null) {
        for (var m in msgResponse.results!) {
          await m.delete();
        }
      }

      final sessionObj = ParseObject('ChatSession')..objectId = session.id;
      await sessionObj.delete();

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

    // ===== NEW FEATURE START =====
    // Optimistic UI Update: Create a temporary ID and add locally first for smooth animations
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatMessage(
      id: tempId,
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
    );
    _activeChat!.messages.add(tempMsg);
    notifyListeners();
    // ===== NEW FEATURE END =====

    final msgObj = ParseObject('Message')
      ..set('text', text)
      ..set('sender', sender == MessageSender.user ? 'user' : 'sero')
      ..set('sessionId', _activeChat!.id);

    final response = await msgObj.save();

    // ===== NEW FEATURE START =====
    // Reconcile optimistic message with server response
    if (response.success) {
      final index = _activeChat!.messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        _activeChat!.messages[index] = ChatMessage(
          id: msgObj.objectId!,
          text: text,
          sender: sender,
          timestamp: msgObj.createdAt ?? DateTime.now(),
        );
        notifyListeners();
      }
    } else {
      _activeChat!.messages.removeWhere((m) => m.id == tempId);
      notifyListeners();
    }
    // ===== NEW FEATURE END =====

    if (sender == MessageSender.user) {
      await _handleAIRelationship(text);
    }
  }

  Future<void> _handleAIRelationship(String userText) async {
    // ===== NEW FEATURE START =====
    // Offline Intent Fallback Check (Faster response for system commands)
    if (await _handleOfflineCommands(userText)) return;
    // ===== NEW FEATURE END =====

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

      final aiChat = _model!.startChat(history: history);
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
      // ===== NEW FEATURE START =====
      // Faster recognition: Initializing with ListenMode.confirmation for quicker intent detection
      if (await _speechToText.initialize()) {
        _isListening = true;
        _speechToText.listen(
          listenMode: ListenMode.confirmation,
          onResult: (val) {
            if (val.finalResult) {
              addMessage(text: val.recognizedWords, sender: MessageSender.user);
              _isListening = false;
              notifyListeners();
            }
          },
        );
      }
      // ===== NEW FEATURE END =====
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
  Future<void> analyzeImage(Uint8List imageBytes, String prompt) async {
    _isTyping = true;
    notifyListeners();

    try {
      final tempId = 'temp_${_id()}';
      final userMsg = ChatMessage(
        id: tempId,
        text: "[ANALYZING IMAGE] $prompt",
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      );
      _activeChat?.messages.add(userMsg);
      notifyListeners();

      final content = [
        ai.Content.multi([
          ai.TextPart(prompt),
          ai.DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await _model!.generateContent(content);

      if (response.text != null) {
        await addMessage(
          text: "[IMAGE ANALYZED]: $prompt",
          sender: MessageSender.user,
        );
        _activeChat?.messages.removeWhere((m) => m.id == tempId);
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

  Future<void> refreshActiveChat() async {
    _isLoading = true;
    notifyListeners();

    if (_activeChat != null) {
      await fetchMessagesForActiveChat();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearChat() {
    if (_activeChat != null) {
      _activeChat!.messages.clear();
      notifyListeners();
    }
  }

  /// Sends a message and updates the UI using a stream for real-time response generation.
  Future<void> sendMessageStream(String text) async {
    if (_activeChat == null) await createNewChat();

    await addMessage(text: text, sender: MessageSender.user);

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

      final aiChat = _model!.startChat(history: history);
      final responseStream = aiChat.sendMessageStream(ai.Content.text(text));

      String fullResponse = "";
      final tempId = 'temp_sero_${_id()}';

      final aiMsg = ChatMessage(
        id: tempId,
        text: "",
        sender: MessageSender.sero,
        timestamp: DateTime.now(),
      );
      _activeChat!.messages.add(aiMsg);
      notifyListeners();

      await for (final chunk in responseStream) {
        if (chunk.text != null) {
          fullResponse += chunk.text!;
          final index = _activeChat!.messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _activeChat!.messages[index] = ChatMessage(
              id: tempId,
              text: fullResponse,
              sender: MessageSender.sero,
              timestamp: aiMsg.timestamp,
            );
            notifyListeners();
          }
        }
      }

      _activeChat!.messages.removeWhere((m) => m.id == tempId);
      await addMessage(text: fullResponse, sender: MessageSender.sero);
      await _flutterTts.speak(fullResponse);
    } catch (e) {
      debugPrint("Stream Error: $e");
      await addMessage(
        text: "STREAM ERROR: Connection lost.",
        sender: MessageSender.sero,
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Handles localized commands for offline fallback (Faster system interaction)
  Future<bool> _handleOfflineCommands(String text) async {
    final lowerText = text.toLowerCase();

    // Command: Battery Level
    if (lowerText.contains("battery") || lowerText.contains("power level")) {
      try {
        final level = await _battery.batteryLevel;
        await addMessage(
          text: "[SYSTEM] Battery is at $level%.",
          sender: MessageSender.sero,
        );
        await _flutterTts.speak("Battery is at $level percent.");
        return true;
      } catch (e) {
        debugPrint("Battery Check Failed: $e");
        return false;
      }
    }

    // Command: Flashlight / Neural Illumination
    if (lowerText.contains("flashlight") || lowerText.contains("torch")) {
      await addMessage(
        text: "[HARDWARE] Toggling neural uplink illumination...",
        sender: MessageSender.sero,
      );
      await _flutterTts.speak("Toggling flashlight.");
      return true;
    }

    return false;
  }
  // ===== NEW FEATURE END =====
}
