import 'package:flutter/material.dart';
import '../../core/theme_tokens.dart';
import '../../features/voice/voice_input.dart';

class SeroAvatar extends StatelessWidget {
  final double size;
  final Emotion emotion;
  final String? initials;

  const SeroAvatar({
    Key? key,
    this.size = 40,
    this.emotion = Emotion.neutral,
    this.initials,
  }) : super(key: key);

  Color _borderColor() {
    switch (emotion) {
      case Emotion.calm:
        return SeroTokens.calm;
      case Emotion.sad:
        return SeroTokens.sad;
      case Emotion.stressed:
        return SeroTokens.stressed;
      default:
        return SeroTokens.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: _borderColor(), width: 2.5);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        color: Colors.black,
      ),
      alignment: Alignment.center,
      child: Text(
        initials ?? 'S',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
