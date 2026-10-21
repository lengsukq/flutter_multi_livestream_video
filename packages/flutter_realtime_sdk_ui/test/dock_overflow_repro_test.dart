import 'package:flutter/gestures.dart';
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
  testWidgets('live reverse action strip reveals hidden actions to the left', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 146,
              height: 48,
              child: RealtimeDockScrollableStrip(
                reverse: true,
                dark: true,
                children: [
                  RealtimeDockItem(
                    icon: Icons.card_giftcard,
                    label: 'Gift',
                    showLabel: false,
                    onPressed: () => tapped = true,
                  ),
                  _item(Icons.favorite_border, 'Like'),
                  _item(Icons.radio_button_checked, 'Recording'),
                  _item(Icons.videocam, 'Video'),
                  _item(Icons.tune, 'Host tools'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(scroll.offset, 0);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(find.byTooltip('Scroll dock left'), findsOneWidget);
    expect(find.byTooltip('Scroll dock right'), findsNothing);
    for (
      var i = 0;
      i < 10 && find.byTooltip('Scroll dock left').evaluate().isNotEmpty;
      i++
    ) {
      await tester.tap(find.byTooltip('Scroll dock left'));
      await tester.pumpAndSettle();
    }
    expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1));
    expect(find.byTooltip('Scroll dock left'), findsNothing);
    await tester.tap(find.byTooltip('Gift'));
    expect(tapped, true);
    await tester.tap(find.byTooltip('Scroll dock right'));
    await tester.pumpAndSettle();
    expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 560.0, 620.0]) {
    testWidgets(
      'every dock action stays accessible at ${width.round()}px using wheel and arrows',
      (tester) async {
        tester.view.physicalSize = Size(width, 680);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var moreTapped = 0;
        var micTapped = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RealtimeMeetingDock(
                  showLabels: false,
                  mediaGroup: [
                    RealtimeDockItem(
                      icon: Icons.mic_off,
                      label: 'Mic',
                      showLabel: false,
                      onPressed: () => micTapped++,
                    ),
                    _item(Icons.videocam_off, 'Camera'),
                    _item(Icons.screen_share, 'Share'),
                    _item(Icons.fiber_manual_record, 'Record'),
                  ],
                  panelsGroup: [
                    _item(Icons.chat_outlined, 'Chat'),
                    _item(Icons.people_outline, 'People'),
                    _item(Icons.school_outlined, 'Classroom'),
                  ],
                  collaborationGroup: [
                    _item(Icons.grid_view, 'Layout'),
                    _item(Icons.emoji_emotions_outlined, 'Reaction'),
                    _item(Icons.poll_outlined, 'Poll'),
                    _item(Icons.timer_outlined, 'Timer'),
                    _item(Icons.front_hand_outlined, 'Raise'),
                    _item(Icons.rule_outlined, 'Q&A'),
                    _item(Icons.edit_note_outlined, 'Notes'),
                  ],
                  moreAction: RealtimeDockItem(
                    icon: Icons.more_horiz,
                    label: 'More',
                    showLabel: false,
                    onPressed: () => moreTapped++,
                  ),
                  exitAction: _item(Icons.call_end, 'Leave'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final stripKey = width < 600
            ? const ValueKey('meeting-dock-secondary-scroll')
            : const ValueKey('meeting-dock-main-scroll');
        final strip = find.byKey(stripKey);
        final scrollView = find.descendant(
          of: strip,
          matching: find.byType(SingleChildScrollView),
        );
        final controller = tester
            .widget<SingleChildScrollView>(scrollView)
            .controller!;
        expect(controller.position.maxScrollExtent, greaterThan(0));
        expect(find.byTooltip('Scroll dock right'), findsOneWidget);

        final scrollPoint = tester.getCenter(strip);
        tester.binding.handlePointerEvent(
          PointerScrollEvent(
            position: scrollPoint,
            scrollDelta: const Offset(0, 130),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          controller.offset,
          greaterThan(0),
          reason: 'A desktop vertical wheel must scroll the dock sideways',
        );

        final beforeMouseDrag = controller.offset;
        final mouse = await tester.startGesture(
          scrollPoint,
          kind: PointerDeviceKind.mouse,
        );
        // First movement wins the gesture arena; the next one scrolls.
        await mouse.moveBy(const Offset(-35, 0));
        await tester.pump();
        await mouse.moveBy(const Offset(-70, 0));
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          controller.offset,
          greaterThan(beforeMouseDrag),
          reason: 'Mouse dragging must move a horizontal toolbar',
        );

        for (
          var i = 0;
          i < 20 && find.byTooltip('Scroll dock right').evaluate().isNotEmpty;
          i++
        ) {
          await tester.tap(find.byTooltip('Scroll dock right'));
          await tester.pumpAndSettle();
        }
        expect(find.byTooltip('Scroll dock right'), findsNothing);
        expect(
          controller.offset,
          closeTo(controller.position.maxScrollExtent, 1),
        );
        await tester.tap(find.byTooltip('More'));
        expect(moreTapped, 1);

        if (width < 600) {
          // The essential actions remain fixed rather than disappearing off-screen.
          await tester.tap(find.byTooltip('Mic'));
          expect(micTapped, 1);
        }

        await tester.tap(find.byTooltip('Scroll dock left'));
        await tester.pumpAndSettle();
        expect(
          controller.offset,
          lessThan(controller.position.maxScrollExtent),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
