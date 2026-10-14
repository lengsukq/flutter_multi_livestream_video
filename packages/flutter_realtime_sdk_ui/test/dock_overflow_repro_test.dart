import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

Widget _item(IconData icon, String label) => RealtimeDockItem(
  icon: icon,
  label: label,
  showLabel: false,
  onPressed: () {},
);

void main() {
  testWidgets('meeting dock does not overflow at 320pt width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: RealtimeMeetingDock(
                    showLabels: false,
                    leadingStatus: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: const Text('00:06'),
                    ),
                    mediaGroup: [
                      _item(Icons.mic_off_rounded, 'Mic'),
                      _item(Icons.videocam_off_rounded, 'Cam'),
                      _item(Icons.front_hand_outlined, 'Raise'),
                      _item(Icons.group_outlined, 'Queue'),
                    ],
                    collaborationGroup: [
                      _item(Icons.screen_share_outlined, 'Share'),
                      _item(Icons.emoji_emotions_outlined, 'React'),
                    ],
                    panelsGroup: [
                      _item(Icons.chat_bubble_outline_rounded, 'Chat'),
                      _item(Icons.people_outline_rounded, 'People'),
                      _item(Icons.school_outlined, 'Class'),
                    ],
                    moreAction: _item(Icons.more_horiz_rounded, 'More'),
                    exitAction: _item(Icons.call_end_rounded, 'Leave'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
