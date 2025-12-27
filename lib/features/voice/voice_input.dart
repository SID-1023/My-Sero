import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'voice_output.dart';

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final VoiceOutput _voiceOutput = VoiceOutput();

  bool _isListening = false;
  bool _isInitialized = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _autoListenAfterResponse =
      true; // automatically listen after Sero speaks

  // Microphone sound-level monitoring (smoothed for UI)
  double _soundLevel = 0.0;
  double _smoothedSoundLevel = 0.0;
  static const double _soundSmoothing = 0.15;

  String _lastWords = "";
  String _lastResponse = "";
  String? _errorMessage;

  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;
  bool get autoListenAfterResponse => _autoListenAfterResponse;
  double get soundLevel => _smoothedSoundLevel;
  String get lastWords => _lastWords;
  String get lastResponse => _lastResponse;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /// Toggle whether Sero should automatically start listening after speaking
  void setAutoListenAfterResponse(bool enabled) {
    _autoListenAfterResponse = enabled;
    notifyListeners();
  }

  Future<bool> initSpeech() async {
    _errorMessage = null;

    // Prefer checking status first so we don't spam a dialog repeatedly
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      _errorMessage = 'Microphone permission denied';
      notifyListeners();
      print(_errorMessage);
      return false;
    }

    try {
      // Initialize speech engine
      _isInitialized = await _speech.initialize(
        onError: (val) {
          _errorMessage = 'Speech error: ${val.errorMsg ?? val.toString()}';
          print(_errorMessage);
          notifyListeners();
        },
        onStatus: (val) => print('Speech Status: $val'),
      );

      if (!_isInitialized) {
        _errorMessage = 'Speech engine failed to initialize';
        print(_errorMessage);
      }
      notifyListeners();
      return _isInitialized;
    } catch (e) {
      _errorMessage = 'Speech init exception: $e';
      print(_errorMessage);
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  void startListening() async {
    // Check if we need to initialize first
    if (!_isInitialized) {
      bool success = await initSpeech();
      if (!success) return;
    }

    if (!_isInitialized) return;

    _lastWords = "";
    _isListening = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          notifyListeners();
        },
        onSoundLevelChange: (level) {
          // level is usually a small double (device dependent), smooth it for UI
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
      debugPrint(_errorMessage);
      _isListening = false;
      notifyListeners();
    }
  }

  void stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Stop listen error: $e');
    }

    _isListening = false;
    _soundLevel = 0.0;
    _smoothedSoundLevel = 0.0;
    notifyListeners();

    // If we captured words, process them immediately
    if (_lastWords.isNotEmpty) {
      _generateSeroResponse(_lastWords);
    }
  }

  /// Simple local "Brain" - replace with API integration for richer responses
  Future<String> _fetchAIResponse(String input) async {
    // Placeholder for AI/backend integration. Right now it uses the simple rules below.
    // Replace this with an HTTP call to OpenAI/Gemini/etc. if you want real conversations.
    await Future.delayed(
      const Duration(milliseconds: 200),
    ); // simulate small network delay

    final String lower = input.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'I am here. What do you require from the void?';
    } else if (lower.contains('who are you') ||
        lower.contains('what are you')) {
      return 'I am Sero, an emotion-aware presence bound to this device.';
    } else if (lower.contains('time')) {
      return 'The current device time is ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}. Pleasant, isn\'t it?';
    }

    return 'I heard you, but my processors cannot yet fulfill that request.';
  }

  Future<void> _generateSeroResponse(String input) async {
    _isThinking = true;
    notifyListeners();

    // get response from the (current) Brain
    final response = await _fetchAIResponse(input);

    _lastResponse = response;
    _isThinking = false;
    _isSpeaking = true;
    notifyListeners();

    // Trigger TTS and listen for completion to toggle speaking state
    await _voiceOutput.speak(
      response,
      onStart: () {
        // Reset sound levels while TTS is playing so we don't accidentally pick up playback
        _soundLevel = 0.0;
        _smoothedSoundLevel = 0.0;
        notifyListeners();
      },
      onComplete: () async {
        _isSpeaking = false;
        notifyListeners();
      },
    );

    // After TTS completes, optionally start listening again for follow-up
    if (_autoListenAfterResponse) {
      // Short delay to avoid capturing the TTS audio as input
      await Future.delayed(const Duration(milliseconds: 800));

      // Ensure we still have permission and the engine is initialized
      if (!_isInitialized) {
        await initSpeech();
      }

      // Start listening automatically
      startListening();
    }
  }

  /// Helper to open app settings so a user can grant mic permission manually
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Unable to open app settings: $e');
    }
  }
}
