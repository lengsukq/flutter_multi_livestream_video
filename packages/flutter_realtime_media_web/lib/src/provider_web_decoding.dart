import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

MediaSessionState? webSessionState(String? value) => switch (value) {
  'joining' => MediaSessionState.joining,
  'connecting' => MediaSessionState.connecting,
  'connected' => MediaSessionState.connected,
  'reconnecting' => MediaSessionState.reconnecting,
  'leaving' => MediaSessionState.leaving,
  'ended' => MediaSessionState.ended,
  'failed' => MediaSessionState.failed,
  _ => null,
};

MediaNetworkQuality webNetworkQuality(Object? value) =>
    switch (value?.toString().toLowerCase()) {
      'excellent' || '1' => MediaNetworkQuality.excellent,
      'good' || '2' => MediaNetworkQuality.good,
      'fair' || '3' => MediaNetworkQuality.fair,
      'poor' || '4' => MediaNetworkQuality.poor,
      'bad' || '5' => MediaNetworkQuality.bad,
      'down' || '6' => MediaNetworkQuality.down,
      _ => MediaNetworkQuality.unknown,
    };

int? webInt(Object? value) => value is int
    ? value
    : value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '');

double? webDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

extension ProviderWebAudioDevice on MediaAudioDevice {
  MediaAudioDevice copyWithId(String? value) =>
      MediaAudioDevice(id: value, label: label, type: type);
}
