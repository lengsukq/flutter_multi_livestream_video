import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';

void main() {
  testWidgets(
    'SharedContentStageBar renders in Whiteboard mode and dispatches page actions',
    (tester) async {
      var prev = 0;
      var next = 0;
      var add = 0;
      var del = 0;
      var stop = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedContentStageBar(
              title: '白板演示',
              badgeIcon: Icons.draw_outlined,
              pageIndex: 0,
              pageCount: 3,
              onPreviousPage: () => prev++,
              onNextPage: () => next++,
              onAddPage: () => add++,
              canAddPage: true,
              onDeletePage: () => del++,
              canDeletePage: true,
              onStop: () => stop++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('白板演示'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.draw_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      expect(prev, 1);

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      expect(next, 1);

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      expect(add, 1);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(del, 1);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(stop, 1);
    },
  );

  testWidgets(
    'SharedContentStageBar renders in ScreenShare mode with annotation and subtitle',
    (tester) async {
      var annotateToggled = false;
      var stopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SharedContentStageBar(
                  title: '屏幕共享',
                  badgeIcon: Icons.screen_share_outlined,
                  subtitle: '共享者：张三',
                  annotationEnabled: annotateToggled,
                  canAnnotate: true,
                  onToggleAnnotation: () =>
                      setState(() => annotateToggled = !annotateToggled),
                  onStop: () => stopped = true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('屏幕共享'), findsOneWidget);
      expect(find.text('共享者：张三'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(annotateToggled, true);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(stopped, true);
    },
  );
}
