import 'package:flutter/material.dart';

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
    // 1.2 seconds for a smooth, natural pulsing loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Subtle background bubble for the indicator
        color: Colors.white.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(0), // Sharp corner for AI messages
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Offset each dot's animation start by 0.2 to create the wave effect
              final double delay = index * 0.2;
              final double progress = (_controller.value - delay).clamp(
                0.0,
                1.0,
              );

              // Pulsing scale: goes from 0.8x size to 1.2x size
              final double scale =
                  0.8 +
                  (0.4 *
                      Curves.easeInOut.transform(
                        (progress * 2).clamp(0.0, 1.0),
                      ));

              // Pulsing opacity: dots fade in and out as they pulse
              final double opacity =
                  0.3 +
                  (0.7 *
                      Curves.easeInOut.transform(
                        (progress * 2).clamp(0.0, 1.0),
                      ));

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 7,
                width: 7,
                // FIXED: transform moved OUT of decoration and into Container
                transform: Matrix4.identity()..scale(scale),
                decoration: BoxDecoration(
                  color: (widget.color ?? Colors.white).withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
