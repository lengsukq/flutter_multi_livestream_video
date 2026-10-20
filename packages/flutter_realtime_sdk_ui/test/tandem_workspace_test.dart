import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Host slots and classroom workspace layout introduced by the Tandem pass.
void main() {
  Future<MediaPreJoinResult> readyResult() async => const MediaPreJoinResult(
    role: MediaRole.participant,
    providerId: 'fake',
    checks: [
      MediaPreJoinCheck(
        type: MediaPreJoinCheckType.backend,
        status: MediaPreJoinStatus.passed,
        severity: MediaPreJoinSeverity.blocking,
        message: 'Ready',
      ),
    ],
  );

  testWidgets('pre-join renders host waiting room, agenda and materials', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var admitted = 0;
    RealtimePreJoinSessionInfo? entered;
    RealtimePreJoinJoinIntent? intent;
    await tester.pumpWidget(
      MaterialApp(
        theme: RealtimeUiTheme.light(),
        home: RealtimePreJoinPage(
          permissionRequester: const _Permissions(),
          roomLabel: 'room-1',
          displayName: 'Teacher',
          brand: const Text('Tandem'),
          sessionInfo: RealtimePreJoinSessionInfo(
            title: 'Quadratics: finding the roots',
            subject: 'Algebra II',
            scheduleLabel: 'Today',
            timeRangeLabel: '4:00 – 5:00 PM',
            startsAt: DateTime.now().add(const Duration(minutes: 4)),
            enrolledCount: 6,
          ),
          waitingGuests: const [
            RealtimePreJoinWaitingGuest(id: 'a', name: 'Ava K.'),
            RealtimePreJoinWaitingGuest(id: 'b', name: 'Jonah M.'),
          ],
          onAdmitGuest: (_) => admitted++,
          agenda: const [
            RealtimePreJoinAgendaItem(
              title: 'Warm-up: factor pairs',
              durationLabel: '5 min',
            ),
          ],
          materials: const [
            RealtimePreJoinMaterial(id: 'm', title: 'Slides.pdf'),
          ],
          runCheck: readyResult,
          openPreview: (_, _) async => null,
          onEnter: (_, _) async {},
          onEnterWithIntent: (_, _, value) async => intent = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tandem'), findsOneWidget);
    expect(find.text('Quadratics: finding the roots'), findsOneWidget);
    expect(find.text('Algebra II'), findsOneWidget);
    expect(find.text('Waiting room (2)'), findsOneWidget);
    expect(find.text('Lesson plan'), findsOneWidget);
    expect(find.text('Class materials'), findsOneWidget);
    expect(find.text('Audio only'), findsOneWidget);

    await tester.ensureVisible(find.text('Admit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admit').first);
    await tester.pump();
    expect(admitted, 1);
    // Only a subsequent host snapshot may confirm admission.
    expect(find.text('Admitted'), findsNothing);
    expect(find.text('Waiting room (2)'), findsOneWidget);

    await tester.ensureVisible(find.text('Audio only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio only'));
    await tester.pumpAndSettle();
    expect(intent, RealtimePreJoinJoinIntent.audioOnly);
    expect(entered, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pre-join restores preview shortcuts and shows mic meter inline without fake toggles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: RealtimeUiTheme.light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: RealtimeStrings.supportedLocales,
          localizationsDelegates: RealtimeStrings.localizationsDelegates,
          home: RealtimePreJoinPage(
            permissionRequester: const _Permissions(),
            roomLabel: 'room-3',
            displayName: 'Guest',
            runCheck: readyResult,
            openPreview: (_, _) async => _DevicesPreview(),
            onEnter: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RealtimePreJoinDevicePicker), findsNWidgets(3));
      expect(find.byType(RealtimePreJoinMediaControls), findsOneWidget);
      expect(find.byType(RealtimeMicrophoneLevelMeter), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RealtimePreJoinMediaControls),
          matching: find.byType(RealtimeMicrophoneLevelMeter),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(RealtimePreJoinDevicePicker),
          matching: find.byType(RealtimeMicrophoneLevelMeter),
        ),
        findsNothing,
      );
      for (final label in const ['环境降噪', '虚化背景', '自动录制', '实时字幕']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.byTooltip('更多设置'), findsOneWidget);
      expect(find.byTooltip('打开麦克风'), findsOneWidget);
      expect(find.byTooltip('打开摄像头'), findsOneWidget);
      expect(find.byTooltip('虚化背景'), findsOneWidget);
      expect(find.text('Play test sound'), findsNothing);
      await tester.tap(find.byTooltip('更多设置'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pre-join hides host sections when no slot data is supplied', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var joinCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: RealtimeUiTheme.light(),
        home: RealtimePreJoinPage(
          permissionRequester: const _Permissions(),
          roomLabel: 'room-2',
          displayName: 'Guest',
          runCheck: readyResult,
          openPreview: (_, _) async => null,
          onEnter: (_, _) async => joinCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting room (0)'), findsNothing);
    expect(find.text('Lesson plan'), findsNothing);
    expect(find.text('Class materials'), findsNothing);
    // No session info keeps the original generic CTA.
    expect(find.text('Join meeting'), findsOneWidget);
    await tester.tap(find.text('Join meeting'));
    await tester.pumpAndSettle();
    expect(joinCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lobby confirms admission from host state and submits a batch once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var guest = const RealtimePreJoinWaitingGuest(id: 'a', name: 'Ava');
      var singleRequests = 0;
      var batchRequests = 0;
      late StateSetter updateHost;
      await tester.pumpWidget(
        MaterialApp(
          theme: RealtimeUiTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return RealtimePreJoinPage(
                permissionRequester: const _Permissions(),
                roomLabel: 'lobby',
                displayName: 'Host',
                waitingGuests: [guest],
                onAdmitGuest: (_) => singleRequests++,
                onAdmitAll: () => batchRequests++,
                runCheck: readyResult,
                openPreview: (_, _) async => null,
                onEnter: (_, _) async {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Admit all'));
      await tester.tap(find.text('Admit all'));
      await tester.pump();
      expect(batchRequests, 1);
      expect(singleRequests, 0);
      expect(find.text('Admitted'), findsNothing);
      await tester.tap(find.text('Admit'));
      expect(singleRequests, 1);
      updateHost(() => guest = guest.copyWith(admitted: true));
      await tester.pump();
      expect(find.text('Admitted'), findsOneWidget);
      expect(find.text('Waiting room (0)'), findsOneWidget);
    },
  );

  testWidgets('audio-only intent forces microphone on and camera off', (
    tester,
  ) async {
    final settings = const MediaLocalPreviewSettings(
      microphoneEnabled: false,
      cameraEnabled: true,
    );
    final applied = RealtimePreJoinJoinIntent.audioOnly.applyTo(settings);
    expect(applied.microphoneEnabled, isTrue);
    expect(applied.cameraEnabled, isFalse);
    final standard = RealtimePreJoinJoinIntent.standard.applyTo(settings);
    expect(standard, same(settings));
    final share = RealtimePreJoinJoinIntent.screenShare.applyTo(settings);
    expect(share, same(settings));
  });

  testWidgets('meeting header uses host session info and invite action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: RealtimeUiTheme.light(),
        home: Scaffold(
          body: RealtimeMeetingTopBar(
            brand: const Text('Tandem'),
            title: 'Quadratics: finding the roots',
            subtitle: 'Algebra II · session 7 of 12',
            inviteAction: () {},
            audienceNames: const ['Ava', 'Jonah'],
            audienceCount: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tandem'), findsOneWidget);
    expect(find.text('Quadratics: finding the roots'), findsOneWidget);
    expect(find.text('Algebra II · session 7 of 12'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DevicesPreview extends Fake implements MediaLocalPreviewSession {
  @override
  MediaTrackRenderer get renderer => const _NullRenderer();
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaLocalPreviewSettings get settings => const MediaLocalPreviewSettings();
  @override
  MediaVideoTrack? get cameraTrack => null;
  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async => const [];
  @override
  Future<void> dispose() async {}
}

class _NullRenderer extends MediaTrackRenderer {
  const _NullRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _Permissions implements MediaPermissionRequester {
  const _Permissions();
  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
  @override
  bool get canOpenAppSettings => true;
  @override
  Future<bool> openAppSettings() async => true;
}
