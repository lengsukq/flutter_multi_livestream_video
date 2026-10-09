import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'phone toolbar avoids consumed status padding, dock and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 24);
      tester.view.padding = const FakeViewPadding(top: 54, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      const key = ValueKey('phone-tools');
      Widget page({double keyboard = 0}) => MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 54, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 54, bottom: 24),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: Scaffold(
              body: SafeArea(
                child: Center(
                  child: SizedBox(
                    width: 280,
                    height: 300,
                    child: MovableAnnotationToolbar(
                      child: Material(
                        child: SizedBox(
                          key: key,
                          width: 160,
                          height: 64,
                          child: const Row(
                            children: [
                              Icon(Icons.drag_indicator),
                              Text('Tools'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final initial = tester.getRect(find.byKey(key));
      expect(initial.top, greaterThanOrEqualTo(54));
      expect(initial.bottom, lessThanOrEqualTo(844 - 24 - 96));
      await tester.drag(
        find.byIcon(Icons.drag_indicator),
        const Offset(-1000, -1000),
      );
      await tester.pump();
      expect(tester.getRect(find.byKey(key)).top, greaterThanOrEqualTo(54));
      await tester.drag(
        find.byIcon(Icons.drag_indicator),
        const Offset(1000, 1000),
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(key)).bottom,
        lessThanOrEqualTo(844 - 24),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpWidget(page(keyboard: 300));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(key)).bottom,
        lessThanOrEqualTo(844 - 300),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'toolbar can leave a small whiteboard, stays on screen and passes other taps',
    (tester) async {
      var pressed = 0;
      var outsideTaps = 0;
      const canvasKey = ValueKey('small-whiteboard');
      const toolsKey = ValueKey('tools');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 350,
                  child: TextButton(
                    onPressed: () => outsideTaps++,
                    child: const Text('Outside board'),
                  ),
                ),
                Positioned(
                  left: 200,
                  top: 150,
                  width: 250,
                  height: 180,
                  child: SizedBox(
                    key: canvasKey,
                    child: MovableAnnotationToolbar(
                      child: Material(
                        child: SizedBox(
                          key: toolsKey,
                          width: 120,
                          height: 50,
                          child: Row(
                            children: [
                              const Icon(Icons.drag_indicator),
                              TextButton(
                                onPressed: () => pressed++,
                                child: const Text('Tool'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byIcon(Icons.drag_indicator),
        const Offset(-470, 350),
      );
      await tester.pump();
      final board = tester.getRect(find.byKey(canvasKey));
      final tools = tester.getRect(find.byKey(toolsKey));
      expect(board.overlaps(tools), isFalse);
      expect(tools.left, greaterThanOrEqualTo(0));
      expect(tools.bottom, lessThanOrEqualTo(600));
      await tester.tap(find.text('Tool'));
      expect(pressed, 1);
      await tester.tap(find.text('Outside board'));
      expect(outsideTaps, 1);
      await tester.drag(
        find.byIcon(Icons.drag_indicator),
        const Offset(-2000, 2000),
      );
      await tester.pump();
      final clamped = tester.getRect(find.byKey(toolsKey));
      expect(clamped.left, greaterThanOrEqualTo(0));
      expect(clamped.bottom, lessThanOrEqualTo(600));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byKey(toolsKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
