import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'RealtimeMeetingDock renders groups and dispatches item actions',
    (tester) async {
      var micTapped = false;
      var shareTapped = false;
      var chatTapped = false;
      var leaveTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealtimeMeetingDock(
              showLabels: true,
              mediaGroup: [
                RealtimeDockItem(
                  icon: Icons.mic_rounded,
                  label: '麦克风',
                  isActive: true,
                  onPressed: () => micTapped = true,
                ),
              ],
              collaborationGroup: [
                RealtimeDockItem(
                  icon: Icons.present_to_all_rounded,
                  label: '共享',
                  onPressed: () => shareTapped = true,
                ),
              ],
              panelsGroup: [
                RealtimeDockItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '聊天',
                  badgeCount: 3,
                  onPressed: () => chatTapped = true,
                ),
              ],
              exitAction: RealtimeDockItem(
                icon: Icons.call_end_rounded,
                label: '离开',
                isDanger: true,
                onPressed: () => leaveTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('麦克风'), findsOneWidget);
      expect(find.text('共享'), findsOneWidget);
      expect(find.text('聊天'), findsOneWidget);
      expect(find.text('离开'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Badge count

      await tester.tap(find.text('麦克风'));
      expect(micTapped, true);

      await tester.tap(find.text('共享'));
      expect(shareTapped, true);

      await tester.tap(find.text('聊天'));
      expect(chatTapped, true);

      await tester.tap(find.text('离开'));
      expect(leaveTapped, true);
    },
  );
}
