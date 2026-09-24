import '../model/media_error.dart';
import '../model/media_role.dart';

/// Provider-specific join information returned by the application backend.
///
/// The core layer only understands the provider id, room code, participant id,
/// and role. Everything a provider SDK needs (URLs, tokens, media placement)
/// travels inside [payload] and is parsed by the matching adapter.
class MediaJoinInfo {
  MediaJoinInfo({
    required this.providerId,
    required this.roomCode,
    required this.participantId,
    required this.role,
    this.displayName = '',
    Map<String, Object?> payload = const {},
  }) : payload = Map.unmodifiable(payload);

  /// Registered provider id, for example `livekit` or `chime`.
  final String providerId;

  /// Application-level room code shared by all participants.
  final String roomCode;

  /// Participant identity expected by the provider.
  final String participantId;

  /// Role the backend issued credentials for.
  final MediaRole role;

  /// Display name to publish to other participants, when supported.
  final String displayName;

  /// Provider payload, passed through to the adapter untouched.
  final Map<String, Object?> payload;

  /// Reads a required non-empty string from [payload].
  ///
  /// Throws [MediaError] with `invalidJoinInfo` so adapters do not need their
  /// own validation error plumbing.
  String requirePayloadString(String key) {
    return requireStringIn(payload, key, providerId: providerId);
  }

  /// Reads an optional string from [payload], returning null when absent.
  String? optionalPayloadString(String key) {
    final value = payload[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Reads a required non-empty string from a raw backend JSON object.
  ///
  /// Shared by adapters so every provider reports missing fields the same way.
  static String requireStringIn(
    Map<String, Object?> json,
    String key, {
    required String providerId,
  }) {
    final value = json[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information is missing "$key".',
        providerId: providerId,
      );
    }
    return value;
  }

  @override
  String toString() =>
      'MediaJoinInfo($providerId, room: $roomCode, participant: '
      '$participantId, role: ${role.wireName})';
}
