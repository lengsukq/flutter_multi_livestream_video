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

  testWidgets('RealtimeDockMoreButton opens sheet and executes action', (
    tester,
  ) async {
    var flipped = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: Scaffold(
          body: RealtimeDockMoreButton(
            showLabel: true,
            hasActiveBadge: true,
            items: [
              RealtimeDockMoreItem(
                icon: Icons.cameraswitch_rounded,
                title: '翻转摄像头',
                subtitle: '切换前后置',
                onTap: () => flipped = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('更多'), findsOneWidget);
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();

    expect(find.text('翻转摄像头'), findsOneWidget);
    expect(find.text('切换前后置'), findsOneWidget);

    await tester.tap(find.text('翻转摄像头'));
    await tester.pumpAndSettle();

    expect(flipped, true);
    expect(find.text('切换前后置'), findsNothing);
  });

  testWidgets('RealtimeDockReactionsButton opens sheet and triggers wave', (
    tester,
  ) async {
    var waveTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: Scaffold(
          body: RealtimeDockReactionsButton(
            showLabel: true,
            onWave: () => waveTriggered = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('互动'), findsOneWidget);
    await tester.tap(find.text('互动'));
    await tester.pumpAndSettle();

    expect(find.text('挥手'), findsOneWidget);
    await tester.tap(find.text('挥手'));
    await tester.pumpAndSettle();

    expect(waveTriggered, true);
    expect(find.text('挥手'), findsNothing);
  });
}
