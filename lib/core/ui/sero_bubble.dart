import 'package:flutter/material.dart';
import '../../core/theme_tokens.dart';

class SeroBubble extends StatelessWidget {
  final Widget child;
  final bool outgoing;

  const SeroBubble({Key? key, required this.child, this.outgoing = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = outgoing ? SeroTokens.primary : Colors.white.withOpacity(0.06);
    final textColor = outgoing ? Colors.black : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SeroTokens.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: textColor, fontSize: SeroTokens.bodySize),
        child: child,
      ),
    );
  }
}
