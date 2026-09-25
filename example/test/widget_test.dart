// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_realtime_media_example/main.dart';

void main() {
  testWidgets('Verify JoinScreen loads with tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChimeExampleApp());

    // Verify that the provider-neutral title and tabs are rendered.
    expect(find.text('Realtime Media'), findsOneWidget);
    expect(find.text('Join room'), findsNWidgets(2));
    expect(find.text('Create room'), findsOneWidget);
  });
}
