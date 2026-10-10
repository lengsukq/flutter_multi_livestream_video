import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_media_ui/src/pre_join_media_setup_controller.dart';
import 'package:flutter_realtime_media_ui/src/pre_join_permission_coordinator.dart';
import 'package:flutter_realtime_media_ui/src/pre_join_preview_owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preview owner releases camera exactly once across duplicate exits',
    () async {
      final preview = _FakeLocalPreview();
      final owner = PreJoinPreviewOwner();
      owner.bind(preview, onFailure: (_) {});
      await Future.wait([owner.release(), owner.release()]);
      expect(preview.disposeCalls, 1);
      expect(owner.session, isNull);
      owner.dispose();
    },
  );

  test(
    'preview owner shares native release and disallows early rebind',
    () async {
      final gate = Completer<void>();
      final old = _DelayedDisposePreview(gate.future);
      final owner = PreJoinPreviewOwner();
      owner.bind(old, onFailure: (_) {});
      final first = owner.release();
      final second = owner.release();
      expect(identical(first, second), isTrue);
      expect(old.disposeCalls, 1);
      expect(
        () => owner.bind(_FakeLocalPreview(), onFailure: (_) {}),
        throwsStateError,
      );
      gate.complete();
      await Future.wait([first, second]);
      final replacement = _FakeLocalPreview();
      owner.bind(replacement, onFailure: (_) {});
      await owner.release();
      expect(old.disposeCalls, 1);
      expect(replacement.disposeCalls, 1);
    },
  );

  testWidgets(
    'duplicate Pre-Join enters and forced route removal do not create late navigation',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final gate = Completer<void>();
      final preview = _FakeLocalPreview();
      Route<dynamic>? preJoinRoute;
      var connectionAttempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => MediaPreJoinPage.show(
                  context,
                  runCheck: _readyResult,
                  openPreview: (_, _) async => preview,
                  permissionRequester: const _TestPermissionRequester(),
                  onEnter: (pageContext, _) async {
                    connectionAttempts++;
                    preJoinRoute = ModalRoute.of(pageContext);
                    await gate.future;
                    if (!pageContext.mounted) return;
                    Navigator.of(
                      pageContext,
                    ).pushReplacement<void, MediaLocalPreviewSettings>(
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(body: Text('Late room')),
                      ),
                    );
                  },
                ),
                child: const Text('Prepare'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Prepare'));
      await tester.pumpAndSettle();
      final join = find.text('Join meeting');
      await tester.tap(join);
      await tester.pump();
      expect(connectionAttempts, 1);
      expect(preview.disposeCalls, 1);
      expect(find.text('Entering room…'), findsOneWidget);
      // The in-flight join disables the button and cannot be scheduled again.
      expect(find.byType(MediaPreJoinPage), findsOneWidget);
      navigatorKey.currentState!.removeRoute(preJoinRoute!);
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(connectionAttempts, 1);
      expect(preview.disposeCalls, 1);
      expect(find.text('Prepare'), findsOneWidget);
      expect(find.text('Late room'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'device setup ignores superseded device query and preserves background',
    () async {
      final setup = PreJoinMediaSetupController();
      final pending = Completer<List<MediaDevice>>();
      final slow = _DelayedLocalPreview(pending.future);
      final outdated = setup.loadDevices(slow);
      setup.resetDevices();
      pending.complete(const [
        MediaDevice(
          id: 'stale',
          label: 'Old microphone',
          kind: MediaDeviceKind.microphone,
        ),
      ]);
      await outdated;
      expect(setup.devices, isEmpty);

      final preview = _FakeLocalPreview();
      await setup.loadDevices(preview);
      expect(setup.devices, hasLength(4));
      final selected = await setup.selectDevice(preview, setup.devices.first);
      expect(selected, isTrue);
      expect(preview.settings.microphone?.id, 'mic-1');
      await setup.applyBackground(preview, const MediaBackgroundEffect.blur());
      expect(setup.backgroundEffect, const MediaBackgroundEffect.blur());
      expect(preview.backgroundCalls, hasLength(1));
      setup.applyCapabilities(const MediaBackgroundCapabilities());
      expect(setup.backgroundEffect.enabled, isFalse);
      setup.dispose();
    },
  );

  test(
    'permission coordinator fails safely when permission query is unavailable',
    () async {
      final coordinator = PreJoinPermissionCoordinator(
        const _TestPermissionRequester(),
      );
      final states = await coordinator.readStatuses();
      expect(states[MediaPermissionKind.camera], MediaPermissionState.granted);
      expect(
        await coordinator.request(MediaPermissionKind.microphone),
        MediaPermissionState.granted,
      );
    },
  );

  testWidgets('room entry stays on Pre-Join until the room is connected', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final preview = _FakeLocalPreview();
    final connectionReady = Completer<void>();
    var joinCalls = 0;
    MediaLocalPreviewSettings? joiningSettings;
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
                  onEnter: (preJoinContext, settings) async {
                    joinCalls++;
                    joiningSettings = settings;
                    await connectionReady.future;
                    if (!preJoinContext.mounted) return;
                    await Navigator.of(
                      preJoinContext,
                    ).pushReplacement<void, MediaLocalPreviewSettings>(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Connected room')),
                          body: const Text('Live media room'),
                        ),
                      ),
                    );
                  },
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
    await tester.tap(find.text('Join meeting'));
    await tester.pump();
    expect(joinCalls, 1);
    expect(find.text('Entering room…'), findsOneWidget);
    expect(find.byType(MediaPreJoinPage), findsOneWidget);
    expect(find.text('Connected room'), findsNothing);
    expect(joiningSettings, isNotNull);
    expect(preview.disposeCalls, 1);
    for (final size in <Size>[
      const Size(320, 640),
      const Size(390, 844),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(find.text('Entering room…'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Joining overlay overflow at $size',
      );
    }

    connectionReady.complete();
    await tester.pumpAndSettle();
    expect(find.text('Connected room'), findsOneWidget);
    expect(find.text('Entering room…'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open preparation'), findsOneWidget);
    expect(preview.disposeCalls, 1);
  });

  testWidgets('failed room entry displays error on Pre-Join and allows retry', (
    tester,
  ) async {
    final previews = <_FakeLocalPreview>[];
    var joinCalls = 0;
    final submittedSettings = <MediaLocalPreviewSettings>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => MediaPreJoinPage.show(
                  context,
                  runCheck: _readyResult,
                  openPreview: (_, _) async {
                    final preview = _FakeLocalPreview();
                    previews.add(preview);
                    return preview;
                  },
                  permissionRequester: const _TestPermissionRequester(),
                  onEnter: (_, settings) async {
                    submittedSettings.add(settings);
                    joinCalls++;
                    if (joinCalls == 1) throw StateError('Token expired');
                  },
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
    await tester.tap(find.text('Join meeting'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Token expired'), findsOneWidget);
    expect(find.text('Join meeting'), findsOneWidget);
    expect(find.text('Open preparation'), findsNothing);
    expect(previews.first.disposeCalls, 1);
    expect(previews.length, 2, reason: 'Restore local preview after failure');

    await tester.tap(find.text('Join meeting'));
    await tester.pumpAndSettle();
    expect(joinCalls, 2);
    expect(submittedSettings, hasLength(2));
    expect(find.text('Open preparation'), findsOneWidget);
    expect(previews.last.disposeCalls, 1);
  });

  test('provider display names keep known brands readable', () {
    expect(mediaProviderDisplayName('livekit'), 'LiveKit');
    expect(mediaProviderDisplayName('trtc'), 'Tencent TRTC');
    expect(mediaProviderDisplayName('aws'), 'AWS');
    expect(mediaProviderDisplayName('chime'), 'AWS · Chime');
    expect(mediaProviderDisplayName('ivs'), 'AWS · IVS');
    expect(mediaProviderDisplayName('custom'), 'CUSTOM');
  });

  testWidgets(
    'pre-join scales across compact phones, tablet and desktop windows',
    (tester) async {
      final preview = _FakeLocalPreview();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
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
                    backendProviderId: 'tencent_rtc',
                    roomLabel: 'room-demo',
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
      // Preview capture is opt-in: the camera track must appear only after
      // explicit user consent, and remain responsive at each viewport width.
      expect(find.byType(MediaTrackView), findsNothing);
      final cameraToggle = find.widgetWithText(FilterChip, 'Camera');
      await tester.ensureVisible(cameraToggle);
      await tester.tap(cameraToggle);
      await tester.pumpAndSettle();
      for (final size in <Size>[
        const Size(320, 640),
        const Size(390, 844),
        const Size(820, 620),
        const Size(1024, 768),
        const Size(1366, 820),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(find.text('Join meeting'), findsOneWidget);
        expect(find.byType(MediaTrackView), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Pre-join layout overflow at $size',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(preview.disposeCalls, 1);
    },
  );

  testWidgets('ready result exposes continue action', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 900);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreJoinPage(
          openPreview: (_, _) async => null,
          permissionRequester: const _TestPermissionRequester(),
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
    expect(find.text('FAKE'), findsWidgets);
    expect(find.text('Join meeting'), findsOneWidget);
    expect(find.text('Run again'), findsOneWidget);
  });

  testWidgets('blocking result hides continue action', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 900);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreJoinPage(
          openPreview: (_, _) async => null,
          permissionRequester: const _TestPermissionRequester(),
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
    expect(find.text('Join meeting'), findsOneWidget);
    expect(
      tester
          .widgetList<RealtimeGlassButton>(find.byType(RealtimeGlassButton))
          .last
          .onPressed,
      isNull,
    );
  });

  testWidgets('pre-join UI follows zh-CN host locale', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 900);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: MediaPreJoinPage(
          openPreview: (_, _) async => null,
          permissionRequester: const _TestPermissionRequester(),
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

    expect(find.text('加入前检查'), findsWidgets);
    expect(find.text('可以继续'), findsOneWidget);
    expect(find.text('后端'), findsOneWidget);
    expect(find.text('通过'), findsOneWidget);
    expect(find.text('加入会议'), findsOneWidget);
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
    expect(preview.settings.microphoneEnabled, isFalse);
    expect(preview.settings.cameraEnabled, isFalse);
    expect(find.byType(MediaTrackView), findsNothing);

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

class _DelayedDisposePreview extends _FakeLocalPreview {
  _DelayedDisposePreview(this.releaseGate);
  final Future<void> releaseGate;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await releaseGate;
  }
}

class _DelayedLocalPreview extends _FakeLocalPreview {
  _DelayedLocalPreview(this.pending);
  final Future<List<MediaDevice>> pending;

  @override
  Future<List<MediaDevice>> listMediaDevices({Set<MediaDeviceKind>? kinds}) =>
      pending;
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
