import 'dart:io';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:flutter/services.dart'; // Added for Haptics

import 'voice_output.dart';
import '../chat/models/chat_message.dart';
import '../chat/chat_provider.dart';
import '../../core/sero_commands.dart';

/// Emotion categories derived from user input
enum Emotion { neutral, calm, sad, stressed }

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final VoiceOutput _voiceOutput = VoiceOutput();
  ChatProvider _chatProvider; // Changed to non-final for updateChatProvider

  VoiceInputProvider({required ChatProvider chatProvider})
    : _chatProvider = chatProvider;

  /// Syncs ChatProvider if updated via ProxyProvider in main.dart
  void updateChatProvider(ChatProvider newProvider) {
    _chatProvider = newProvider;
  }

  /* ================= SETTINGS & PROFILE STATE ================= */

  String _userName = "User";
  String _userHandle = "user_sero";
  Color _customAccentColor = const Color(0xFFD50000);
  bool _useSystemEmotionColor = true;

  String get userName => _userName;
  String get userHandle => _userHandle;
  Color get customAccentColor => _customAccentColor;

  void updateProfile({String? name, String? handle}) {
    if (name != null) _userName = name;
    if (handle != null) _userHandle = handle;
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _customAccentColor = color;
    _useSystemEmotionColor = false;
    notifyListeners();
  }

  void resetToEmotionColor() {
    _useSystemEmotionColor = true;
    notifyListeners();
  }

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

  /* ================= EMOTION & COLOR LOGIC ================= */

  Emotion _currentEmotion = Emotion.neutral;
  Emotion get currentEmotion => _currentEmotion;

  /// Returns the UI accent color.
  /// Mood detection still runs in the background, but the color remains constant.
  Color get emotionColor {
    // We ignore the _currentEmotion switch entirely to keep the UI professional.
    // If a custom color is set in settings, use that; otherwise, default to Sero Green.
    if (!_useSystemEmotionColor) return _customAccentColor;

    // This is your "Top Notch" Sero Green.
    // It will now stay this color even if you are angry, sad, or stressed.
    return const Color(0xFF00FF11);
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

    HapticFeedback.lightImpact(); // Provide physical feedback when starting
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
      return 'I am here, $_userName. What do you require from the void?';
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

        // Ensure thinking state stops
        _isThinking = false;
        notifyListeners();
        return;
      } else {
        final msg =
            'Opening apps by voice is currently supported on Android only.';
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        if (speak) await _voiceOutput.speak(msg);
        _isThinking = false;
        notifyListeners();
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
        return "Greetings, $_userName. I am online and ready.";
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

  static const Map<String, List<String>> _appAliases = {
    'instagram': ['insta', 'ig', 'reels', 'instagram'],
    'facebook': ['fb', 'facebook', 'meta'],
    'messenger': ['fb-messenger', 'messenger', 'chat'],
    'twitter': ['x', 'twitter', 'twt'],
    'threads': ['threads', 'meta threads'],
    'linkedin': ['linkedin', 'jobs', 'professional'],
    'snapchat': ['snap', 'snapchat', 'sc'],
    'whatsapp': ['whatsapp', 'wa', 'watsapp'],
    'telegram': ['telegram', 'tg', 'tele'],
    'discord': ['discord', 'dc', 'gaming chat'],
    'reddit': ['reddit', 'forum'],
    'pinterest': ['pinterest', 'pin', 'ideas'],
    'tiktok': ['tiktok', 'tk', 'douyin'],
    'skype': ['skype', 'video call'],
    'zoom': ['zoom', 'meeting', 'video conference'],
    'teams': ['teams', 'microsoft teams', 'msteams'],
    'slack': ['slack', 'workspace'],
    'signal': ['signal', 'private messenger'],
    'viber': ['viber'],
    'line': ['line messenger'],
    'wechat': ['wechat', 'weixin'],
    'notes': [
      'notes',
      'keep',
      'memo',
      'notepad',
      'com.google.android.keep',
      'com.samsung.android.app.notes',
      'com.miui.notes',
    ],
    'album': [
      'album',
      'gallery',
      'photos',
      'images',
      'com.android.gallery3d',
      'com.sec.android.gallery3d',
      'com.miui.gallery',
    ],
    'chrome': ['chrome', 'google chrome', 'browser'],
    'gmail': ['gmail', 'google mail', 'email'],
    'drive': ['drive', 'google drive', 'cloud storage'],
    'photos': ['photos', 'google photos', 'gallery', 'album', 'images', 'pics'],
    'play store': ['play store', 'playstore', 'google play', 'market'],
    'google pay': ['gpay', 'google pay', 'wallet'],
    'assistant': ['assistant', 'google assistant', 'hey google'],
    'maps': ['maps', 'google maps', 'navigation', 'gps', 'comgooglemaps'],
    'camera': ['camera', 'cam', 'selfie', 'video recorder', 'lens'],
    'calendar': ['calendar', 'cal', 'google calendar', 'events'],
    'keep': ['keep', 'google keep', 'notes'],
    'clock': ['clock', 'alarm', 'timer', 'stopwatch'],
    'calculator': ['calculator', 'calc'],
    'files': ['files', 'file manager', 'explorer', 'downloads'],
    'settings': ['settings', 'config', 'setup', 'preferences'],
    'contacts': ['contacts', 'people', 'address book'],
    'phone': ['phone', 'dialer', 'calls'],
    'messages': ['messages', 'message', 'sms', 'text'],
    'youtube': ['youtube', 'yt', 'videos'],
    'amazon': ['amazon', 'amazon shopping', 'amazon prime'],
    'flipkart': ['flipkart', 'fk'],
    'myntra': ['myntra'],
    'ajio': ['ajio'],
    'meesho': ['meesho'],
    'nykaa': ['nykaa'],
    'ebay': ['ebay'],
    'aliexpress': ['aliexpress'],
    'shein': ['shein'],
    'temu': ['temu'],
    'etsy': ['etsy'],
    'walmart': ['walmart'],
    'target': ['target'],
    'shopee': ['shopee'],
    'netflix': ['netflix', 'movies'],
    'prime video': ['prime video', 'amazon prime video', 'pv'],
    'hotstar': ['hotstar', 'disney hotstar', 'disney+'],
    'disney': ['disney', 'disney plus'],
    'hulu': ['hulu'],
    'hbo max': ['hbo', 'max'],
    'crunchyroll': ['crunchyroll', 'anime'],
    'spotify': ['spotify', 'music'],
    'youtube music': ['youtube music', 'yt music'],
    'apple music': ['apple music'],
    'soundcloud': ['soundcloud'],
    'shazam': ['shazam', 'song id'],
    'jio cinema': ['jio cinema', 'jiocinema'],
    'sony liv': ['sonyliv', 'sony liv'],
    'zee5': ['zee5'],
    'voot': ['voot'],
    'gaana': ['gaana'],
    'wynk': ['wynk'],
    'chatgpt': ['chatgpt', 'openai', 'gpt', 'ai chat'],
    'gemini': ['gemini', 'google ai', 'bard'],
    'copilot': ['copilot', 'microsoft ai', 'bing'],
    'claude': ['claude', 'anthropic'],
    'canva': ['canva', 'design', 'graphic'],
    'notion': ['notion', 'workspace', 'wiki'],
    'evernote': ['evernote'],
    'adobe acrobat': ['pdf', 'acrobat', 'reader'],
    'wps office': ['wps', 'office', 'word', 'excel'],
    'dropbox': ['dropbox'],
    'onedrive': ['onedrive', 'microsoft cloud'],
    'zomato': ['zomato', 'food delivery'],
    'swiggy': ['swiggy', 'instamart'],
    'ubereats': ['uber eats', 'food'],
    'uber': ['uber', 'cab', 'taxi'],
    'ola': ['ola'],
    'rapido': ['rapido', 'bike taxi'],
    'airbnb': ['airbnb', 'hotel'],
    'booking': ['booking.com', 'hotels'],
    'irctc': ['irctc', 'train'],
    'makemytrip': ['mmt', 'makemytrip'],
    'phonepe': ['phonepe', 'pp'],
    'paytm': ['paytm'],
    'paypal': ['paypal'],
    'venmo': ['venmo'],
    'cashapp': ['cash app'],
    'binance': ['binance', 'crypto'],
    'coinbase': ['coinbase'],
    'truecaller': ['truecaller', 'caller id'],
    'strava': ['strava', 'running', 'cycling'],
    'fitbit': ['fitbit'],
    'myfitnesspal': ['calories', 'diet', 'fitness'],
    'calm': ['calm', 'meditation', 'sleep'],
    'duolingo': ['duolingo', 'languages'],
    'headspace': ['headspace'],
  };

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

  int _scoreAppMatch(AppInfo app, String name) {
    final n = (app.appName ?? "").toLowerCase();
    final p = (app.packageName ?? "").toLowerCase();
    final lowerName = name.toLowerCase();

    for (final entry in _appAliases.entries) {
      if (entry.value.contains(lowerName)) {
        if (p.contains(entry.key) || n.contains(entry.key)) return 2000;
      }
    }

    if (n == lowerName) return 1500;
    var score = 0;
    if (n.contains(lowerName)) score += 500;
    if (p.contains(lowerName)) score += 400;
    final tokens = n.split(RegExp(r'\s+'));
    if (tokens.any((t) => t.startsWith(lowerName))) score += 250;
    final ld = _levenshteinDistance(n, lowerName);
    score -= ld * 30;
    final ld2 = _levenshteinDistance(p, lowerName);
    score -= ld2 * 10;
    return score;
  }

  Future<bool> _openAppByName(String name) async {
    try {
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
      );

      final lowerName = name.toLowerCase();
      if (apps.isEmpty) {
        final msg = "I couldn't find any apps on this device.";
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        await _voiceOutput.speak(msg);
        return false;
      }

      final scored = <MapEntry<AppInfo, int>>[];
      for (final a in apps) {
        final s = _scoreAppMatch(a, lowerName);
        scored.add(MapEntry(a, s));
      }

      scored.sort((a, b) => b.value.compareTo(a.value));
      final top = scored.first;

      if (top.value >= 150) {
        return await FlutterDeviceApps.openApp(top.key.packageName ?? "");
      }

      final suggestions = scored
          .where((e) => e.value > 0)
          .take(5)
          .map((e) => e.key.appName)
          .toList();

      final msg = suggestions.isNotEmpty
          ? "I couldn't find '$name'. Did you mean: ${suggestions.join(', ')}?"
          : "I couldn't find '$name' on this device.";

      _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
      await _voiceOutput.speak(msg);
      _lastOpenHandled = true;
      return false;
    } catch (e) {
      _errorMessage = 'Open app failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _listInstalledAppsAndShow({int maxToSpeak = 8}) async {
    try {
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
      );

      if (apps.isEmpty) {
        final msg = 'No apps found on this device.';
        _chatProvider.addMessage(text: msg, sender: MessageSender.sero);
        await _voiceOutput.speak(msg);
        return;
      }

      apps.sort((a, b) => (a.appName ?? "").compareTo(b.appName ?? ""));
      final names = apps.map((a) => a.appName ?? "").toList();
      final showCount = names.length > 50 ? 50 : names.length;
      final shortList = names.take(showCount).join(', ');

      _chatProvider.addMessage(
        text:
            'Found ${apps.length} apps: $shortList${names.length > showCount ? ', ...' : ''}',
        sender: MessageSender.sero,
      );

      final speakMsg =
          'I found ${apps.length} apps. Examples include: ${names.take(maxToSpeak).join(', ')}.';
      await _voiceOutput.speak(speakMsg);
    } catch (e) {
      _errorMessage = 'List apps failed: $e';
      notifyListeners();
    }
  }
}
