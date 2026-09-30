import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider display names keep known brands readable', () {
    expect(mediaProviderDisplayName('livekit'), 'LiveKit');
    expect(mediaProviderDisplayName('trtc'), 'Tencent TRTC');
    expect(mediaProviderDisplayName('aws'), 'AWS');
    expect(mediaProviderDisplayName('chime'), 'AWS · Chime');
    expect(mediaProviderDisplayName('ivs'), 'AWS · IVS');
    expect(mediaProviderDisplayName('custom'), 'CUSTOM');
  });

  testWidgets('ready result exposes continue action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreJoinDialog(
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.participant,
            providerId: 'fake',
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.passed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Backend reachable.',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ready to continue'), findsOneWidget);
    expect(find.text('FAKE'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Run again'), findsOneWidget);
  });

  testWidgets('blocking result hides continue action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreJoinDialog(
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.participant,
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.failed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Backend unavailable.',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Resolve blocking issues before joining'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('pre-join UI follows zh-CN host locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: MediaPreJoinDialog(
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.participant,
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.passed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Backend reachable.',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('加入前检查'), findsOneWidget);
    expect(find.text('可以继续'), findsOneWidget);
    expect(find.text('后端'), findsOneWidget);
    expect(find.text('通过'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('重新检查'), findsOneWidget);
  });

  testWidgets('pre-join page releases local capture when canceled', (
    tester,
  ) async {
    final preview = _FakeLocalPreview();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => MediaPreJoinPage.show(
                  context,
                  runCheck: _readyResult,
                  openPreview: (_, _) async => preview,
                  permissionRequester: const _TestPermissionRequester(),
                  displayName: 'Morgan',
                ),
                child: const Text('Open preparation'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open preparation'));
    await tester.pumpAndSettle();
    expect(find.text('Morgan'), findsOneWidget);
    expect(find.byType(MediaTrackView), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(preview.disposeCalls, 1);
    expect(find.text('Open preparation'), findsOneWidget);
  });

  testWidgets('pre-join page fits a 390px phone viewport', (tester) async {
    final preview = _FakeLocalPreview();
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => MediaPreJoinPage.show(
                  context,
                  runCheck: _readyResult,
                  openPreview: (_, _) async => preview,
                  permissionRequester: const _TestPermissionRequester(),
                ),
                child: const Text('Open preparation'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preparation'));
    await tester.pumpAndSettle();

    expect(find.text('Join meeting'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(preview.disposeCalls, 1);
  });

  testWidgets('pre-join blur selection is returned and applied to preview', (
    tester,
  ) async {
    final preview = _FakeLocalPreview();
    MediaLocalPreviewSettings? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  chosen = await MediaPreJoinPage.show(
                    context,
                    runCheck: _blurReadyResult,
                    openPreview: (_, _) async => preview,
                    permissionRequester: const _TestPermissionRequester(),
                  );
                },
                child: const Text('Open preparation'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open preparation'));
    await tester.pumpAndSettle();
    expect(find.text('Background blur'), findsOneWidget);

    await tester.tap(find.text('Background blur'));
    await tester.pumpAndSettle();
    expect(preview.backgroundCalls, [const MediaBackgroundEffect.blur()]);

    await tester.tap(find.text('Join meeting'));
    await tester.pumpAndSettle();
    expect(chosen?.backgroundEffect, const MediaBackgroundEffect.blur());
  });

  testWidgets('pre-join page preserves selected devices and media state', (
    tester,
  ) async {
    final preview = _FakeLocalPreview();
    MediaLocalPreviewSettings? chosen;
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  chosen = await MediaPreJoinPage.show(
                    context,
                    runCheck: _readyResult,
                    openPreview: (_, _) async => preview,
                    permissionRequester: const _TestPermissionRequester(),
                  );
                },
                child: const Text('Open preparation'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preparation'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    expect(preview.settings.microphoneEnabled, isTrue);
    final microphonePicker = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<MediaDevice>,
    );
    await tester.tap(microphonePicker.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB microphone').last);
    await tester.pumpAndSettle();
    expect(preview.settings.microphone?.id, 'mic-2');

    await tester.tap(find.text('Join meeting'));
    await tester.pumpAndSettle();
    expect(chosen?.microphoneEnabled, isTrue);
    expect(chosen?.microphone?.id, 'mic-2');
    expect(preview.disposeCalls, 1);
  });

  testWidgets(
    'unsupported local preview still lets a ready attendee continue',
    (tester) async {
      MediaLocalPreviewSettings? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    chosen = await MediaPreJoinPage.show(
                      context,
                      runCheck: _readyResult,
                      openPreview: (_, _) async => null,
                      permissionRequester: const _TestPermissionRequester(),
                    );
                  },
                  child: const Text('Open preparation'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preparation'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not supported by this provider'),
        findsWidgets,
      );
      await tester.tap(find.text('Join meeting'));
      await tester.pumpAndSettle();
      expect(chosen, isNotNull);
      expect(chosen!.cameraEnabled, isFalse);
    },
  );
}

Future<MediaPreJoinResult> _readyResult() async => const MediaPreJoinResult(
  role: MediaRole.participant,
  providerId: 'fake',
  checks: [
    MediaPreJoinCheck(
      type: MediaPreJoinCheckType.backend,
      status: MediaPreJoinStatus.passed,
      severity: MediaPreJoinSeverity.blocking,
      message: 'Backend reachable.',
    ),
  ],
);

Future<MediaPreJoinResult> _blurReadyResult() async => const MediaPreJoinResult(
  role: MediaRole.participant,
  providerId: 'fake',
  backgroundCapabilities: MediaBackgroundCapabilities(canBlur: true),
  checks: [
    MediaPreJoinCheck(
      type: MediaPreJoinCheckType.backend,
      status: MediaPreJoinStatus.passed,
      severity: MediaPreJoinSeverity.blocking,
      message: 'Backend reachable.',
    ),
  ],
);

class _FakeLocalPreview
    implements MediaLocalPreviewSession, MediaBackgroundEffectsController {
  int disposeCalls = 0;
  final List<MediaBackgroundEffect> backgroundCalls = [];
  MediaLocalPreviewSettings _settings = const MediaLocalPreviewSettings();
  final _track = const _TestVideoTrack();

  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities(
    canPublishAudio: true,
    canPublishVideo: true,
    canBlurBackground: true,
    canEnumerateAudioDevices: true,
    canEnumerateMicrophones: true,
    canEnumerateCameras: true,
    canSelectMicrophone: true,
    canSelectCamera: true,
    canSelectAudioOutput: true,
  );
  @override
  MediaVideoTrack? get cameraTrack => _settings.cameraEnabled ? _track : null;
  @override
  MediaTrackRenderer get renderer => const _TestTrackRenderer();
  @override
  MediaLocalPreviewSettings get settings => _settings;

  @override
  MediaBackgroundCapabilities get backgroundCapabilities =>
      const MediaBackgroundCapabilities(canBlur: true);

  @override
  MediaBackgroundEffect get backgroundEffect => _settings.backgroundEffect;

  @override
  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) async {
    backgroundCalls.add(effect);
    _settings = _settings.copyWith(backgroundEffect: effect);
  }

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async => const [
    MediaDevice(
      id: 'mic-1',
      label: 'Built-in microphone',
      kind: MediaDeviceKind.microphone,
    ),
    MediaDevice(
      id: 'mic-2',
      label: 'USB microphone',
      kind: MediaDeviceKind.microphone,
    ),
    MediaDevice(
      id: 'camera-1',
      label: 'Built-in camera',
      kind: MediaDeviceKind.camera,
    ),
    MediaDevice(
      id: 'speaker-1',
      label: 'Built-in speaker',
      kind: MediaDeviceKind.audioOutput,
    ),
  ];

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _settings = _settings.copyWith(
      microphone: device.kind == MediaDeviceKind.microphone
          ? device
          : _settings.microphone,
      camera: device.kind == MediaDeviceKind.camera ? device : _settings.camera,
      audioOutput: device.kind == MediaDeviceKind.audioOutput
          ? device
          : _settings.audioOutput,
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _settings = _settings.copyWith(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _settings = _settings.copyWith(cameraEnabled: enabled);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _TestVideoTrack implements MediaVideoTrack {
  const _TestVideoTrack();
  @override
  String get id => 'preview-track';
  @override
  String get participantId => 'local-preview';
  @override
  bool get isLocal => true;
  @override
  bool get isScreenShare => false;
  @override
  int get width => 1280;
  @override
  int get height => 720;
  @override
  double get aspectRatio => 16 / 9;
}

class _TestTrackRenderer extends MediaTrackRenderer {
  const _TestTrackRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const ColoredBox(color: Colors.blueGrey);
}

class _TestPermissionRequester implements MediaPermissionRequester {
  const _TestPermissionRequester();

  @override
  bool get canOpenAppSettings => false;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;

  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
}
