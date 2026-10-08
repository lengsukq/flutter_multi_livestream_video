import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_screen_annotation/flutter_realtime_screen_annotation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SystemAnnotationToolbarApp renders toolbar and dispatches method calls',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_realtime_screen_annotation_toolbar'),
            (call) async {
              calls.add(call);
              return null;
            },
          );

      await tester.pumpWidget(const SystemAnnotationToolbarApp());
      await tester.pumpAndSettle();

      // Tool icons should be present
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.highlight), findsOneWidget);

      // Select highlight tool
      await tester.tap(find.byIcon(Icons.highlight));
      await tester.pumpAndSettle();
      expect(
        calls.any(
          (c) =>
              c.method == 'selectTool' &&
              (c.arguments as Map)['tool'] == 'highlight',
        ),
        isTrue,
      );

      // Collapse into floating bubble
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // In collapsed state, toolbar is hidden, edit bubble is shown
      expect(find.byIcon(Icons.chevron_left), findsNothing);

      // Tap bubble to expand back
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    },
  );
}
