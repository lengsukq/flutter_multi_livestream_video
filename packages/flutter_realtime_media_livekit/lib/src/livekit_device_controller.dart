import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class LiveKitDeviceController implements MediaDeviceController {
  LiveKitDeviceController({
    required this.capabilities,
    required this.requireRoom,
    required this.ensureActive,
  });
  final MediaCapabilities Function() capabilities;
  final lk.Room Function() requireRoom;
  final void Function() ensureActive;
  final String providerId = 'livekit';
  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    ensureActive();
    final requested = kinds ?? MediaDeviceKind.values.toSet();
    final devices = <MediaDevice>[];
    try {
      if (requested.contains(MediaDeviceKind.microphone) &&
          capabilities().canEnumerateMicrophones) {
        devices.addAll(
          (await lk.Hardware.instance.audioInputs()).map(
            (device) => MediaDevice(
              id: device.deviceId,
              label: device.label,
              kind: MediaDeviceKind.microphone,
              groupId: device.groupId,
            ),
          ),
        );
      }
      if (requested.contains(MediaDeviceKind.camera) &&
          capabilities().canEnumerateCameras) {
        devices.addAll(
          (await lk.Hardware.instance.videoInputs()).map(
            (device) => MediaDevice(
              id: device.deviceId,
              label: device.label,
              kind: MediaDeviceKind.camera,
              groupId: device.groupId,
            ),
          ),
        );
      }
      if (requested.contains(MediaDeviceKind.audioOutput) &&
          capabilities().canEnumerateAudioDevices) {
        devices.addAll(
          (await lk.Hardware.instance.audioOutputs()).map(
            (device) => MediaDevice(
              id: device.deviceId,
              label: device.label,
              kind: MediaDeviceKind.audioOutput,
              groupId: device.groupId,
            ),
          ),
        );
      }
      return List.unmodifiable(devices);
    } catch (error) {
      throw normalizeRealtimeException(
        error,
        domain: 'media',
        operation: 'listDevices',
        providerId: providerId,
      );
    }
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    ensureActive();
    try {
      switch (device.kind) {
        case MediaDeviceKind.microphone:
          if (!capabilities().canSelectMicrophone) {
            _unsupportedDevice('microphone device selection');
          }
          final selected = await _findLiveKitDevice(
            device,
            lk.Hardware.instance.audioInputs,
          );
          await requireRoom().setAudioInputDevice(selected);
        case MediaDeviceKind.camera:
          if (!capabilities().canSelectCamera) {
            _unsupportedDevice('camera device selection');
          }
          final selected = await _findLiveKitDevice(
            device,
            lk.Hardware.instance.videoInputs,
          );
          await requireRoom().setVideoInputDevice(selected);
        case MediaDeviceKind.audioOutput:
          if (!capabilities().canSelectAudioOutput) {
            _unsupportedDevice('audio output device selection');
          }
          final selected = await _findLiveKitDevice(
            device,
            lk.Hardware.instance.audioOutputs,
          );
          await requireRoom().setAudioOutputDevice(selected);
      }
    } on RealtimeException {
      rethrow;
    } catch (error) {
      throw normalizeRealtimeException(
        error,
        domain: 'media',
        operation: 'selectDevice',
        providerId: providerId,
      );
    }
  }

  Future<lk.MediaDevice> _findLiveKitDevice(
    MediaDevice device,
    Future<List<lk.MediaDevice>> Function() loader,
  ) async {
    final values = await loader();
    for (final value in values) {
      if (value.deviceId == device.id ||
          (device.id.isEmpty && value.label == device.label)) {
        return value;
      }
    }
    throw RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message: 'The selected media device is no longer available.',
      providerId: providerId,
    );
  }

  Never _unsupportedDevice(String feature) => throw RealtimeException(
    code: RealtimeErrorCode.unsupportedFeature,
    message: 'LiveKit $feature is not supported for this session.',
    providerId: providerId,
  );
}
