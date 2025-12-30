import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/voice/voice_input.dart';

class AssistantResponseBubble extends StatelessWidget {
  const AssistantResponseBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceInputProvider>(
      builder: (context, voice, child) {
        // Condition to show the bubble
        final bool isVisible =
            voice.lastResponse.isNotEmpty || voice.isThinking;

        // Display logic for thinking state vs response
        final String displayText = voice.isThinking
            ? 'Processing system query...'
            : voice.lastResponse;

        final Color emotionColor = voice.emotionColor;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
          // Moves from below the screen (-150) to its active position (140)
          bottom: isVisible ? 140 : -150,
          left: 20,
          right: 20,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isVisible ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        // Deep obsidian with a hint of the emotion color
                        color: const Color(0xFF0F0F13).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: emotionColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: emotionColor.withOpacity(0.05),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top "Branding" Row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: emotionColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "SERO UPLINK",
                                style: TextStyle(
                                  color: emotionColor.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // The actual response text
                          Text(
                            displayText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 17,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
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
