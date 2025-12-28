import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sero/features/dev_preview_screen.dart';

void main() {
  testWidgets('Dev Preview shows disabled message when preview is off', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevPreviewScreen()));
    expect(find.textContaining('disabled'), findsOneWidget);
  });
}
