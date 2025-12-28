import 'dart:io';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_apps/device_apps.dart';

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
        final ok = await _openAppByName(appName);
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

  /// Attempts to open an installed Android app by fuzzy matching the app name.
  Future<bool> _openAppByName(String name) async {
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
      );

      final lowerName = name.toLowerCase();

      // Narrow down candidates by app name or package name containing the spoken name
      final candidates = apps.where((a) {
        final n = a.appName.toLowerCase();
        final p = a.packageName.toLowerCase();
        return n.contains(lowerName) || p.contains(lowerName);
      }).toList();

      if (candidates.isEmpty) return false;

      // Prefer exact name match if any
      var match = candidates.first;
      for (final c in candidates) {
        if (c.appName.toLowerCase() == lowerName) {
          match = c;
          break;
        }
      }

      return await DeviceApps.openApp(match.packageName);
    } catch (e) {
      _errorMessage = 'Open app failed: $e';
      notifyListeners();
      return false;
    }
  }
}
