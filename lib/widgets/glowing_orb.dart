import 'package:flutter/material.dart';

class GlowingOrb extends StatefulWidget {
  final bool isListening;
  const GlowingOrb({super.key, required this.isListening});

  @override
  State<GlowingOrb> createState() => _GlowingOrbState();
}

class _GlowingOrbState extends State<GlowingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 200 * (widget.isListening ? _pulseAnimation.value : 1.0),
          height: 200 * (widget.isListening ? _pulseAnimation.value : 1.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFF2E2E), // Bright Glow
                const Color(0xFFB11226).withOpacity(0.6), // Cosmic Red
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB11226).withOpacity(0.5),
                blurRadius: widget.isListening ? 50 : 20,
                spreadRadius: widget.isListening ? 10 : 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
