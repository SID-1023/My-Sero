import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sero/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Run the app
    await tester.pumpWidget(const AssistantApp());

    // Verify MaterialApp exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
