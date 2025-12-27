import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class GlowingOrbPainter extends CustomPainter {
  final double progress;
  final Color color;

  GlowingOrbPainter({required this.progress, required this.color});

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
        ..color = color.withOpacity(0.95);

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
        ..color = color.withOpacity(0.25);

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
