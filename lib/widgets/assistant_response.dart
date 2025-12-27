import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/voice/voice_input.dart';

class AssistantResponseBubble extends StatelessWidget {
  const AssistantResponseBubble({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceInputProvider>(
      builder: (_, voice, __) {
        final visible = (voice.lastResponse.isNotEmpty) || voice.isThinking;
        final text = voice.isThinking ? '...thinking' : voice.lastResponse;

        return IgnorePointer(
          ignoring: true,
          child: AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            bottom: visible ? 100 : -120,
            left: 24,
            right: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: visible ? 1 : 0,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
