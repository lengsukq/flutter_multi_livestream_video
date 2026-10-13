class ProcessedVideoCameraDevice {
  const ProcessedVideoCameraDevice({
    required this.id,
    required this.label,
    this.isFrontFacing = false,
  });

  factory ProcessedVideoCameraDevice.fromJson(Map<String, Object?> json) =>
      ProcessedVideoCameraDevice(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        isFrontFacing: json['isFrontFacing'] == true,
      );

  final String id;
  final String label;
  final bool isFrontFacing;
}
