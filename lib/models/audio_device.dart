/// Broad device category for applications that want to present their own
/// audio-output picker. [label] is the native Chime SDK label and is used when
/// selecting the device; [type] is a best-effort classification of that label.
class ChimeAudioDevice {
  const ChimeAudioDevice({required this.label, required this.type});

  final String label;
  final ChimeAudioDeviceType type;

  factory ChimeAudioDevice.fromLabel(String label) {
    final normalized = label.toLowerCase();
    final type = switch (normalized) {
      _ when normalized.contains('bluetooth') => ChimeAudioDeviceType.bluetooth,
      _
          when normalized.contains('headset') ||
              normalized.contains('headphone') =>
        ChimeAudioDeviceType.wiredHeadset,
      _ when normalized.contains('speaker') => ChimeAudioDeviceType.speaker,
      _
          when normalized.contains('earpiece') ||
              normalized.contains('receiver') =>
        ChimeAudioDeviceType.earpiece,
      _ => ChimeAudioDeviceType.other,
    };
    return ChimeAudioDevice(label: label, type: type);
  }
}

/// Coarse categories for the audio devices exposed by the native SDK.
enum ChimeAudioDeviceType { bluetooth, wiredHeadset, speaker, earpiece, other }
