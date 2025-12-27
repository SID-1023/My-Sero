import 'emotion_detector.dart';

class EmotionResponse {
  static String getResponse(Emotion emotion) {
    switch (emotion) {
      case Emotion.stressed:
        return "I hear you. Let's slow down together. Take a deep breath with me.";
      case Emotion.sad:
        return "I'm here for you. You're not alone in this moment.";
      case Emotion.angry:
        return "It sounds intense. Let's pause and breathe before reacting.";
      case Emotion.happy:
        return "That's wonderful to hear! Keep that positive energy going.";
      default:
        return "Tell me more about how you're feeling.";
    }
  }
}
