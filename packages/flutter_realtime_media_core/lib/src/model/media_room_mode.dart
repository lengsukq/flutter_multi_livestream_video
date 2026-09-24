import 'media_role.dart';

/// Product-level room mode used by the backend to assign media roles.
enum MediaRoomMode {
  /// Symmetric meeting: every attendee joins as [MediaRole.participant].
  meeting,

  /// One-to-many broadcast: creator is [MediaRole.host], other devices are
  /// [MediaRole.viewer]. The backend remains authoritative for this mapping.
  broadcast;

  String get wireName => name;
}
