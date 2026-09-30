class VideoEffectsCameraDevice {
  const VideoEffectsCameraDevice({
    required this.id,
    required this.label,
    this.isFrontFacing = false,
  });

  factory VideoEffectsCameraDevice.fromJson(Map<String, Object?> json) =>
      VideoEffectsCameraDevice(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        isFrontFacing: json['isFrontFacing'] == true,
      );

  final String id;
  final String label;
  final bool isFrontFacing;
}
