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
      await owner.dispose();
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

  test('provider display names keep known brands readable', () {
    expect(mediaProviderDisplayName('livekit'), 'LiveKit');
    expect(mediaProviderDisplayName('trtc'), 'Tencent TRTC');
    expect(mediaProviderDisplayName('aws'), 'AWS');
    expect(mediaProviderDisplayName('chime'), 'AWS · Chime');
    expect(mediaProviderDisplayName('ivs'), 'AWS · IVS');
    expect(mediaProviderDisplayName('custom'), 'CUSTOM');
  });
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
