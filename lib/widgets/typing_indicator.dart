import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/voice/voice_input.dart'; // To access the emotion color

class TypingIndicator extends StatefulWidget {
  final Color? color;
  const TypingIndicator({super.key, this.color});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1.5 seconds provides a more "sophisticated" and calm processing feel
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Connect to your global emotion color
    final voiceProvider = context.watch<VoiceInputProvider>();
    final activeColor = widget.color ?? voiceProvider.emotionColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Glassmorphic background matches ChatBubble
        color: activeColor.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(4), // Sharp corner for AI
        ),
        border: Border.all(color: activeColor.withOpacity(0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Calculate sine wave offset for each dot (staggered effect)
              // This creates a continuous fluid wave instead of individual pulses
              final double offset = index * 0.4;
              final double value = math.sin(
                (_controller.value * 2 * math.pi) - offset,
              );

              // Map sine (-1 to 1) to a normalized range (0 to 1)
              final double normalized = (value + 1) / 2;

              // Scale dots between 0.7x and 1.3x
              final double scale = 0.7 + (0.6 * normalized);

              // Opacity pulses between 0.2 and 1.0
              final double opacity = 0.2 + (0.8 * normalized);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: 6,
                transform: Matrix4.identity()
                  ..translate(0.0, -2.0 * normalized) // Subtle vertical float
                  ..scale(scale),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (opacity > 0.6) // Only glow when the dot is "bright"
                      BoxShadow(
                        color: activeColor.withOpacity(0.2 * opacity),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
