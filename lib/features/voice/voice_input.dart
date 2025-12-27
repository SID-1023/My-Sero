import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'voice_output.dart';

/// Simple emotion categories derived from user text input
enum Emotion { neutral, calm, sad, stressed }

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final VoiceOutput _voiceOutput = VoiceOutput();

  bool _isListening = false;
  bool _isInitialized = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _autoListenAfterResponse = true;

  // Microphone sound-level monitoring (smoothed for UI)
  double _soundLevel = 0.0;
  double _smoothedSoundLevel = 0.0;
  static const double _soundSmoothing = 0.15;

  String _lastWords = "";
  String _lastResponse = "";
  String? _errorMessage;

  // ===== EMOTION STATE =====
  Emotion _currentEmotion = Emotion.neutral;
  Emotion get currentEmotion => _currentEmotion;

  /// 🎨 Emotion-driven orb color (USED BY UI)
  Color get emotionColor {
    switch (_currentEmotion) {
      case Emotion.calm:
        return const Color(0xFF1AFF6B); // calm green
      case Emotion.sad:
        return const Color(0xFF4FC3F7); // soft blue
      case Emotion.stressed:
        return const Color(0xFFFF5252); // stress red
      case Emotion.neutral:
      default:
        return const Color(0xFFD50000); // default Sero red
    }
  }

  // ===== GETTERS =====
  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;
  bool get autoListenAfterResponse => _autoListenAfterResponse;
  double get soundLevel => _smoothedSoundLevel;
  String get lastWords => _lastWords;
  String get lastResponse => _lastResponse;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  // ===== SETTINGS & PERMISSIONS =====

  /// Opens the device system settings for this specific app
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      _errorMessage = "Could not open settings: $e";
      notifyListeners();
    }
  }

  void setAutoListenAfterResponse(bool enabled) {
    _autoListenAfterResponse = enabled;
    notifyListeners();
  }

  // ===== INITIALIZATION =====
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
      _isInitialized = await _speech.initialize(
        onError: (val) {
          _errorMessage = 'Speech error: ${val.errorMsg ?? val.toString()}';
          notifyListeners();
        },
      );

      if (!_isInitialized) {
        _errorMessage = 'Speech engine failed to initialize';
      }

      notifyListeners();
      return _isInitialized;
    } catch (e) {
      _errorMessage = 'Speech init exception: $e';
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  // ===== LISTENING =====
  void startListening() async {
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
        listenFor: const Duration(seconds: 60),
      );
    } catch (e) {
      _errorMessage = 'Listen error: $e';
      _isListening = false;
      notifyListeners();
    }
  }

  void stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}

    _isListening = false;
    _soundLevel = 0.0;
    _smoothedSoundLevel = 0.0;
    notifyListeners();

    if (_lastWords.isNotEmpty) {
      _generateSeroResponse(_lastWords, speak: true);
    }
  }

  // ===== KEYBOARD INPUT =====
  void sendTextInput(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    // 1. Update the display words
    _lastWords = cleanText;

    // 2. Trigger the color shift based on the text
    _updateEmotion(cleanText);

    // 3. Set thinking state and clear mic visuals
    _isThinking = true;
    _soundLevel = 0.0;
    _smoothedSoundLevel = 0.0;
    notifyListeners();

    // 4. Fire the response pipeline (text-only for keyboard input)
    _generateSeroResponse(cleanText, speak: false);
  }

  /// Update the emotion immediately based on provided text so the orb updates
  void _updateEmotion(String text) {
    _currentEmotion = _classifyEmotion(text);
  }

  // ===== RESPONSE ENGINE =====
  Future<String> _fetchAIResponse(String input) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final lower = input.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'I am here. What do you require from the void?';
    } else if (lower.contains('who are you')) {
      return 'I am Sero, an emotion-aware presence bound to this device.';
    } else if (lower.contains('time')) {
      return 'The time is ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}.';
    }

    return 'I heard you, but my processors cannot yet fulfill that request.';
  }

  Future<void> _generateSeroResponse(String input, {bool speak = true}) async {
    _isThinking = true;

    // 🧠 Emotion detection (updates UI instantly)
    _currentEmotion = _classifyEmotion(input);
    notifyListeners();

    final response = await _fetchAIResponse(input);

    _lastResponse = response;
    _isThinking = false;
    notifyListeners();

    if (speak) {
      _isSpeaking = true;
      notifyListeners();

      await _voiceOutput.speak(
        response,
        onStart: () {
          _soundLevel = 0.0;
          _smoothedSoundLevel = 0.0;
          notifyListeners();
        },
        onComplete: () {
          _isSpeaking = false;
          notifyListeners();
        },
      );
    } else {
      // Clear mic visuals so the UI shows a quiet state when returning text-only
      _soundLevel = 0.0;
      _smoothedSoundLevel = 0.0;
      notifyListeners();
    }

    if (_autoListenAfterResponse) {
      await Future.delayed(const Duration(milliseconds: 800));
      // Only auto-listen if we aren't already listening or thinking
      if (!_isListening && !_isThinking) {
        startListening();
      }
    }
  }

  // ===== EMOTION CLASSIFIER =====
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
