import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'trailing actions are quiet, touch-friendly and invoke the callback',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: RealtimeUiTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 330,
                child: RealtimeGlassTextField(
                  controller: controller,
                  label: 'Room code',
                  prefixIcon: Icons.tag_rounded,
                  suffix: RealtimeFieldAction(
                    label: 'Paste',
                    icon: Icons.content_paste_outlined,
                    onPressed: () => calls++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final action = find.byType(RealtimeFieldAction);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: action, matching: find.byType(RealtimePill)),
        findsNothing,
      );
      expect(
        tester
            .widget<Material>(
              find
                  .descendant(of: action, matching: find.byType(Material))
                  .first,
            )
            .color,
        Colors.transparent,
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: action,
          matching: find.byIcon(Icons.content_paste_outlined),
        ),
      );
      expect(icon.color, RealtimeUiTokens.textMuted);
      await tester.tap(find.text('Paste'));
      await tester.pump();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('input actions remain usable on 320px screens with 200% text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: RealtimeUiTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RealtimeGlassTextField(
                controller: controller,
                label: '房间码',
                prefixIcon: Icons.tag_rounded,
                suffix: RealtimeFieldAction(
                  label: '生成随机码',
                  icon: Icons.casino_outlined,
                  onPressed: () => controller.text = '123456',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(RealtimeFieldAction));
    await tester.pump();
    expect(controller.text, '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled field action does not execute and remains readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RealtimeUiTheme.light(),
        home: const Scaffold(
          body: RealtimeFieldAction(
            label: 'Paste',
            icon: Icons.content_paste_outlined,
            onPressed: null,
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(RealtimeFieldAction)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Paste'));
    expect(tester.takeException(), isNull);
  });
}
