import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme_tokens.dart';

class SeroTimestamp extends StatelessWidget {
  final DateTime timestamp;

  const SeroTimestamp({Key? key, required this.timestamp}) : super(key: key);

  String _format(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 7) return DateFormat('MMM d').format(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Text(_format(timestamp), style: SeroTokens.caption);
  }
}
