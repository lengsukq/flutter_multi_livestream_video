import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

class ClassroomAttendance {
  const ClassroomAttendance({
    required this.userId,
    required this.displayName,
    required this.online,
    required this.onlineDuration,
    this.firstJoinedAt,
    this.lastJoinedAt,
    this.lastLeftAt,
    this.avatarUrl,
  });
  final String userId, displayName;
  final String? avatarUrl;
  final bool online;
  final Duration onlineDuration;
  final DateTime? firstJoinedAt, lastJoinedAt, lastLeftAt;
  factory ClassroomAttendance.fromJson(Map<String, dynamic> value) =>
      JsonReader(
        value,
      ).decode(() => ClassroomAttendance._fromJsonUnchecked(value));
  factory ClassroomAttendance._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomAttendance(
        userId: JsonReader(value).required<String>('userId'),
        displayName: JsonReader(value).required<String>('displayName'),
        avatarUrl: JsonReader(value).optional<String>('avatarUrl'),
        online: JsonReader(value).required<bool>('online'),
        onlineDuration: Duration(
          milliseconds:
              JsonReader(value).optional<int>('onlineMilliseconds') ?? 0,
        ),
        firstJoinedAt: JsonReader(value).optionalDateTime('firstJoinedAt'),
        lastJoinedAt: JsonReader(value).optionalDateTime('lastJoinedAt'),
        lastLeftAt: JsonReader(value).optionalDateTime('lastLeftAt'),
      );
}
