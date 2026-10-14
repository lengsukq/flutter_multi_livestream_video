import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'compact room status stays with the title while exit stays trailing',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final width in [320.0, 390.0, 520.0, 600.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 700);
          await tester.pumpWidget(
            MaterialApp(
              theme: RealtimeUiTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: RealtimeMeetingTopBar(
                    compact: true,
                    title: '488156',
                    statusWidgets: const [
                      Text('00:04', key: ValueKey('status')),
                    ],
                    trailingActions: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton.filled(
                        onPressed: () {},
                        icon: const Icon(Icons.call_end, key: ValueKey('exit')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('status'))).dx,
            lessThan(width / 2),
          );
          expect(
            tester.getCenter(find.byKey(const ValueKey('exit'))).dx,
            greaterThan(width / 2),
          );
          expect(tester.takeException(), isNull, reason: '$width at $scale');
        }
      }
    },
  );
}
