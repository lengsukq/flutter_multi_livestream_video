import '../model/media_audio_device.dart';
import 'media_session.dart';

/// Session that can publish realtime data messages.
///
/// Messaging is separate from media publishing so broadcast viewers can offer
/// chat without gaining any audio/video publish ability.
abstract class MediaDataMessenger {
  /// Sends a data message on [topic].
  ///
  /// Throws `MediaError` with `invalidArgument` for empty input and
  /// `unsupportedFeature` when the session cannot send data.
  Future<void> sendMessage(String message, {String topic});
}

/// Interactive session: symmetric meeting participant or broadcast host.
///
/// Camera and microphone operations must fail with `MediaError` (not a
/// provider exception) and must leave the session usable after a failure.
abstract class InteractiveMediaSession extends MediaSession
    implements MediaDataMessenger {
  /// Mutes or unmutes the local microphone.
  Future<void> setMuted(bool muted);

  /// Toggles the local microphone.
  Future<void> toggleMute();

  /// Starts or stops publishing the local camera.
  Future<void> setVideoEnabled(bool enabled);

  /// Starts or stops publishing a local screen share.
  ///
  /// Fails with `unsupportedFeature` when `canScreenShare` is false.
  Future<void> setScreenShareEnabled(bool enabled);

  /// Switches between the front and back camera.
  ///
  /// Fails with `unsupportedFeature` when `canSwitchCamera` is false.
  Future<void> switchCamera(MediaCameraPosition position);

  /// Lists available audio output devices.
  ///
  /// Fails with `unsupportedFeature` when `canEnumerateAudioDevices` is false.
  Future<List<MediaAudioDevice>> listAudioDevices();

  /// Selects an audio output device returned by [listAudioDevices].
  Future<void> selectAudioDevice(MediaAudioDevice device);
}
