part of 'chime_media_session.dart';

class _ChimeMediaControls {
  _ChimeMediaControls(this._session);
  final ChimeMediaSession _session;
  String get providerId => _session.providerId;
  MediaCapabilities get capabilities => _session.capabilities;
  MediaRole get role => _session.role;
  MediaSessionState get state => _session.state;
  MediaSnapshot get snapshot => _session.snapshot;
  Duration get cleanupTimeout => _session.cleanupTimeout;

  bool _macEffectsInputAvailable = false;
  bool get _effectsPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.macOS &&
              _macEffectsInputAvailable));
  Future<void> _probeProcessedVideoInput() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      _macEffectsInputAvailable =
          await MethodChannel(
            _processedSink.channelName,
          ).invokeMethod<bool>('probeProcessedVideoInput') ??
          false;
    } on MissingPluginException {
      _macEffectsInputAvailable = false;
    } on PlatformException {
      _macEffectsInputAvailable = false;
    }
  }

  final _processedSink = NativeProcessedVideoSink(
    providerId: 'chime',
    channelName: 'com.oneplusdream.aws.chime.methodChannel',
    attachMethod: 'attachProcessedVideoSource',
    detachMethod: 'detachProcessedVideoSource',
  );
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      capabilities.canPublishVideo &&
      _effectsPlatform &&
      _processedSink.supports(source) &&
      source.platform ==
          (defaultTargetPlatform == TargetPlatform.android
              ? ProcessedVideoPlatform.android
              : ProcessedVideoPlatform.macos);
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) async {
    _session._ensureActive();
    if (!supportsProcessedVideoSource(source)) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        providerId: providerId,
        message:
            'Processed video input is unavailable for this role or platform.',
      );
    }
    await _processedSink.attach(source);
  }

  Future<void> detachProcessedVideoSource() => _processedSink.detach();

  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    final requested = kinds ?? MediaDeviceKind.values.toSet();
    _session._ensureActive();
    final cameras =
        capabilities.canEnumerateCameras &&
            requested.contains(MediaDeviceKind.camera)
        ? await ProcessedVideoBridge().listCameras()
        : const <ProcessedVideoCameraDevice>[];
    final devices = requested.contains(MediaDeviceKind.audioOutput)
        ? await listAudioDevices()
        : const <MediaAudioDevice>[];
    return [
      for (final camera in cameras)
        MediaDevice(
          id: camera.id,
          label: camera.label,
          kind: MediaDeviceKind.camera,
        ),
      ...devices.map(
        (device) => MediaDevice(
          id: device.id ?? device.label,
          label: device.label,
          kind: MediaDeviceKind.audioOutput,
        ),
      ),
    ];
  }

  Future<void> selectMediaDevice(MediaDevice device) async {
    _session._ensureActive();
    if (device.kind == MediaDeviceKind.camera && capabilities.canSelectCamera) {
      if (_processedSink.source == null) {
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          providerId: providerId,
          message: 'Prepare the SDK video source before selecting a camera.',
        );
      }
      await _processedSink.selectCamera(device.id);
      return;
    }
    if (device.kind != MediaDeviceKind.audioOutput) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Chime only exposes audio output device selection.',
        providerId: providerId,
      );
    }
    final mapped = MediaAudioDevice.fromLabel(device.label);
    return selectAudioDevice(
      MediaAudioDevice(
        id: device.id.isEmpty ? null : device.id,
        label: mapped.label,
        type: mapped.type,
      ),
    );
  }

  Future<void> setMuted(bool muted) async {
    _session._ensureActive();
    try {
      await _session._session.setMuted(muted);
      _session._mapper._onProviderSnapshot(_session._session.snapshot);
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'setMuted', stack: stack);
    }
  }

  Future<void> toggleMute() async {
    _session._ensureActive();
    try {
      await _session._session.toggleMute();
      _session._mapper._onProviderSnapshot(_session._session.snapshot);
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'toggleMute', stack: stack);
    }
  }

  Future<void> setVideoEnabled(bool enabled) async {
    _session._ensureActive();
    try {
      await _processedSink.setEnabled(enabled);
      await _session._session.setVideoEnabled(enabled);
      _session._mapper._onProviderSnapshot(_session._session.snapshot);
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'setVideoEnabled', stack: stack);
    }
  }

  Future<void> setScreenShareEnabled(bool enabled) async {
    throw RealtimeException(
      code: RealtimeErrorCode.unsupportedFeature,
      message: 'Outgoing screen share is not implemented by flutter_aws_chime.',
      providerId: providerId,
    );
  }

  Future<void> switchCamera(MediaCameraPosition position) async {
    _session._ensureActive();
    try {
      if (_processedSink.source != null) {
        await _processedSink.selectCamera(
          position == MediaCameraPosition.front ? 'front' : 'back',
        );
        return;
      }
      await _session._session.switchCamera(
        position == MediaCameraPosition.front
            ? chime.CameraPosition.front
            : chime.CameraPosition.back,
      );
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'switchCamera', stack: stack);
    }
  }

  Future<List<MediaAudioDevice>> listAudioDevices() async {
    _session._ensureActive();
    try {
      final devices = await _session._session.listAudioDevices();
      return devices.map(_mapAudioDevice).toList(growable: false);
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'listAudioDevices', stack: stack);
    }
  }

  Future<void> selectAudioDevice(MediaAudioDevice device) async {
    _session._ensureActive();
    try {
      await _session._session.selectAudioDevice(
        chime.ChimeAudioDevice.fromLabel(device.label),
      );
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'selectAudioDevice', stack: stack);
    }
  }

  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    _session._ensureActive();
    try {
      await _session._session.sendMessage(message, topic: topic);
      _session._mapper._onProviderSnapshot(_session._session.snapshot);
    } on chime.RealtimeException catch (error, stack) {
      throw _mapError(error, stage: 'sendMessage', stack: stack);
    }
  }
}
