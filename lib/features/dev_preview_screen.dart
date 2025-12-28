import 'package:flutter/material.dart';
import '../core/ui/sero_avatar.dart';
import '../core/ui/sero_badge.dart';
import '../core/ui/sero_timestamp.dart';
import '../core/ui/sero_bubble.dart';
import '../core/ui/ui_preview.dart';

class DevPreviewScreen extends StatelessWidget {
  const DevPreviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kUseNewUIPreview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dev Preview')),
        body: const Center(
          child: Text(
            'New UI preview is disabled. Enable kUseNewUIPreview to view.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sero UI Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const SeroAvatar(size: 56, initials: 'S'),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text(
                    'Sero',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SeroTimestamp(timestamp: DateTime.now()),
              ],
            ),
            const SizedBox(height: 20),
            const SeroBadge(text: 'NEW'),
            const SizedBox(height: 20),
            const SeroBubble(
              outgoing: false,
              child: Text('This is an incoming message example.'),
            ),
            const SeroBubble(
              outgoing: true,
              child: Text('This is an outgoing reply to the incoming message.'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              child: const Text('This is a CTA (preview only)'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
