import 'dart:convert';

/// Provider-neutral invalidation hint. Privileged mutations are NEVER applied
/// from realtime data: receiving this only triggers a trusted state refresh.
class ClassroomRevisionEvent {
  const ClassroomRevisionEvent({
    required this.roomCode,
    required this.revision,
    required this.eventId,
    required this.timestampMs,
    this.eventType = 'classroom.state.changed',
  });
  static const int version = 1;
  final String roomCode;
  final String eventType;
  final int revision;
  final String eventId;
  final int timestampMs;

  String encode() => jsonEncode({
    'v': version,
    'type': eventType,
    'roomCode': roomCode,
    'revision': revision,
    'eventId': eventId,
    'timestampMs': timestampMs,
  });

  static ClassroomRevisionEvent? decode(
    String raw, {
    required String expectedRoomCode,
    required int nowMs,
    String expectedType = 'classroom.state.changed',
    Duration maxAge = const Duration(minutes: 5),
  }) {
    if (raw.length > 1024 || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != version ||
          decoded['type'] != expectedType ||
          decoded['roomCode'] != expectedRoomCode ||
          decoded['revision'] is! int ||
          decoded['eventId'] is! String ||
          decoded['timestampMs'] is! int) {
        return null;
      }
      final revision = decoded['revision'] as int;
      final eventId = decoded['eventId'] as String;
      final timestamp = decoded['timestampMs'] as int;
      if (revision < 0 ||
          eventId.isEmpty ||
          eventId.length > 128 ||
          (nowMs - timestamp).abs() > maxAge.inMilliseconds) {
        return null;
      }
      return ClassroomRevisionEvent(
        roomCode: expectedRoomCode,
        revision: revision,
        eventType: expectedType,
        eventId: eventId,
        timestampMs: timestamp,
      );
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
