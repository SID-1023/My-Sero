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
  String _lastWords = "";
  String? _errorMessage;

  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;
  bool get autoListenAfterResponse => _autoListenAfterResponse;
  String get lastWords => _lastWords;
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
        onSoundLevelChange: (level) => debugPrint('Sound level: $level'),
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
    notifyListeners();

    // If we captured words, process them immediately
    if (_lastWords.isNotEmpty) {
      _generateSeroResponse(_lastWords);
    }
  }

  /// Simple local "Brain" - replace with API integration for richer responses
  Future<void> _generateSeroResponse(String input) async {
    _isThinking = true;
    notifyListeners();

    // Simulate short thinking delay
    await Future.delayed(const Duration(milliseconds: 350));

    final String lower = input.toLowerCase();
    String response;

    if (lower.contains('hello') || lower.contains('hi')) {
      response = 'I am here. What do you require from the void?';
    } else if (lower.contains('who are you') ||
        lower.contains('what are you')) {
      response = 'I am Sero, an emotion-aware presence bound to this device.';
    } else if (lower.contains('time')) {
      response =
          'The current device time is ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}. Pleasant, isn\'t it?';
    } else {
      response =
          'I heard you, but my processors cannot yet fulfill that request.';
    }

    _isThinking = false;
    _isSpeaking = true;
    notifyListeners();

    // Trigger TTS and listen for completion to toggle speaking state
    await _voiceOutput.speak(
      response,
      onStart: () {
        // Can trigger additional UI changes on start if needed
      },
      onComplete: () {
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
