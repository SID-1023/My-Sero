import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceOutput {
  final FlutterTts _tts = FlutterTts();

  VoiceOutput() {
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(0.9); // Slightly deeper, "AI" feel
    await _tts.setSpeechRate(0.45); // Calm, measured pace
    await _tts.setVolume(1.0);
  }

  /// Speak text and optionally notify when started/completed.
  Future<void> speak(
    String text, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) async {
    if (text.isEmpty) return;

    final completer = Completer<void>();

    _tts.setStartHandler(() {
      try {
        if (onStart != null) onStart();
      } catch (_) {}
    });

    _tts.setCompletionHandler(() {
      try {
        if (onComplete != null) onComplete();
      } catch (_) {}
      if (!completer.isCompleted) completer.complete();
    });

    _tts.setErrorHandler((msg) {
      if (!completer.isCompleted) completer.complete();
    });

    await _tts.speak(text);

    // Wait until the completion handler is invoked
    await completer.future;
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
