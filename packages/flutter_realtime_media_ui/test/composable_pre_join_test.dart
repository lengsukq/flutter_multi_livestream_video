import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restarted checks ignore the older result', () async {
    final earlier = Completer<MediaPreJoinResult>();
    var calls = 0;
    var previewCalls = 0;
    final controller = RealtimePreJoinController(
      runCheck: () => ++calls == 1 ? earlier.future : Future.value(_check()),
      openPreview: (_, _) async {
        previewCalls++;
        return null;
      },
      permissionRequester: const _PermissionRequester(),
    );
    final one = controller.initialize();
    // Allow the first request to enter the check runner before restarting.
    await Future<void>.delayed(Duration.zero);
    final two = controller.initialize();
    earlier.complete(_check(providerId: 'stale'));
    await Future.wait([one, two]);
    expect(controller.result?.providerId, 'fake');
    expect(previewCalls, 0, reason: 'viewers do not open local capture');
    expect(controller.canEnter, isTrue);
    controller.dispose();
  });

  test(
    'failed entry returns to Pre-Join with retry settings and preview',
    () async {
      final previews = <_Preview>[];
      final controller = RealtimePreJoinController(
        runCheck: () async => _check(role: MediaRole.participant),
        openPreview: (_, _) async {
          final session = _Preview();
          previews.add(session);
          return session;
        },
        permissionRequester: const _PermissionRequester(),
      );
      await controller.initialize();
      expect(previews, hasLength(1));
      await controller.setCameraEnabled(true);
      expect(controller.preview?.settings.cameraEnabled, isTrue);
      var calls = 0;
      await controller.enter((settings) async {
        calls++;
        expect(settings.cameraEnabled, isTrue);
        expect(previews.first.disposeCount, 1);
        throw StateError('join failed');
      });
      expect(controller.joinError, isA<StateError>());
      expect(controller.joining, isFalse);
      expect(previews, hasLength(2), reason: 'failure reopens the preview');
      await controller.enter((settings) async {
        calls++;
        expect(settings.cameraEnabled, isTrue);
      });
      expect(calls, 2);
      expect(previews.last.disposeCount, 1);
      controller.dispose();
    },
  );

  testWidgets('preview, permissions and checks are independently placeable', (
    tester,
  ) async {
    final controller = RealtimePreJoinController(
      runCheck: () async => _check(),
      openPreview: (_, _) async => null,
      permissionRequester: const _PermissionRequester(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    for (final width in [390.0, 768.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 780));
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimePreJoinScope(
            controller: controller,
            child: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 120, child: RealtimePreJoinPreview()),
                  const Expanded(
                    child: SingleChildScrollView(
                      child: RealtimePreJoinCheckList(),
                    ),
                  ),
                  RealtimePreJoinJoinButton(onEnter: (_) async {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RealtimePreJoinJoinButton), findsOneWidget);
      expect(find.byType(RealtimePreJoinPreview), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('default Pre-Join template composes public pieces responsively', (
    tester,
  ) async {
    final controller = RealtimePreJoinController(
      runCheck: () async => _check(),
      openPreview: (_, _) async => null,
      permissionRequester: const _PermissionRequester(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    for (final width in [390.0, 768.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 780));
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeComposablePreJoinTemplate(
            controller: controller,
            onEnter: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RealtimePreJoinPreview), findsOneWidget);
      expect(find.byType(RealtimePreJoinCheckList), findsOneWidget);
      expect(find.byType(RealtimePreJoinJoinButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'media controls show checkmark beside switches when permissions are granted',
    (tester) async {
      final controller = RealtimePreJoinController(
        runCheck: () async => _check(role: MediaRole.participant),
        openPreview: (_, _) async => _Preview(),
        permissionRequester: const _PermissionRequester(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: RealtimePreJoinScope(
            controller: controller,
            child: const Scaffold(body: RealtimePreJoinMediaControls()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    },
  );

  testWidgets(
    'media controls show cross beside switches and trigger request when permission denied',
    (tester) async {
      var requestedMic = false;
      final controller = RealtimePreJoinController(
        runCheck: () async => _check(role: MediaRole.participant),
        openPreview: (_, _) async => _Preview(),
        permissionRequester: _DenyingPermissionRequester(
          onRequestMic: () => requestedMic = true,
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: RealtimePreJoinScope(
            controller: controller,
            child: const Scaffold(body: RealtimePreJoinMediaControls()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      expect(requestedMic, isTrue);
    },
  );

  testWidgets('pending macOS-style permission is requested on switch tap and track enabled',
    (tester) async {
      final requester = _GrantOnRequest();
      final controller = RealtimePreJoinController(
        runCheck: () async => _check(role: MediaRole.participant),
        openPreview: (_, _) async => _Preview(),
        permissionRequester: requester,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await tester.pumpWidget(MaterialApp(
        home: RealtimePreJoinScope(
          controller: controller,
          child: const Scaffold(body: RealtimePreJoinMediaControls()),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.help_outline_rounded), findsNWidgets(2));
      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();
      expect(controller.permissions[MediaPermissionKind.microphone],
          MediaPermissionState.granted);
      expect(controller.preview!.settings.microphoneEnabled, isTrue);
      await tester.tap(find.byType(CupertinoSwitch).last);
      await tester.pumpAndSettle();
      expect(controller.permissions[MediaPermissionKind.camera],
          MediaPermissionState.granted);
      expect(controller.preview!.settings.cameraEnabled, isTrue);
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
    },
  );
}

class _GrantOnRequest implements MediaPermissionRequester {
  final _granted = <MediaPermissionKind>{};

  @override
  bool get canOpenAppSettings => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      _granted.contains(kind) ? MediaPermissionState.granted
          : MediaPermissionState.unknown;
  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async {
    _granted.add(kind);
    return MediaPermissionState.granted;
  }
}

class _DenyingPermissionRequester implements MediaPermissionRequester {
  const _DenyingPermissionRequester({this.onRequestMic});
  final VoidCallback? onRequestMic;

  @override
  bool get canOpenAppSettings => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      MediaPermissionState.denied;
  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async {
    if (kind == MediaPermissionKind.microphone) {
      onRequestMic?.call();
    }
    return MediaPermissionState.denied;
  }
}

MediaPreJoinResult _check({
  MediaRole role = MediaRole.viewer,
  String providerId = 'fake',
}) => MediaPreJoinResult(
  role: role,
  providerId: providerId,
  checks: const [
    MediaPreJoinCheck(
      type: MediaPreJoinCheckType.backend,
      status: MediaPreJoinStatus.passed,
      severity: MediaPreJoinSeverity.blocking,
      message: 'Backend ready',
    ),
  ],
);

class _PermissionRequester implements MediaPermissionRequester {
  const _PermissionRequester();

  @override
  bool get canOpenAppSettings => false;
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _Preview extends Fake implements MediaLocalPreviewSession {
  MediaLocalPreviewSettings _settings = const MediaLocalPreviewSettings();
  int disposeCount = 0;

  @override
  MediaLocalPreviewSettings get settings => _settings;
  @override
  MediaVideoTrack? get cameraTrack => null;
  @override
  MediaTrackRenderer get renderer => const _Renderer();
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  Future<void> setMicrophoneEnabled(bool enabled) async =>
      _settings = _settings.copyWith(microphoneEnabled: enabled);
  @override
  Future<void> setCameraEnabled(bool enabled) async =>
      _settings = _settings.copyWith(cameraEnabled: enabled);
  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async => const [];
  @override
  Future<void> selectMediaDevice(MediaDevice device) async {}
  @override
  Future<void> dispose() async => disposeCount++;
}
