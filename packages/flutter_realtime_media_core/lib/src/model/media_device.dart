/// Provider-neutral local media device.
enum MediaDeviceKind { microphone, camera, audioOutput }

class MediaDevice {
  const MediaDevice({
    required this.id,
    required this.label,
    required this.kind,
    this.groupId,
  });

  /// Provider/platform device identifier. Treat as opaque.
  final String id;

  /// Human-readable label exposed by the platform.
  final String label;

  final MediaDeviceKind kind;

  /// Optional platform grouping identifier.
  final String? groupId;

  @override
  String toString() => 'MediaDevice($kind, $label, id: $id)';
}
