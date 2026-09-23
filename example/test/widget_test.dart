// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_aws_chime_example/main.dart';

void main() {
  testWidgets('Verify JoinScreen loads with tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that Chime Live title and tabs are rendered.
    expect(find.text('Chime Live'), findsOneWidget);
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.text('创建房间'), findsOneWidget);
  });
}
