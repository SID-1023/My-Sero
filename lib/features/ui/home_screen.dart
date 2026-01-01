import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

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
  Offset _pointerPos = Offset.zero;
  double _manualRotation = 0.0;

  // Dynamic Accent Color from Back4app
  Color _neuralAccentColor = const Color(0xFF00FF11);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadNeuralColor(); // Fetch the saved color on startup
  }

  // Fetch the accent color saved in Back4app Settings
  Future<void> _loadNeuralColor() async {
    ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null) {
      String? savedColor = currentUser.get<String>('accentColor');
      if (savedColor != null) {
        setState(() {
          _neuralAccentColor = Color(int.parse(savedColor));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final provider = context.watch<VoiceInputProvider>();

    // If the provider has a specific "emotion" color, use that.
    // Otherwise, use our saved neuralAccentColor.
    final Color activeColor = provider.isListening
        ? provider.emotionColor
        : _neuralAccentColor;

    if (_pointerPos == Offset.zero) {
      _pointerPos = Offset(size.width / 2, size.height / 2);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pointerPos = details.localPosition;
            _manualRotation += details.delta.dx * 0.01;
          });
        },
        child: SeroAuraEffect(
          touchPosition: _pointerPos,
          color: activeColor, // SYNCED AURA
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildHeader(activeColor), // SYNCED HEADER TEXT
                    const Spacer(),

                    // ================= MAIN ORB =================
                    SizedBox(
                      width: 320,
                      height: 320,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
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
                                color: activeColor, // SYNCED ORB COLOR
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Spacer(),
                    _buildKeyboardHint(
                      context,
                      activeColor,
                    ), // SYNCED KEYBOARD HINT
                    _buildBottomNav(provider, activeColor), // SYNCED NAV & MIC
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

  Widget _buildHeader(Color themeColor) {
    return Column(
      children: [
        Text(
          "I CAN SEARCH NEW CONTACTS",
          style: TextStyle(
            color: themeColor.withOpacity(0.7), // SYNCED
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "What Can I Do for\nYou Today?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: themeColor, // SYNCED
            height: 1.1,
            shadows: [
              Shadow(color: themeColor.withOpacity(0.5), blurRadius: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardHint(BuildContext context, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KeyboardInputScreen()),
          );
        },
        child: Opacity(
          opacity: 0.4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 16, color: themeColor), // SYNCED
              const SizedBox(width: 8),
              Text(
                "Use Keyboard",
                style: TextStyle(fontSize: 13, color: themeColor), // SYNCED
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(VoiceInputProvider provider, Color themeColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: themeColor.withOpacity(0.1)), // SYNCED BORDER
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            Icons.person_outline,
            color: themeColor.withOpacity(0.3),
          ), // SYNCED
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: themeColor.withOpacity(0.4),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.add, color: themeColor.withOpacity(0.4)),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.read<ChatProvider>().createNewChat();
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
            ],
          ),

          // The Mic Button usually handles its own internal color,
          // but you can pass themeColor if SeroMicButton supports it.
          SeroMicButton(controller: _controller),

          IconButton(
            icon: Icon(Icons.tune, color: themeColor), // SYNCED TUNE ICON
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadNeuralColor(); // Refresh color when returning from Settings
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

// ... AuraPainter and SeroAuraEffect remain the same ...
// ================= FX CLASSES DEFINED LOCALLY =================
// Add this at the very bottom of home_screen.dart

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
