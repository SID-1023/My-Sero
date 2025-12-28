import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_output.dart';
import '../ui/chat_message.dart';

/// Simple emotion categories derived from user text input
enum Emotion { neutral, calm, sad, stressed }

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final VoiceOutput _voiceOutput = VoiceOutput();

  // ================= CORE STATES =================
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _autoListenAfterResponse = true;

  // ================= AUDIO LEVEL =================
  double _soundLevel = 0.0;
  double _smoothedSoundLevel = 0.0;
  static const double _soundSmoothing = 0.15;

  String _lastWords = "";
  String _lastResponse = "";
  String? _errorMessage;

  // ================= CHAT HISTORY =================
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  // ================= EMOTION =================
  Emotion _currentEmotion = Emotion.neutral;
  Emotion get currentEmotion => _currentEmotion;

  /// 🎨 Emotion-driven orb color
  Color get emotionColor {
    switch (_currentEmotion) {
      case Emotion.calm:
        return const Color(0xFF1AFF6B);
      case Emotion.sad:
        return const Color(0xFF4FC3F7);
      case Emotion.stressed:
        return const Color(0xFFFF5252);
      case Emotion.neutral:
      default:
        return const Color(0xFFD50000);
    }
  }

  // ================= GETTERS =================
  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;
  bool get autoListenAfterResponse => _autoListenAfterResponse;
  double get soundLevel => _smoothedSoundLevel;
  String get lastWords => _lastWords;
  String get lastResponse => _lastResponse;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  // ================= SETTINGS =================
  void setAutoListenAfterResponse(bool enabled) {
    _autoListenAfterResponse = enabled;
    notifyListeners();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  // ================= INITIALIZATION =================
  Future<bool> initSpeech() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      _errorMessage = 'Microphone permission denied';
      notifyListeners();
      return false;
    }

    _isInitialized = await _speech.initialize();
    notifyListeners();
    return _isInitialized;
  }

  // ================= VOICE LISTENING =================
  void startListening() async {
    if (!_isInitialized) {
      final ok = await initSpeech();
      if (!ok) return;
    }

    _lastWords = "";
    _isListening = true;
    notifyListeners();

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
  }

  void stopListening() async {
    await _speech.stop();
    _isListening = false;
    notifyListeners();

    if (_lastWords.isNotEmpty) {
      _handleUserInput(_lastWords, speak: true);
    }
  }

  // ================= KEYBOARD INPUT =================
  void sendTextInput(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _handleUserInput(cleanText, speak: false);
  }

  // ================= USER INPUT PIPELINE =================
  void _handleUserInput(String input, {required bool speak}) {
    // Add USER message
    _messages.add(
      ChatMessage(
        id: _id(),
        text: input,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ),
    );

    _lastWords = input;
    _currentEmotion = _classifyEmotion(input);
    _isThinking = true;
    _soundLevel = 0.0;
    _smoothedSoundLevel = 0.0;
    notifyListeners();

    _generateSeroResponse(input, speak: speak);
  }

  // ================= RESPONSE ENGINE =================
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
  }) async {
    final response = await _fetchAIResponse(input);

    // Add SERO message
    _messages.add(
      ChatMessage(
        id: _id(),
        text: response,
        sender: MessageSender.sero,
        timestamp: DateTime.now(),
      ),
    );

    _lastResponse = response;
    _isThinking = false;
    notifyListeners();

    if (speak) {
      _isSpeaking = true;
      notifyListeners();
      await _voiceOutput.speak(response);
      _isSpeaking = false;
      notifyListeners();
    }

    if (_autoListenAfterResponse) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_isListening && !_isThinking) {
        startListening();
      }
    }
  }

  // ================= EMOTION CLASSIFIER =================
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

  String _id() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
}
