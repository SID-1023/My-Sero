import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/voice/voice_input.dart';
import 'widgets/mic_button.dart';
import 'widgets/assistant_response.dart';

void main() {
  runApp(const AssistantApp());
}

/* ================= ROOT APP ================= */

class AssistantApp extends StatelessWidget {
  const AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VoiceInputProvider>(
      create: (_) => VoiceInputProvider()..initSpeech(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'),
        home: const AssistantScreen(),
      ),
    );
  }
}

/* ================= MAIN SCREEN ================= */

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: Stack(
        children: [
          /* ================= BACKGROUND AMBIENT GLOW ================= */
          Positioned(
            top: -150,
            left: screenSize.width * 0.1,
            right: screenSize.width * 0.1,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4D0000).withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox(),
              ),
            ),
          ),

          /* ================= MAIN CONTENT ================= */
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),

                _buildHeader(),

                const Spacer(),

                /* ================= MAIN 3D PATTERN ================= */
                Center(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: 320,
                      height: 320,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: CircularLoopPainter(_controller.value),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                _buildInteractionArea(),

                _buildBottomNav(),
              ],
            ),
          ),

          // On-screen assistant response bubble (shows Sero text / thinking)
          const AssistantResponseBubble(),
        ],
      ),
    );
  }

  /* ================= HEADER ================= */

  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          "I CAN SEARCH NEW CONTACTS",
          style: TextStyle(
            color: Color(0xFFD50000),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
          ),
        ),
        SizedBox(height: 12),
        Text(
          "What Can I Do for\nYou Today?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFB3B3),
            height: 1.1,
            letterSpacing: -1.2,
          ),
        ),
      ],
    );
  }

  /* ================= INTERACTION HINT ================= */

  Widget _buildInteractionArea() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24.0),
      child: Opacity(
        opacity: 0.3,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              "Use Keyboard",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /* ================= BOTTOM NAV ================= */

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline, color: Colors.white38),
          ),

          /* ================= MIC BUTTON ================= */
          SeroMicButton(controller: _controller),

          IconButton(
            onPressed: () {
              final provider = Provider.of<VoiceInputProvider>(
                context,
                listen: false,
              );
              provider.setAutoListenAfterResponse(
                !provider.autoListenAfterResponse,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Auto-listen ${provider.autoListenAfterResponse ? 'enabled' : 'disabled'}',
                  ),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
            icon: Consumer<VoiceInputProvider>(
              builder: (_, vp, __) => Icon(
                Icons.tune,
                color: vp.autoListenAfterResponse
                    ? Colors.greenAccent
                    : Colors.white38,
              ),
            ),
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

/* ================= MINI 3D PAINTER ================= */

class Mini3DPainter extends CustomPainter {
  final double progress;

  Mini3DPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width / 3.5;

    for (int i = 0; i < 3; i++) {
      final double rotationSpeed = progress * 2 * pi;
      final double orbitOffset = i * (pi * 0.6);

      final Paint tubePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD50000);

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = const Color(0xFFFF1A1A).withOpacity(0.4);

      final Path path = Path();

      for (double t = 0; t <= 2 * pi; t += 0.3) {
        final double x = baseRadius * cos(t);
        final double y = baseRadius * sin(t);
        final double z = baseRadius * sin(t + orbitOffset);

        final double rx = x * cos(rotationSpeed) + z * sin(rotationSpeed);
        final double rz = -x * sin(rotationSpeed) + z * cos(rotationSpeed);
        final double ry =
            y * cos(rotationSpeed * 0.5) - rz * sin(rotationSpeed * 0.5);

        final double p = 1 / (1 - (rz / 250));
        final double px = center.dx + rx * p;
        final double py = center.dy + ry * p;

        if (t == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }

      path.close();
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, tubePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/* ================= MAIN BLOODY MOON PAINTER ================= */

class CircularLoopPainter extends CustomPainter {
  final double progress;

  CircularLoopPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width / 2.6;

    for (int i = 0; i < 4; i++) {
      final double rotationSpeed = progress * 2 * pi;
      final double orbitOffset = i * (pi / 2);

      final Paint tubePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF800000).withOpacity(0.95);

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
        ..color = const Color(0xFFFF5252).withOpacity(0.2);

      final Path path = Path();

      for (double t = 0; t <= 2 * pi; t += 0.05) {
        final double x = baseRadius * cos(t);
        final double y = baseRadius * sin(t);
        final double z = baseRadius * sin(t + orbitOffset);

        final double rx = x * cos(rotationSpeed) + z * sin(rotationSpeed);
        final double rz = -x * sin(rotationSpeed) + z * cos(rotationSpeed);

        final double ry =
            y * cos(rotationSpeed * 0.5 + orbitOffset) -
            rz * sin(rotationSpeed * 0.5 + orbitOffset);
        final double rz2 =
            y * sin(rotationSpeed * 0.5 + orbitOffset) +
            rz * cos(rotationSpeed * 0.5 + orbitOffset);

        final double perspective = 1 / (1 - (rz2 / 600));
        final double px = center.dx + rx * perspective;
        final double py = center.dy + ry * perspective;

        if (t == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }

      path.close();
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, tubePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircularLoopPainter oldDelegate) => true;
}
