import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'classroom_role.dart';

class ClassroomStudent {
  const ClassroomStudent({
    required this.userId,
    required this.participantId,
    required this.displayName,
    required this.online,
    required this.handRaised,
    required this.canSpeak,
    this.role = ClassroomRole.student,
    this.microphoneOn,
    this.cameraOn,
    this.avatarUrl,
  });
  final String userId, participantId, displayName;
  final String? avatarUrl;
  final bool online, handRaised, canSpeak;
  final ClassroomRole role;
  // Null means the provider has not supplied media telemetry.
  final bool? microphoneOn, cameraOn;
  ClassroomStudent withMedia({bool? microphoneOn, bool? cameraOn}) =>
      ClassroomStudent(
        userId: userId,
        participantId: participantId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        online: online,
        handRaised: handRaised,
        canSpeak: canSpeak,
        role: role,
        microphoneOn: microphoneOn ?? this.microphoneOn,
        cameraOn: cameraOn ?? this.cameraOn,
      );
  factory ClassroomStudent.fromJson(Map<String, dynamic> data) =>
      JsonReader(data).decode(() => ClassroomStudent._fromJsonUnchecked(data));
  factory ClassroomStudent._fromJsonUnchecked(Map<String, dynamic> data) =>
      ClassroomStudent(
        userId: JsonReader(data).required<String>('userId'),
        participantId: JsonReader(data).required<String>('participantId'),
        displayName: JsonReader(data).optional<String>('displayName') ?? '',
        avatarUrl: JsonReader(data).optional<String>('avatarUrl'),
        online: JsonReader(data).optional<bool>('online') ?? false,
        handRaised: JsonReader(data).optional<bool>('handRaised') ?? false,
        canSpeak: JsonReader(data).optional<bool>('canSpeak') ?? false,
        role: data['role'] == null
            ? ClassroomRole.student
            : JsonReader(data).enumValue('role', ClassroomRole.values),
      );
}
