import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_example/standalone_chat_demo.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('embedded chat cards align with their parent Video / Chat tabs', (
    tester,
  ) async {
    // Rendering a hidden embedded Demo requires no actual vendor connection.
    final realtime = Realtime.fromSdk(RealtimeSdk(plugins: const []));

    for (final width in [360.0, 768.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width > 728 ? 680 : width - 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RealtimeSegmentedTabs<int>(
                      selectedValue: 1,
                      onChanged: (_) {},
                      tabs: const [
                        RealtimeSegmentTab(value: 0, label: '视频'),
                        RealtimeSegmentTab(value: 1, label: '聊天'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StandaloneChatDemoPage(
                        backendUrl: '',
                        realtime: realtime,
                        userId: 'student-123',
                        displayName: 'Student',
                        embedded: true,
                        visible: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final tabRect = tester.getRect(
        find.byType(RealtimeSegmentedTabs<int>).first,
      );
      final surfaces = find.descendant(
        of: find.byType(StandaloneChatDemoPage),
        matching: find.byType(RealtimeGlassSurface),
      );
      expect(surfaces, findsAtLeastNWidgets(2));
      for (final i in [0, 1]) {
        final rect = tester.getRect(surfaces.at(i));
        expect(rect.left, closeTo(tabRect.left, 1));
        expect(rect.right, closeTo(tabRect.right, 1));
      }
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
