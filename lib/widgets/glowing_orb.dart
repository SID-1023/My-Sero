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
    final baseRadius = size.width / 2.8;

    // 1. Draw the Central Energy Core (Static Glow)
    final Paint coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(center, baseRadius * 0.8, coreGlow);

    // 2. Draw 3D Orbiting Rings
    // We use a list to store paths and their "Z" depth for sorting
    for (int i = 0; i < 4; i++) {
      final double rotationSpeed = progress * 2 * pi;
      final double orbitOffset = i * (pi / 2);

      // Gradient for the "Tube" to make it look 3D (lit from one side)
      final Paint tubePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            color.withOpacity(0.1),
            color,
            Colors.white,
            color,
            color.withOpacity(0.1),
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          transform: GradientRotation(rotationSpeed + orbitOffset),
        ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = color.withOpacity(0.2);

      final Path path = Path();

      // Calculate 3D points
      for (double t = 0; t <= 2 * pi; t += 0.1) {
        // Parametric circle equation
        final double x = baseRadius * cos(t);
        final double y = baseRadius * sin(t);
        final double z = baseRadius * sin(t + orbitOffset);

        // Rotation Matrix logic for Y and Z axis
        // This gives the "Wobble" and 3D spinning effect
        final double rx = x * cos(rotationSpeed) + z * sin(rotationSpeed);
        final double rz = -x * sin(rotationSpeed) + z * cos(rotationSpeed);

        final double ry =
            y * cos(rotationSpeed * 0.5 + orbitOffset) -
            rz * sin(rotationSpeed * 0.5 + orbitOffset);

        final double rz2 =
            y * sin(rotationSpeed * 0.5 + orbitOffset) +
            rz * cos(rotationSpeed * 0.5 + orbitOffset);

        // Perspective projection: Objects further away (smaller Z) look smaller
        final double perspective = 1 / (1 - (rz2 / (baseRadius * 4)));
        final double px = center.dx + rx * perspective;
        final double py = center.dy + ry * perspective;

        if (t == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }

      path.close();

      // Draw outer glow then the sharp "plasma" tube
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, tubePaint);
    }

    // 3. Inner "Pulse" Ring
    final Paint pulsePaint = Paint()
      ..color = color.withOpacity(0.4 * (1.0 - (progress % 1.0)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(
      center,
      baseRadius * 0.5 * (1.0 + (progress % 1.0)),
      pulsePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
