import 'package:flutter/material.dart';
import '../../core/theme_tokens.dart';

class SeroBadge extends StatelessWidget {
  final String text;
  final Color color;

  const SeroBadge({
    Key? key,
    required this.text,
    this.color = SeroTokens.primary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SeroTokens.radiusSmall),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
