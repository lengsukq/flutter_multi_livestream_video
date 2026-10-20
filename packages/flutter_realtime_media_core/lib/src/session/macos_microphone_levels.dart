import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// True PCM microphone input energy from the macOS CoreAudio capture graph.
///
/// Subscribing starts a capture tap, and cancelling it immediately releases
/// the microphone. Callers must only subscribe after the user explicitly
/// enabled the microphone in Pre-Join. No backend or RTC room is involved.
class MacosMicrophoneLevels {
  const MacosMicrophoneLevels._();

  static const EventChannel _channel = EventChannel(
    'flutter_realtime_media_core/microphone_levels',
  );

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static Stream<double> get levels => _channel.receiveBroadcastStream().map(
    (value) => switch (value) {
      final num sample when sample.isFinite => sample.toDouble().clamp(
        0.0,
        1.0,
      ),
      _ => 0.0,
    },
  );
}
