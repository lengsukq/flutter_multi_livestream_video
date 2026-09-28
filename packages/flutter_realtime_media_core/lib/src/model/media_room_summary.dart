import 'media_room_mode.dart';

/// Lightweight room information returned by backend room discovery.
class MediaRoomSummary {
  const MediaRoomSummary({
    required this.roomCode,
    required this.providerId,
    required this.attendeeCount,
    this.roomMode,
    this.createdAt,
    this.engineId,
  });

  final String roomCode;
  final String providerId;

  /// Concrete engine id when [providerId] is a public vendor such as `aws`.
  final String? engineId;
  final MediaRoomMode? roomMode;
  final int attendeeCount;
  final DateTime? createdAt;

  factory MediaRoomSummary.fromJson(Map<String, dynamic> json) {
    final roomCode = json['roomCode']?.toString().trim() ?? '';
    final providerId = json['provider']?.toString().trim().toLowerCase() ?? '';
    final rawEngineId = json['engine']?.toString().trim().toLowerCase();
    final rawMode = json['roomMode']?.toString().trim().toLowerCase();
    final roomMode = switch (rawMode) {
      'meeting' => MediaRoomMode.meeting,
      'broadcast' => MediaRoomMode.broadcast,
      _ => null,
    };
    final rawCount = json['attendeeCount'];
    final attendeeCount = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '') ?? 0;
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    return MediaRoomSummary(
      roomCode: roomCode,
      providerId: providerId,
      engineId: rawEngineId == null || rawEngineId.isEmpty ? null : rawEngineId,
      roomMode: roomMode,
      attendeeCount: attendeeCount,
      createdAt: createdAt,
    );
  }
}
