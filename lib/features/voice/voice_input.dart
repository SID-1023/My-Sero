import 'dart:io';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
// FIX: Updated to correct package import
import 'package:flutter_device_apps/flutter_device_apps.dart';

import 'voice_output.dart';
import '../chat/models/chat_message.dart';
import '../chat/chat_provider.dart';
import '../../core/sero_commands.dart';

/// Emotion categories derived from user input
enum Emotion { neutral, calm, sad, stressed }

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final VoiceOutput _voiceOutput = VoiceOutput();
  final ChatProvider _chatProvider;

  VoiceInputProvider({required ChatProvider chatProvider})
    : _chatProvider = chatProvider;

  /* ================= CORE STATES ================= */

  bool _isListening = false;
  bool _isInitialized = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _autoListenAfterResponse = true;

  // Tunables for listening behavior
  Duration _pauseFor = const Duration(
    seconds: 2,
  ); // default: 2s to avoid false stops
  String? _lastStatus;
  final List<String> _statusLog = [];

  // Tracks whether the last open-app attempt already posted a message/suggestion
  bool _lastOpenHandled = false;

  // Continuous listening support
  bool _continuousListening = false;
  String _lastProcessedText = '';
  Duration _continuousRestartDelay = const Duration(milliseconds: 400);

  /// Set the pause duration used by the speech listener (helps tune silence detection)
  void setPauseFor(Duration d) {
    _pauseFor = d;
  }

  /// Enable or disable continuous listening. When enabled, the provider will
  /// automatically restart listening after processing a final result.
  void setContinuousListening(bool enabled) {
    _continuousListening = enabled;
    if (enabled && !_isListening) startListening();
    notifyListeners();
  }

  /// Tune how long to wait before restarting listening in continuous mode
  void setContinuousRestartDelay(Duration d) {
    _continuousRestartDelay = d;
  }

  /// Retrieve a short status log for diagnostics
  List<String> get statusLog => List.unmodifiable(_statusLog);

  String? get lastStatus => _lastStatus;

  /* ================= AUDIO LEVEL ================= */

  double _soundLevel = 0.0;
  double _smoothedSoundLevel = 0.0;
  static const double _soundSmoothing = 0.15;

  /* ================= TEXT ================= */

  String _lastWords = "";
  String _lastResponse = "";
  String? _errorMessage;

  /* ================= EMOTION ================= */

  Emotion _currentEmotion = Emotion.neutral;
  Emotion get currentEmotion => _currentEmotion;

  Color get emotionColor {
    switch (_currentEmotion) {
      case Emotion.calm:
        return const Color(0xFF1AFF6B);
      case Emotion.sad:
        return const Color(0xFF4FC3F7);
      case Emotion.stressed:
        return const Color(0xFFFF5252);
      case Emotion.neutral:
        return const Color(0xFFD50000);
    }
  }

  /* ================= GETTERS ================= */

  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;
  bool get autoListenAfterResponse => _autoListenAfterResponse;
  double get soundLevel => _smoothedSoundLevel;
  String get lastWords => _lastWords;
  String get lastResponse => _lastResponse;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /* ================= SETTINGS ================= */

  void setAutoListenAfterResponse(bool enabled) {
    _autoListenAfterResponse = enabled;
    notifyListeners();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  String? _localeId;

  /* ================= INITIALIZATION ================= */

  Future<bool> initSpeech() async {
    _errorMessage = null;

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      _errorMessage = 'Microphone permission denied';
      notifyListeners();
      return false;
    }

    try {
      // Initialize with status & error callbacks so we can react quickly
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          // Keep a short status log to help diagnose devices that terminate early
          _lastStatus = status;
          _statusLog.insert(0, '${DateTime.now().toIso8601String()}:$status');
          if (_statusLog.length > 20) _statusLog.removeLast();

          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = error.errorMsg;
          _isListening = false;
          _statusLog.insert(
            0,
            '${DateTime.now().toIso8601String()}:ERROR:${error.errorMsg}',
          );
          if (_statusLog.length > 20) _statusLog.removeLast();
          notifyListeners();
        },
      );

      // Capture system locale to improve recognition accuracy
      try {
        final systemLocale = await _speech.systemLocale();
        _localeId = systemLocale?.localeId;
      } catch (_) {
        _localeId = null;
      }

      // If initialization succeeded but returned false, provide guidance
      if (!_isInitialized) {
        _errorMessage = 'Speech recognition not available on this device.';
        notifyListeners();
      }

      notifyListeners();
      return _isInitialized;
    } catch (e) {
      _errorMessage = 'Speech init failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Run a quick diagnostic to help surface why the microphone may not work.
  Future<Map<String, Object?>> diagnoseMicrophone() async {
    final map = <String, Object?>{};

    final perm = await Permission.microphone.status;
    map['permission'] = perm.toString();
    map['pauseForMs'] = _pauseFor.inMilliseconds;
    map['lastStatus'] = _lastStatus;
    map['statusLog'] = _statusLog.take(6).toList();

    try {
      if (!_isInitialized) {
        map['initialized'] = await initSpeech();
      } else {
        map['initialized'] = true;
      }

      try {
        final systemLocale = await _speech.systemLocale();
        map['systemLocale'] = systemLocale?.localeId;
      } catch (e) {
        map['systemLocale'] = null;
      }

      try {
        final locales = await _speech.locales();
        map['availableLocales'] = locales
            ?.map((l) => l.localeId)
            .take(6)
            .toList();
      } catch (_) {
        map['availableLocales'] = null;
      }

      map['errorMessage'] = _errorMessage;
    } catch (e) {
      map['diagnoseError'] = e.toString();
    }

    // Update public error message for quick UI visibility
    if (map['initialized'] == true &&
        (map['permission'] as String).contains('granted')) {
      _errorMessage = null;
    } else if ((map['permission'] as String).contains('denied')) {
      _errorMessage =
          'Microphone permission denied. Open settings to allow microphone access.';
    }

    notifyListeners();
    return map;
  }

  /// Returns a short, human readable diagnostic summary for displaying to users
  Future<String> getMicrophoneDiagnosticSummary() async {
    final diag = await diagnoseMicrophone();
    final permission = diag['permission'];
    final initialized = diag['initialized'];
    final sysLocale = diag['systemLocale'];

    final parts = <String>[];
    parts.add('Permission: $permission');
    parts.add('Initialized: $initialized');
    if (sysLocale != null) parts.add('Locale: $sysLocale');
    if (diag['errorMessage'] != null)
      parts.add('Error: ${diag['errorMessage']}');

    return parts.join(' • ');
  }

  /* ================= VOICE LISTENING ================= */

  /// Starts listening. Tries on-device first (fast) and falls back if necessary.
  void startListening({bool useOnDevice = true}) async {
    if (_isListening || _isSpeaking) return;

    if (!_isInitialized) {
      final ok = await initSpeech();
      if (!ok) return;
    }

    _lastWords = "";
    _isListening = true;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          // Update partial results for instant UI feedback
          _lastWords = result.recognizedWords;
          notifyListeners();

          // If this is a final recognition result, process it immediately.
          // This avoids waiting for a manual stop and enables quick interactions
          // similar to ChatGPT/Gemini voice behavior.
          if (result.finalResult) {
            _processRecognizedText(result.recognizedWords, speak: true);

            if (_continuousListening) {
              Future.delayed(_continuousRestartDelay, () {
                if (!_isSpeaking && !_isListening) startListening();
              });
            }
          }
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          _smoothedSoundLevel =
              _smoothedSoundLevel * (1 - _soundSmoothing) +
              _soundLevel * _soundSmoothing;
          notifyListeners();
        },
        // Fast & accurate settings
        listenMode: ListenMode.dictation,
        partialResults: true,
        pauseFor: _pauseFor,
        listenFor: const Duration(seconds: 30),
        cancelOnError: true,
        localeId: _localeId,
        // Prefer on-device recognition when available for lower latency
        onDevice: useOnDevice,
      );
    } catch (e) {
      // If on-device caused issues, retry without it once
      if (useOnDevice) {
        _errorMessage =
            'On-device listen failed, retrying with server-based recognition.';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 50));
        startListening(useOnDevice: false);
        return;
      }

      _errorMessage = 'Listen error: $e';
      _isListening = false;
      notifyListeners();
    }
  }

  void stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
    } catch (_) {}

    _isListening = false;
    _soundLevel = 0.0;
    _smoothedSoundLevel = 0.0;
    notifyListeners();

    if (_lastWords.isNotEmpty) {
      _processRecognizedText(_lastWords, speak: true);
      _lastWords = '';
    }
  }

  /// Safely process recognized text (avoids duplicate handling and stops the
  /// recognition engine before passing the text through the input pipeline).
  void _processRecognizedText(String text, {bool speak = true}) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (clean == _lastProcessedText) return; // ignore duplicates

    _lastProcessedText = clean;

    // Stop listening to avoid capturing the TTS output or continuing recognition
    if (_isListening) {
      try {
        _speech.stop();
      } catch (_) {}
      _isListening = false;
    }

    _lastWords = clean;
    notifyListeners();

    // Delegate into the existing handler which updates UI and finishes workflow
    _handleUserInput(clean, speak: speak, showOverlay: true);
  }

  /* ================= KEYBOARD INPUT ================= */

  void sendTextInput(
    String text, {
    bool suppressAutoListen = true,
    bool showOverlay = false,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _handleUserInput(
      cleanText,
      speak: false,
      suppressAutoListen: suppressAutoListen,
      showOverlay: showOverlay,
    );
  }

  /* ================= USER INPUT PIPELINE ================= */

  void _handleUserInput(
    String input, {
    required bool speak,
    bool suppressAutoListen = false,
    bool showOverlay = true,
  }) {
    // USER message → delegate to ChatProvider to keep sessions in sync
    _chatProvider.addMessage(text: input, sender: MessageSender.user);

    _lastWords = input;
    _currentEmotion = _classifyEmotion(input);
    _soundLevel = 0.0;
    _smoothedSoundLevel = 0.0;

    // Only set thinking state (and show overlay) when requested
    if (showOverlay) {
      _isThinking = true;
      notifyListeners();
    }

    _generateSeroResponse(
      input,
      speak: speak,
      suppressAutoListen: suppressAutoListen,
      showOverlay: showOverlay,
    );
  }

  /* ================= RESPONSE ENGINE ================= */

  Future<String> _fetchAIResponse(String input) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final lower = input.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'I am here. What do you require from the void?';
    }
    if (lower.contains('who are you')) {
      return 'I am Sero, an emotion-aware presence bound to this device.';
    }
    if (lower.contains('time')) {
      return 'The time is ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}.';
    }

    return 'I heard you, but my processors cannot yet fulfill that request.';
  }

  Future<void> _generateSeroResponse(
    String input, {
    required bool speak,
    bool suppressAutoListen = false,
    bool showOverlay = true,
  }) async {
    // Enter thinking state and classify emotion early
    if (showOverlay) {
      _isThinking = true;
      _currentEmotion = _classifyEmotion(input);
      notifyListeners();
    }

    String response;

    // First, handle direct "open/launch/start <app>" commands on Android.
    final openMatch = RegExp(
      r'\b(?:open|launch|start)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(input);
    if (openMatch != null) {
      final appName = openMatch.group(1)!.trim();

      if (Platform.isAndroid) {
        _lastOpenHandled = false;
        final ok = await _openAppByName(appName);

        // If _openAppByName already added a message/suggestion, don't duplicate it
        if (_lastOpenHandled) return;

        final msg = ok
            ? 'Opening $appName.'
            : "I couldn't find '$appName' on this device.";

        // Add reply and speak if requested
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        if (speak && msg.isNotEmpty) await _voiceOutput.speak(msg);
        return;
      } else {
        final msg =
            'Opening apps by voice is currently supported on Android only.';
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        if (speak) await _voiceOutput.speak(msg);
        return;
      }
    }

    // 1️⃣ Check local command engine first
    final intent = SeroCommandHandler.determineIntent(input);
    if (intent != null) {
      response = _handleLocalIntent(intent);
    } else {
      // 2️⃣ Fall back to AI
      response = await _fetchAIResponse(input);
    }

    // Add Sero message to chat history
    _chatProvider.addMessage(text: response, sender: MessageSender.sero);

    // Update overlay state
    if (showOverlay) {
      _lastResponse = response;
      _isThinking = false;
      notifyListeners();
    }

    // Speak the response if requested
    if (speak && response.isNotEmpty) {
      // Ensure we aren't listening while speaking to avoid picking up TTS
      if (_isListening) {
        try {
          await _speech.stop();
        } catch (_) {}
        _isListening = false;
        notifyListeners();
      }

      _isSpeaking = true;
      notifyListeners();

      // Use onComplete callback so UI updates exactly when TTS finishes
      await _voiceOutput.speak(
        response,
        onComplete: () {
          _isSpeaking = false;
          notifyListeners();
        },
      );

      // Ensure speaking flag is cleared if onComplete wasn't called for any reason
      _isSpeaking = false;
      notifyListeners();
    }

    // Optionally resume listening after a short delay
    if (!suppressAutoListen && _autoListenAfterResponse) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_isListening && !_isThinking) {
        startListening();
      }
    }
  }

  /// Handle locally recognized intents (fast, deterministic responses and actions)
  String _handleLocalIntent(String intent) {
    switch (intent) {
      case 'greeting':
        return "Greetings. I am online and ready.";
      case 'time':
        final now = DateTime.now();
        return "The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')}.";
      case 'settings':
        // Open settings (provided by this provider)
        openSettings();
        return "Opening your system settings now.";
      case 'identity':
        return "I am Sero. A digital presence designed to perceive and respond to your emotions.";
      case 'list_apps':
        // Asynchronously enumerate installed apps and show summary
        _listInstalledAppsAndShow();
        return "Listing installed apps now.";
      case 'navigation_home':
        // We don't have a BuildContext here; a future task could publish an
        // event that the UI listens to for navigation. For now, respond.
        return "Returning to the home interface.";
      case 'app_exit':
        return "Okay, exiting is not supported yet. I'll remember the intent.";
      case 'clear':
        _chatProvider.clear();
        return "Chat cleared.";
      default:
        return "Command recognized, but I am still learning how to execute it.";
    }
  }

  /* ================= EMOTION CLASSIFIER ================= */

  Emotion _classifyEmotion(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('sad') ||
        lower.contains('depressed') ||
        lower.contains('lonely')) {
      return Emotion.sad;
    }

    if (lower.contains('stressed') ||
        lower.contains('anxious') ||
        lower.contains('angry') ||
        lower.contains('overwhelm')) {
      return Emotion.stressed;
    }

    if (lower.contains('calm') ||
        lower.contains('relax') ||
        lower.contains('good') ||
        lower.contains('fine') ||
        lower.contains('thank')) {
      return Emotion.calm;
    }

    return Emotion.neutral;
  }

  /* ================= APP OPENING (ANDROID) ================= */

  // Small alias table to recognize common short names
  static const Map<String, List<String>> _appAliases = {
    // Social
    'instagram': ['insta', 'instagram'],
    'facebook': ['facebook', 'fb'],
    'messenger': ['fb-messenger', 'messenger'],
    'twitter': ['x', 'twitter'],
    'threads': ['threads'],
    'linkedin': ['linkedin'],
    'snapchat': ['snapchat'],
    'whatsapp': ['whatsapp', 'wa'],
    'telegram': ['telegram', 'tg'],

    // Google / System
    'chrome': ['chrome', 'google chrome', 'googlechrome'],
    'gmail': ['gmail'],
    'drive': ['drive'],
    'photos': ['photos'],
    'play store': ['play store', 'playstore', 'google play'],
    'google pay': ['gpay', 'google pay'],
    'assistant': ['assistant', 'google assistant'],
    'maps': ['maps', 'google maps', 'comgooglemaps'],

    // Shopping
    'amazon': ['amazon', 'amazon shopping', 'amazon prime'],
    'flipkart': ['flipkart'],
    'myntra': ['myntra'],
    'ajio': ['ajio'],
    'snapdeal': ['snapdeal'],

    // OTT / Music
    'netflix': ['netflix'],
    'prime video': ['prime video', 'amazon prime video'],
    'hotstar': ['hotstar', 'disney hotstar'],
    'disney': ['disney', 'disney plus'],
    'spotify': ['spotify'],
    'youtube music': ['youtube music'],
    'jio cinema': ['jio cinema'],
    'sony liv': ['sonyliv', 'sony liv'],
    'zee5': ['zee5'],

    // Messaging & Calls
    'messages': ['messages', 'message'],
    'phone': ['phone', 'dialer'],
    'contacts': ['contacts'],
    'truecaller': ['truecaller'],
  };

  // Simple Levenshtein distance implementation for fuzzy matching
  int _levenshteinDistance(String s, String t) {
    final n = s.length;
    final m = t.length;
    if (n == 0) return m;
    if (m == 0) return n;

    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) dp[i][0] = i;
    for (var j = 0; j <= m; j++) dp[0][j] = j;

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[n][m];
  }

  // FIX: Application changed to AppInfo
  int _scoreAppMatch(AppInfo app, String name) {
    final n = (app.appName ?? "").toLowerCase();
    final p = (app.packageName ?? "").toLowerCase();
    final lowerName = name.toLowerCase();

    // Exact match is best
    if (n == lowerName) return 1000;

    var score = 0;

    // Containment checks
    if (n.contains(lowerName)) score += 400;
    if (p.contains(lowerName)) score += 300;

    // Token prefix checks (helps partial words like 'insta')
    final tokens = n.split(RegExp(r'\s+'));
    if (tokens.any((t) => t.startsWith(lowerName))) score += 250;

    // Alias checks
    for (final entry in _appAliases.entries) {
      final key = entry.key;
      final aliases = entry.value;
      if (aliases.any((a) => a == lowerName) && n.contains(key)) {
        score += 500;
      }
    }

    // Levenshtein penalty - the closer the app name is, the better
    final ld = _levenshteinDistance(n, lowerName);
    score -= ld * 30;
    final ld2 = _levenshteinDistance(p, lowerName);
    score -= ld2 * 10;

    return score;
  }

  /// Attempts to open an installed Android app by fuzzy matching the app name.
  Future<bool> _openAppByName(String name) async {
    try {
      // FIX: DeviceApps changed to FlutterDeviceApps
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: false,
        onlyLaunchable: true,
      );

      final lowerName = name.toLowerCase();

      if (apps.isEmpty) {
        final msg = "I couldn't find any user-installed apps on this device.";
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        await _voiceOutput.speak(msg);
        return false;
      }

      // Score every candidate and pick the best match
      // FIX: Application changed to AppInfo
      final scored = <MapEntry<AppInfo, int>>[];
      for (final a in apps) {
        final s = _scoreAppMatch(a, lowerName);
        scored.add(MapEntry(a, s));
      }

      scored.sort((a, b) => b.value.compareTo(a.value));

      final top = scored.first;

      // If the top score passes a threshold, open it
      const threshold = 150;
      if (top.value >= threshold) {
        // FIX: DeviceApps changed to FlutterDeviceApps
        return await FlutterDeviceApps.openApp(top.key.packageName ?? "");
      }

      // Otherwise offer helpful suggestions to the user
      final suggestions = scored
          .where((e) => e.value > -1000)
          .take(5)
          .map((e) => e.key.appName)
          .toList();

      final msg = suggestions.isNotEmpty
          ? "I couldn't find '$name'. Did you mean: ${suggestions.join(', ')}?"
          : "I couldn't find '$name' on this device.";

      _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
      await _voiceOutput.speak(msg);

      // Indicate to the caller that we already responded with suggestions
      _lastOpenHandled = true;
      return false;
    } catch (e) {
      _errorMessage = 'Open app failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// List installed user apps, post to chat, and speak a brief summary.
  Future<void> _listInstalledAppsAndShow({int maxToSpeak = 8}) async {
    try {
      // FIX: DeviceApps changed to FlutterDeviceApps
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: false,
        onlyLaunchable: true,
      );

      if (apps.isEmpty) {
        final msg = 'No user-installed apps found on this device.';
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        await _voiceOutput.speak(msg);
        return;
      }

      apps.sort((a, b) => (a.appName ?? "").compareTo(b.appName ?? ""));
      final count = apps.length;

      final names = apps.map((a) => a.appName ?? "").toList();

      // Post a concise list (trimmed to avoid spamming the chat)
      final showCount = names.length > 50 ? 50 : names.length;
      final shortList = names.take(showCount).join(', ');
      final chatMsg =
          'Found $count user-installed apps: $shortList${names.length > showCount ? ', ...' : ''}';
      _chatProvider.addMessage(text: chatMsg, sender: MessageSender.sero);

      // Speak only the first few to keep TTS brief
      final speakList = names.take(maxToSpeak).join(', ');
      final speakMsg = 'I found $count apps. First ${maxToSpeak}: $speakList.';
      await _voiceOutput.speak(speakMsg);
    } catch (e) {
      _errorMessage = 'List apps failed: $e';
      notifyListeners();
    }
  }
}
