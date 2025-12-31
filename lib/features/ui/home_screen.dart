import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback
import 'package:provider/provider.dart';

import '../voice/voice_input.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/assistant_response.dart';
import '../../widgets/glowing_orb.dart';
import 'keyboard_input_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_provider.dart';
import '../chat/chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Track touch position for the Aura effect and Orb rotation
  Offset _pointerPos = Offset.zero;
  double _manualRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final provider = context.watch<VoiceInputProvider>();

    if (_pointerPos == Offset.zero) {
      _pointerPos = Offset(size.width / 2, size.height / 2);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pointerPos = details.localPosition;
            // Adds rotation physics to the orb based on horizontal drag
            _manualRotation += details.delta.dx * 0.01;
          });
        },
        child: SeroAuraEffect(
          touchPosition: _pointerPos,
          color: provider.emotionColor,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildHeader(),
                    const Spacer(),

                    // ================= MAIN ORB =================
                    SizedBox(
                      width: 320,
                      height: 320,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) {
                          // Wraps the orb in a transform to allow the tilt/rotate physics
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // Perspective
                              ..rotateX(
                                (_pointerPos.dy - size.height / 2) * -0.0005,
                              )
                              ..rotateY(
                                (_pointerPos.dx - size.width / 2) * 0.0005,
                              )
                              ..rotateZ(_manualRotation),
                            child: CustomPaint(
                              painter: GlowingOrbPainter(
                                progress: _controller.value,
                                color: provider.emotionColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Spacer(),
                    _buildKeyboardHint(context),
                    _buildBottomNav(provider),
                  ],
                ),
              ),
              const AssistantResponseBubble(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          "I CAN SEARCH NEW CONTACTS",
          style: TextStyle(
            color: Color.fromARGB(255, 14, 213, 0),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        SizedBox(height: 12),
        Text(
          "What Can I Do for\nYou Today?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: Color.fromARGB(255, 14, 213, 0),
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact(); // Tactile feedback
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KeyboardInputScreen()),
          );
        },
        child: const Opacity(
          opacity: 0.3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Use Keyboard",
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(VoiceInputProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.person_outline, color: Colors.white38),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white38,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white38),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  final chatProvider = context.read<ChatProvider>();
                  chatProvider.createNewChat();
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
            ],
          ),
          SeroMicButton(controller: _controller),
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF1AFF6B)),
            onPressed: () {
              HapticFeedback.heavyImpact(); // Stronger feedback for settings
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ================= FX CLASSES DEFINED LOCALLY =================

class SeroAuraEffect extends StatelessWidget {
  final Widget child;
  final Offset touchPosition;
  final Color color;

  const SeroAuraEffect({
    super.key,
    required this.child,
    required this.touchPosition,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AuraPainter(touchPosition: touchPosition, baseColor: color),
      child: child,
    );
  }
}

class AuraPainter extends CustomPainter {
  final Offset touchPosition;
  final Color baseColor;

  AuraPainter({required this.touchPosition, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (touchPosition.dx / size.width) * 2 - 1,
          (touchPosition.dy / size.height) * 2 - 1,
        ),
        radius: 0.8,
        colors: [
          baseColor.withOpacity(0.12),
          baseColor.withOpacity(0.04),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(AuraPainter oldDelegate) =>
      oldDelegate.touchPosition != touchPosition ||
      oldDelegate.baseColor != baseColor;
}
