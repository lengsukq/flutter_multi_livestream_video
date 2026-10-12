import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
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
  testWidgets(
    'RealtimeShareOptionCard renders unselected state and dispatches onTap',
    (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealtimeShareOptionCard(
              title: '白板演示',
              subtitle: '打开多人协同互动白板与课件',
              icon: Icons.draw_rounded,
              iconColor: Colors.blue,
              iconBackgroundColor: Colors.blue.withValues(alpha: 0.12),
              isSelected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('白板演示'), findsOneWidget);
      expect(find.text('打开多人协同互动白板与课件'), findsOneWidget);
      expect(find.byIcon(Icons.draw_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.tap(find.text('白板演示'));
      await tester.pumpAndSettle();

      expect(tapped, true);
    },
  );

  testWidgets(
    'RealtimeShareOptionCard renders selected state with active badge and checkmark',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealtimeShareOptionCard(
              title: '白板演示',
              subtitle: '打开多人协同互动白板与课件',
              icon: Icons.draw_rounded,
              iconColor: Colors.blue,
              iconBackgroundColor: Colors.blue.withValues(alpha: 0.12),
              isSelected: true,
              activeBadgeText: '共享中',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('白板演示'), findsOneWidget);
      expect(find.text('共享中'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    },
  );

  testWidgets(
    'RealtimeShareOptionCard respects disabled state without firing onTap',
    (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealtimeShareOptionCard(
              title: '屏幕共享',
              subtitle: '共享电脑或手机屏幕给所有参会者',
              icon: Icons.screen_share_outlined,
              iconColor: Colors.green,
              iconBackgroundColor: Colors.green.withValues(alpha: 0.12),
              enabled: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('屏幕共享'));
      await tester.pumpAndSettle();

      expect(tapped, false);
    },
  );

  testWidgets(
    'RealtimeDockSharedContentButton renders default standalone screen share item',
    (tester) async {
      final media = _FakeMediaSession();
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'room-1',
          participantId: 'self',
          session: media,
        ),
        renderer: const _FakeRenderer(),
        disposeClients: () {},
      );
      addTearDown(room.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: RealtimeStrings.supportedLocales,
          localizationsDelegates: RealtimeStrings.localizationsDelegates,
          home: RealtimeRoomUiScope(
            room: room,
            child: const Scaffold(
              body: RealtimeDockSharedContentButton(showLabel: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('屏幕共享'), findsOneWidget);
      expect(find.byIcon(Icons.screen_share_rounded), findsOneWidget);
    },
  );
}

class _FakeRenderer extends MediaTrackRenderer {
  const _FakeRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _FakeMediaSession extends Fake implements MediaSession {
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.host;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaSessionState get state => MediaSessionState.connected;
  @override
  MediaSnapshot get snapshot => MediaSnapshot(
    state: MediaSessionState.connected,
    capabilities: capabilities,
  );
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Stream<MediaMessage> get dataMessages => const Stream.empty();
  @override
  Future<void> sendData(
    Object message, {
    MediaSendOptions options = const MediaSendOptions(),
  }) async {}
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {}
  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> setScreenShareEnabled(bool enabled) async {}
}
