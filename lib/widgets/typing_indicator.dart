import 'dart:math' as math;
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color? color; // Now essentially required from parent to maintain theme
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
    // 1.5s duration creates a sophisticated, calm "processing" feel
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
    // UPDATED LOGIC: We no longer watch VoiceInputProvider.
    // We strictly use the color passed down, or a default fallback.
    final activeColor = widget.color ?? const Color(0xFF00FF11);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Glassmorphic "Ghost" Background synced with theme
        color: activeColor.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
          bottomLeft: Radius.circular(6), // Sharp AI tail
        ),
        border: Border.all(color: activeColor.withOpacity(0.15), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Continuous Fluid Wave Logic
              final double offset = index * 0.4;
              final double value = math.sin(
                (_controller.value * 2 * math.pi) - offset,
              );

              // Map sine (-1 to 1) to normalized (0 to 1)
              final double normalized = (value + 1) / 2;

              // Scale dots between 0.8x and 1.2x
              final double scale = 0.8 + (0.4 * normalized);

              // Opacity pulses between 0.3 and 1.0
              final double opacity = 0.3 + (0.7 * normalized);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: 6,
                transform: Matrix4.identity()
                  ..translate(0.0, -3.0 * normalized) // Staggered float
                  ..scale(scale),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (opacity > 0.7) // Glow pulses with brightness
                      BoxShadow(
                        color: activeColor.withOpacity(0.3 * opacity),
                        blurRadius: 10,
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
