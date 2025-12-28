import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_output.dart';
import '../chat/models/chat_message.dart';
import '../chat/chat_provider.dart';

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
      _isInitialized = await _speech.initialize();
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      _errorMessage = 'Speech init failed: $e';
      notifyListeners();
      return false;
    }
  }

  /* ================= VOICE LISTENING ================= */

  void startListening() async {
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
          _lastWords = result.recognizedWords;
          notifyListeners();
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          _smoothedSoundLevel =
              _smoothedSoundLevel * (1 - _soundSmoothing) +
              _soundLevel * _soundSmoothing;
          notifyListeners();
        },
      );
    } catch (e) {
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
      _handleUserInput(_lastWords, speak: true);
    }
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
    final response = await _fetchAIResponse(input);

    // SERO message → delegate to ChatProvider
    _chatProvider.addMessage(text: response, sender: MessageSender.sero);

    // Only update overlay-related state when requested
    if (showOverlay) {
      _lastResponse = response;
      _isThinking = false;
      notifyListeners();
    }

    if (speak) {
      _isSpeaking = true;
      notifyListeners();

      await _voiceOutput.speak(response);

      _isSpeaking = false;
      notifyListeners();
    }

    if (!suppressAutoListen && _autoListenAfterResponse) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_isListening && !_isThinking) {
        startListening();
      }
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
}
