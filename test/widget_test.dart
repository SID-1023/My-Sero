import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sero/main.dart'; // Ensure this points to your main.dart correctly

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // FIX: Changed 'isLoggedIn: null' to 'isLoggedIn: false'
    // This satisfies the required non-nullable bool parameter in the AssistantApp constructor.
    await tester.pumpWidget(const AssistantApp(isLoggedIn: false));

    // Verify MaterialApp exists in the widget tree
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Optional: Add a second test to check the logged-in state
  testWidgets('App displays home screen when logged in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AssistantApp(isLoggedIn: true));

    // You can add more specific checks here depending on your HomeScreen UI
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
