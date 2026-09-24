/// Role of the local participant inside a room.
///
/// The backend is responsible for issuing credentials that match the requested
/// role. A client-side role check is a convenience, not a security boundary:
/// a `viewer` token must not grant publish permission on the server side.
enum MediaRole {
  /// Symmetric real-time meeting participant (publish and subscribe).
  participant,

  /// One-to-many broadcast host (publish and subscribe).
  host,

  /// One-to-many broadcast viewer (subscribe only, no media publishing).
  viewer;

  /// Name used on the wire for the backend contract and adapter payloads.
  String get wireName => name;

  /// Whether this role may publish audio/video tracks.
  bool get canPublishMedia => this != MediaRole.viewer;

  /// Parses a wire value, returning null for unknown input.
  static MediaRole? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final role in MediaRole.values) {
      if (role.wireName == normalized) return role;
    }
    return null;
  }
}
