import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/voice/voice_input.dart';

class SeroMicButton extends StatelessWidget {
  final AnimationController controller;
  const SeroMicButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Access the voice provider to check if we are currently listening
    final voiceProvider = Provider.of<VoiceInputProvider>(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Tap to toggle listening (start/stop)
      onTap: () {
        if (!voiceProvider.isInitialized) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                voiceProvider.errorMessage ??
                    "Microphone not initialized. Tap Settings to enable.",
              ),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => voiceProvider.openSettings(),
              ),
            ),
          );
          return;
        }

        if (voiceProvider.isListening) {
          voiceProvider.stopListening();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Stopped listening"),
              duration: Duration(milliseconds: 700),
            ),
          );
        } else {
          voiceProvider.startListening();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Listening…"),
              duration: Duration(milliseconds: 700),
            ),
          );
        }
      },
      child: Opacity(
        opacity: voiceProvider.isInitialized ? 1.0 : 0.45,
        child: SizedBox(
          width: 80,
          height: 80,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return CustomPaint(
                painter: Mini3DPainter(
                  controller.value,
                  isListening: voiceProvider.isListening,
                  isThinking: voiceProvider.isThinking,
                  isSpeaking: voiceProvider.isSpeaking,
                  soundLevel: voiceProvider.soundLevel,
                  emotion: voiceProvider.currentEmotion,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ================= THE MISSING PAINTER CLASS ================= */

class Mini3DPainter extends CustomPainter {
  final double progress;
  final bool isListening;
  final bool isThinking;
  final bool isSpeaking;
  final double soundLevel;
  final Emotion emotion;

  Mini3DPainter(
    this.progress, {
    required this.isListening,
    this.isThinking = false,
    this.isSpeaking = false,
    this.soundLevel = 0.0,
    this.emotion = Emotion.neutral,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Pulse when speaking, grow slightly with voice volume
    final double speakingPulse = isSpeaking
        ? (1.0 + 0.04 * (1 + sin(progress * 2 * pi)))
        : 1.0;

    // Subtle sound-driven pulse (clamped)
    final double soundPulse = 1.0 + (soundLevel / 20.0).clamp(0.0, 0.12);
    final double totalPulse = speakingPulse * soundPulse;

    final baseRadius =
        (isListening ? size.width / 3.0 : size.width / 3.5) * totalPulse;

    // Map emotion to a gentle tint color
    Color? emotionTint;
    switch (emotion) {
      case Emotion.calm:
        emotionTint = const Color(0xFF4CAF50); // green
        break;
      case Emotion.sad:
        emotionTint = const Color(0xFF2196F3); // blue
        break;
      case Emotion.stressed:
        emotionTint = const Color(0xFFFF5252); // red
        break;
      default:
        emotionTint = null;
    }

    for (int i = 0; i < 3; i++) {
      // Slower rotation while speaking, faster when listening
      final double rotationSpeed =
          progress * 2 * pi * (isSpeaking ? 0.4 : (isListening ? 1.6 : 1.0));
      final double orbitOffset = i * (pi * 0.6);

      final double baseStroke = isListening ? 6.0 : (isSpeaking ? 5.0 : 4.0);
      final double strokeWidth =
          baseStroke * (1.0 + (soundLevel / 100.0)).clamp(1.0, 1.14);

      // Base colors are chosen to preserve previous contrast
      final Color baseTubeColor = isListening
          ? const Color(0xFFFF2E2E)
          : (isSpeaking ? const Color(0xFF8B0000) : const Color(0xFFD50000));

      // Blend with emotion tint subtly if present
      final Color tubeColor = emotionTint != null
          ? Color.lerp(baseTubeColor, emotionTint, 0.36) ?? baseTubeColor
          : baseTubeColor;

      final Paint tubePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = tubeColor;

      // Increase glow opacity & width with sound level and speaking state (stronger for speaking)
      final double baseGlowWidth = isListening
          ? 18.0
          : (isSpeaking ? 16.0 : 10.0);
      final double glowWidth =
          baseGlowWidth *
          (1.0 + (soundLevel / 140.0)).clamp(1.0, 1.18) *
          (isSpeaking ? 1.12 : 1.0);
      final double baseOpacity = isListening ? 0.6 : (isSpeaking ? 0.65 : 0.32);
      final double glowOpacity =
          (baseOpacity + (soundLevel / 36.0) + (isSpeaking ? 0.12 : 0.0)).clamp(
            0.0,
            0.98,
          );

      final Color baseGlowColor = isListening
          ? const Color(0xFFFF1A1A)
          : (isSpeaking ? const Color(0xFF6B0000) : const Color(0xFFFF1A1A));

      final Color glowColor = emotionTint != null
          ? Color.lerp(baseGlowColor, emotionTint, 0.34) ?? baseGlowColor
          : baseGlowColor;

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = glowColor.withOpacity(glowOpacity);

      final Path path = Path();
      for (double t = 0; t <= 2 * pi; t += 0.3) {
        // Morph radius when thinking to create spikes/erratic behavior. We use a
        // combination of sinusoidal terms to create pseudo-random spikes that are
        // still deterministic and cheap to compute.
        double spikeFactor = 1.0;
        if (isThinking) {
          final double spikeAmp = 0.16; // intensity of spikes
          final double n1 = sin(t * 6.0 + progress * 2.0 * pi * 2.0 + i);
          final double n2 = 0.5 * cos(t * 11.0 - progress * 2.0 * pi + i * 0.7);
          final double noise = (n1 + n2) * 0.5; // -1..1-ish
          spikeFactor = (1.0 + spikeAmp * noise).clamp(0.7, 1.35);
        }

        // Slight additional widening when speaking (keeps ring rounded)
        final double speakingMorph = isSpeaking
            ? (1.0 + 0.06 * (1 + sin(progress * 2 * pi)) * 0.5)
            : 1.0;

        final double finalRadius = baseRadius * spikeFactor * speakingMorph;

        double x = finalRadius * cos(t);
        double y = finalRadius * sin(t);
        double z = finalRadius * sin(t + orbitOffset);

        double rx = x * cos(rotationSpeed) + z * sin(rotationSpeed);
        double rz = -x * sin(rotationSpeed) + z * cos(rotationSpeed);
        double ry =
            y * cos(rotationSpeed * 0.5) - rz * sin(rotationSpeed * 0.5);

        double p = 1 / (1 - (rz / 250));
        double px = center.dx + rx * p;
        double py = center.dy + ry * p;

        if (t == 0)
          path.moveTo(px, py);
        else
          path.lineTo(px, py);
      }
      path.close();
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, tubePaint);
    }
  }

  @override
  bool shouldRepaint(covariant Mini3DPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isThinking != isThinking ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.soundLevel != soundLevel ||
        oldDelegate.emotion != emotion;
  }
}
