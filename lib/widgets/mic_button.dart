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
      // Using Long Press to trigger the mic
      onLongPressStart: (_) {
        if (voiceProvider.isInitialized) {
          voiceProvider.startListening();
        } else {
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
        }
      },
      onLongPressEnd: (_) {
        if (voiceProvider.isListening) voiceProvider.stopListening();
      },
      onTap: () {
        // If currently listening, a single tap should stop listening
        if (voiceProvider.isListening) {
          voiceProvider.stopListening();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Stopped listening"),
              duration: Duration(milliseconds: 700),
            ),
          );
          return;
        }

        // Otherwise, provide feedback that they should hold to speak
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hold the orb to speak"),
            duration: Duration(seconds: 1),
          ),
        );
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
                  isSpeaking: voiceProvider.isSpeaking,
                  soundLevel: voiceProvider.soundLevel,
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
  final bool isSpeaking;
  final double soundLevel;

  Mini3DPainter(
    this.progress, {
    required this.isListening,
    this.isSpeaking = false,
    this.soundLevel = 0.0,
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

    for (int i = 0; i < 3; i++) {
      // Slower rotation while speaking, faster when listening
      final double rotationSpeed =
          progress * 2 * pi * (isSpeaking ? 0.4 : (isListening ? 1.6 : 1.0));
      final double orbitOffset = i * (pi * 0.6);

      final double baseStroke = isListening ? 6.0 : (isSpeaking ? 5.0 : 4.0);
      final double strokeWidth =
          baseStroke * (1.0 + (soundLevel / 100.0)).clamp(1.0, 1.14);

      final Paint tubePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = isListening
            ? const Color(0xFFFF2E2E)
            : (isSpeaking ? const Color(0xFF8B0000) : const Color(0xFFD50000));

      // Increase glow opacity & width slightly with sound level (subtle, no shape change)
      final double baseGlowWidth = isListening
          ? 18.0
          : (isSpeaking ? 14.0 : 10.0);
      final double glowWidth =
          baseGlowWidth * (1.0 + (soundLevel / 140.0)).clamp(1.0, 1.12);
      final double baseOpacity = isListening ? 0.6 : (isSpeaking ? 0.55 : 0.32);
      final double glowOpacity = (baseOpacity + (soundLevel / 40.0)).clamp(
        0.0,
        0.88,
      );

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color =
            (isListening
                    ? const Color(0xFFFF1A1A)
                    : (isSpeaking
                          ? const Color(0xFF6B0000)
                          : const Color(0xFFFF1A1A)))
                .withOpacity(glowOpacity);

      final Path path = Path();
      for (double t = 0; t <= 2 * pi; t += 0.3) {
        double x = baseRadius * cos(t);
        double y = baseRadius * sin(t);
        double z = baseRadius * sin(t + orbitOffset);

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
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.soundLevel != soundLevel;
  }
}
