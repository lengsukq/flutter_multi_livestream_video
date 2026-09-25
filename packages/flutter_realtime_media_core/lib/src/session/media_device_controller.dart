import '../model/media_device.dart';
import '../model/media_error.dart';
import 'media_session.dart';

/// Optional provider surface for enumerating and selecting local media devices.
abstract interface class MediaDeviceController {
  Future<List<MediaDevice>> listMediaDevices({Set<MediaDeviceKind>? kinds});

  Future<void> selectMediaDevice(MediaDevice device);
}

extension MediaSessionDeviceControl on MediaSession {
  Future<List<MediaDevice>> listMicrophones() {
    if (!capabilities.canEnumerateMicrophones) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.unsupportedFeature,
          message: 'Microphone enumeration is not supported for this session.',
          providerId: providerId,
        ),
      );
    }
    return listMediaDevices(kinds: const {MediaDeviceKind.microphone});
  }

  Future<List<MediaDevice>> listCameras() {
    if (!capabilities.canEnumerateCameras) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.unsupportedFeature,
          message: 'Camera enumeration is not supported for this session.',
          providerId: providerId,
        ),
      );
    }
    return listMediaDevices(kinds: const {MediaDeviceKind.camera});
  }

  Future<List<MediaDevice>> listAudioOutputs() {
    if (!capabilities.canEnumerateAudioDevices) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.unsupportedFeature,
          message:
              'Audio output enumeration is not supported for this session.',
          providerId: providerId,
        ),
      );
    }
    return listMediaDevices(kinds: const {MediaDeviceKind.audioOutput});
  }

  /// Lists devices when the provider exposes a device controller.
  Future<List<MediaDevice>> listMediaDevices({Set<MediaDeviceKind>? kinds}) {
    final current = this;
    if (current is MediaDeviceController) {
      return (current as MediaDeviceController).listMediaDevices(kinds: kinds);
    }
    throw MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'Media device enumeration is not supported for this session.',
      providerId: providerId,
    );
  }

  /// Selects a previously enumerated device.
  Future<void> selectMediaDevice(MediaDevice device) {
    final supported = switch (device.kind) {
      MediaDeviceKind.microphone => capabilities.canSelectMicrophone,
      MediaDeviceKind.camera => capabilities.canSelectCamera,
      MediaDeviceKind.audioOutput => capabilities.canSelectAudioOutput,
    };
    if (!supported) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.unsupportedFeature,
          message:
              '${device.kind.name} device selection is not supported for this session.',
          providerId: providerId,
        ),
      );
    }
    final current = this;
    if (current is MediaDeviceController) {
      return (current as MediaDeviceController).selectMediaDevice(device);
    }
    throw MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'Media device selection is not supported for this session.',
      providerId: providerId,
    );
  }

  Future<void> selectMicrophone(MediaDevice device) {
    if (device.kind != MediaDeviceKind.microphone) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.invalidArgument,
          message: 'selectMicrophone requires a microphone device.',
          providerId: providerId,
        ),
      );
    }
    return selectMediaDevice(device);
  }

  Future<void> selectCamera(MediaDevice device) {
    if (device.kind != MediaDeviceKind.camera) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.invalidArgument,
          message: 'selectCamera requires a camera device.',
          providerId: providerId,
        ),
      );
    }
    return selectMediaDevice(device);
  }

  Future<void> selectAudioOutput(MediaDevice device) {
    if (device.kind != MediaDeviceKind.audioOutput) {
      return Future.error(
        MediaError(
          code: MediaErrorCode.invalidArgument,
          message: 'selectAudioOutput requires an audio output device.',
          providerId: providerId,
        ),
      );
    }
    return selectMediaDevice(device);
  }
}
