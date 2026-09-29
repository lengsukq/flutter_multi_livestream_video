import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_media_track.dart';
import 'livekit_track_renderer.dart';

class LiveKitLocalPreviewSession implements MediaLocalPreviewSession {
  LiveKitLocalPreviewSession._({
    required this.role,
    required this.capabilities,
    required lk.LocalVideoTrack? cameraTrack,
  }) : _cameraTrack = cameraTrack,
       _settings = MediaLocalPreviewSettings(
         cameraEnabled: cameraTrack != null,
       );

  static Future<LiveKitLocalPreviewSession> create({
    required MediaRole role,
  }) async {
    final canPublish = role != MediaRole.viewer;
    final capabilities = _previewCapabilities(canPublish);
    lk.LocalVideoTrack? camera;
    try {
      if (canPublish) camera = await lk.LocalVideoTrack.createCameraTrack();
      return LiveKitLocalPreviewSession._(
        role: role,
        capabilities: capabilities,
        cameraTrack: camera,
      );
    } catch (error) {
      try {
        await camera?.stop();
      } catch (_) {}
      throw MediaError(
        code: _isPermissionFailure(error)
            ? MediaErrorCode.permissionDenied
            : MediaErrorCode.nativeError,
        message: 'Unable to start the LiveKit camera preview.',
        details: error,
        providerId: 'livekit',
      );
    }
  }

  static MediaCapabilities _previewCapabilities(bool canPublish) {
    final desktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    final canSelectOutput =
        !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;
    return MediaCapabilities(
      canPublishAudio: canPublish,
      canPublishVideo: canPublish,
      canSwitchCamera: canPublish,
      canEnumerateAudioDevices: true,
      canEnumerateMicrophones: canPublish,
      canEnumerateCameras: canPublish,
      canSelectMicrophone: canPublish && (kIsWeb || desktop),
      canSelectCamera: canPublish,
      canSelectAudioOutput: canSelectOutput,
    );
  }

  static bool _isPermissionFailure(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('permission') ||
        value.contains('denied') ||
        value.contains('notallowed');
  }

  @override
  final String providerId = 'livekit';

  @override
  final MediaRole role;

  @override
  final MediaCapabilities capabilities;

  @override
  final MediaTrackRenderer renderer = const LiveKitTrackRenderer();

  lk.LocalVideoTrack? _cameraTrack;
  lk.LocalAudioTrack? _microphoneTrack;
  MediaDevice? _selectedMicrophone;
  MediaDevice? _selectedCamera;
  MediaDevice? _selectedOutput;
  MediaLocalPreviewSettings _settings;
  bool _disposed = false;

  @override
  MediaVideoTrack? get cameraTrack {
    final track = _cameraTrack;
    if (track == null) return null;
    return LiveKitMediaVideoTrack(
      liveKitTrack: track,
      id: 'livekit-preview-${track.hashCode}',
      participantId: 'local-preview',
      isLocal: true,
      isScreenShare: false,
      width: 1280,
      height: 720,
    );
  }

  @override
  MediaLocalPreviewSettings get settings => _settings;

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _ensureActive();
    final hardware = lk.Hardware.instance;
    final devices = <MediaDevice>[];
    if (kinds == null || kinds.contains(MediaDeviceKind.microphone)) {
      if (capabilities.canEnumerateMicrophones) {
        devices.addAll((await hardware.audioInputs()).map(_mapDevice));
      }
    }
    if (kinds == null || kinds.contains(MediaDeviceKind.camera)) {
      if (capabilities.canEnumerateCameras) {
        devices.addAll((await hardware.videoInputs()).map(_mapDevice));
      }
    }
    if (kinds == null || kinds.contains(MediaDeviceKind.audioOutput)) {
      if (capabilities.canEnumerateAudioDevices) {
        devices.addAll((await hardware.audioOutputs()).map(_mapDevice));
      }
    }
    return List.unmodifiable(devices);
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _ensureActive();
    switch (device.kind) {
      case MediaDeviceKind.microphone:
        if (!capabilities.canSelectMicrophone) {
          throw _unsupported('Microphone selection');
        }
        _selectedMicrophone = device;
        if (_microphoneTrack != null) {
          await _microphoneTrack!.setDeviceId(device.id);
        } else if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows)) {
          await lk.Hardware.instance.selectAudioInput(_toLiveKitDevice(device));
        }
        break;
      case MediaDeviceKind.camera:
        if (!capabilities.canSelectCamera) {
          throw _unsupported('Camera selection');
        }
        _selectedCamera = device;
        if (_cameraTrack != null) await _cameraTrack!.switchCamera(device.id);
        break;
      case MediaDeviceKind.audioOutput:
        if (!capabilities.canSelectAudioOutput) {
          throw _unsupported('Audio output selection');
        }
        _selectedOutput = device;
        await lk.Hardware.instance.selectAudioOutput(_toLiveKitDevice(device));
        break;
    }
    _refreshSettings();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _ensureActive();
    if (!capabilities.canPublishAudio) throw _unsupported('Microphone capture');
    if (enabled == _settings.microphoneEnabled) return;
    if (enabled) {
      try {
        _microphoneTrack = await lk.LocalAudioTrack.create(
          lk.AudioCaptureOptions(deviceId: _selectedMicrophone?.id),
        );
      } catch (error) {
        throw MediaError(
          code: _isPermissionFailure(error)
              ? MediaErrorCode.permissionDenied
              : MediaErrorCode.nativeError,
          message: 'Unable to start the LiveKit microphone check.',
          details: error,
          providerId: providerId,
        );
      }
    } else {
      await _microphoneTrack?.stop();
      _microphoneTrack = null;
    }
    _refreshSettings(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _ensureActive();
    if (!capabilities.canPublishVideo) throw _unsupported('Camera capture');
    if (enabled == _settings.cameraEnabled) return;
    if (enabled) {
      try {
        _cameraTrack = await lk.LocalVideoTrack.createCameraTrack(
          lk.CameraCaptureOptions(deviceId: _selectedCamera?.id),
        );
      } catch (error) {
        throw MediaError(
          code: _isPermissionFailure(error)
              ? MediaErrorCode.permissionDenied
              : MediaErrorCode.nativeError,
          message: 'Unable to start the LiveKit camera preview.',
          details: error,
          providerId: providerId,
        );
      }
    } else {
      await _cameraTrack?.stop();
      _cameraTrack = null;
    }
    _refreshSettings(cameraEnabled: enabled);
  }

  void _refreshSettings({bool? microphoneEnabled, bool? cameraEnabled}) {
    _settings = MediaLocalPreviewSettings(
      microphoneEnabled: microphoneEnabled ?? _settings.microphoneEnabled,
      cameraEnabled: cameraEnabled ?? _settings.cameraEnabled,
      microphone: _selectedMicrophone,
      camera: _selectedCamera,
      audioOutput: _selectedOutput,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final microphone = _microphoneTrack;
    final camera = _cameraTrack;
    _microphoneTrack = null;
    _cameraTrack = null;
    try {
      await microphone?.stop();
    } finally {
      await camera?.stop();
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The local preview session has been disposed.',
        providerId: providerId,
      );
    }
  }

  MediaError _unsupported(String operation) => MediaError(
    code: MediaErrorCode.unsupportedFeature,
    message: '$operation is not supported by the LiveKit preview.',
    providerId: providerId,
  );
}

MediaDevice _mapDevice(lk.MediaDevice device) => MediaDevice(
  id: device.deviceId,
  label: device.label.isEmpty ? device.kind : device.label,
  kind: switch (device.kind) {
    'audioinput' => MediaDeviceKind.microphone,
    'videoinput' => MediaDeviceKind.camera,
    _ => MediaDeviceKind.audioOutput,
  },
  groupId: device.groupId,
);

lk.MediaDevice _toLiveKitDevice(MediaDevice device) =>
    lk.MediaDevice(device.id, device.label, switch (device.kind) {
      MediaDeviceKind.microphone => 'audioinput',
      MediaDeviceKind.camera => 'videoinput',
      MediaDeviceKind.audioOutput => 'audiooutput',
    }, device.groupId ?? '');
