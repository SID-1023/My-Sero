import 'package:flutter/foundation.dart';

/// Copilot-friendly command intent handler for quick local command recognition.
///
/// Add categories to `_intentMap` and Copilot will suggest keywords as you
/// begin typing category names (e.g., 'music', 'weather', 'timers').
class SeroCommandHandler {
  // Intent Mapping: Add a category here, and Copilot will help you fill it!
  static final Map<String, List<String>> _intentMap = {
    'greeting': ['hi', 'hello', 'hey', 'wake up', 'are you there'],
    'settings': ['open settings', 'go to settings', 'configure', 'setup'],
    'navigation_home': ['go home', 'open home', 'main screen', 'back to start'],
    'time': ['time', 'what time', 'current time', 'clock'],
    'date': ['date', 'today', 'what day'],
    'identity': ['who are you', 'your name', 'what are you'],
    'mood_check': ['how are you', 'how do you feel', 'are you happy'],
    'volume_control': ['volume', 'mute', 'louder', 'quieter'],
    'app_exit': ['close app', 'exit', 'quit', 'stop sero'],
    'clear': ['clear screen', 'reset chat', 'start over'],
    // ADD NEW CATEGORIES HERE: Copilot will likely suggest 'weather', 'music', etc.
  };

  /// Main logic to find the Intent from spoken text
  static String? determineIntent(String input) {
    final lowerInput = input.toLowerCase();

    for (var entry in _intentMap.entries) {
      if (entry.value.any((keyword) => lowerInput.contains(keyword))) {
        return entry.key;
      }
    }
    return null; // No local command found, send to AI
  }

  /// Add or replace an intent category at runtime. Useful for extending the
  /// command set programmatically or through Copilot-assisted editing.
  static void addOrReplaceIntent(String category, List<String> keywords) {
    _intentMap[category] = keywords;
  }

  /// Returns a copy of the current intent map for inspection / debugging.
  static Map<String, List<String>> get intentMap =>
      Map.unmodifiable(_intentMap);
}
