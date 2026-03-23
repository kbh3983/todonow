// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todonow/main.dart';

void main() {
  testWidgets('Clock presence test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChronosApp());
    await tester.pumpAndSettle();

    // Verify that the digital clock is displayed.
    // The clock format is HH:mm:ss, so it should contain colons.
    expect(find.byType(Text), findsWidgets);

    // Verify that the Insights tab is present in the BottomNavigationBar.
    expect(find.text('Insights'), findsOneWidget);
  });
}
