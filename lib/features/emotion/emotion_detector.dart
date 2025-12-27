enum Emotion { happy, sad, stressed, angry, neutral }

class EmotionDetector {
  Emotion detect(String text) {
    text = text.toLowerCase();

    if (text.contains('stress') ||
        text.contains('tired') ||
        text.contains('pressure')) {
      return Emotion.stressed;
    }
    if (text.contains('sad') || text.contains('lonely')) {
      return Emotion.sad;
    }
    if (text.contains('angry') || text.contains('hate')) {
      return Emotion.angry;
    }
    if (text.contains('happy') || text.contains('good')) {
      return Emotion.happy;
    }
    return Emotion.neutral;
  }
}
