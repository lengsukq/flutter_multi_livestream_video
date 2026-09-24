import 'package:flutter/foundation.dart';

import '../model/media_error.dart';
import '../model/media_role.dart';
import '../session/media_join_info.dart';
import '../session/media_room_session.dart';
import '../session/media_session_factory.dart';
import 'media_backend_client.dart';
import 'media_backend_config.dart';
import 'media_backend_error.dart';
import 'media_backend_transport.dart';

/// High-level client for applications whose backend implements the media
/// backend contract.
///
/// It resolves the provider adapter from a [MediaRegistry], parses the provider
/// join payload, joins the media session, and keeps backend presence alive for
/// the duration of the room session.
///
/// Keep this client alive until every [MediaRoomSession] created from it has
/// been disposed: those sessions use its transport for heartbeat and leave.
class MediaClient {
  MediaClient({
    required String backendUrl,
    MediaRegistry? registry,
    MediaTokenProvider? tokenProvider,
    MediaHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration heartbeatInterval = const Duration(seconds: 30),
    MediaBackendTransport? transport,
  }) : this.withConfig(
         MediaBackendConfig.fromUrl(
           backendUrl,
           tokenProvider: tokenProvider,
           headersProvider: headersProvider,
           requestTimeout: requestTimeout,
           heartbeatInterval: heartbeatInterval,
         ),
         registry: registry,
         transport: transport,
       );

  MediaClient.withConfig(
    this.config, {
    MediaRegistry? registry,
    MediaBackendTransport? transport,
  }) : registry = registry ?? MediaRegistry.global,
       backend = MediaBackendClient(config, transport: transport);

  final MediaBackendConfig config;
  final MediaRegistry registry;
  final MediaBackendClient backend;

  /// Creates a room and joins it as [nickname].
  ///
  /// Provider selection belongs to the application backend. The backend
  /// returns the granted provider in the join response and this client then
  /// resolves the matching adapter from [registry].
  Future<MediaRoomSession> createRoomAndJoin({
    required String nickname,
    MediaRole role = MediaRole.participant,
    String? roomCode,
  }) async {
    final response = await backend.createRoom(
      role: role,
      roomCode: roomCode,
      nickname: nickname,
    );
    return _joinResponse(response);
  }

  /// Joins an existing room as [nickname].
  ///
  /// The room code identifies the room; the backend owns the room-to-provider
  /// mapping and returns provider-specific join credentials.
  Future<MediaRoomSession> joinRoom({
    required String roomCode,
    required String nickname,
    MediaRole role = MediaRole.participant,
  }) async {
    final response = await backend.joinRoom(
      role: role,
      roomCode: roomCode,
      nickname: nickname,
    );
    return _joinResponse(response);
  }

  /// Closes the backend transport. Room sessions must be disposed first.
  void dispose() => backend.dispose();

  Future<MediaRoomSession> _joinResponse(MediaRoomJoinResponse response) async {
    final factory = registry.require(response.providerId);
    if (!factory.isPlatformSupported) {
      throw MediaError(
        code: MediaErrorCode.unsupportedPlatform,
        message:
            'The ${response.providerId} adapter is not available on this '
            'platform.',
        providerId: response.providerId,
      );
    }
    if (!factory.supportedRoles.contains(response.role)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'The ${response.providerId} adapter does not support the '
            '${response.role.wireName} role.',
        providerId: response.providerId,
      );
    }

    final MediaJoinInfo joinInfo;
    try {
      final adapterJson = Map<String, dynamic>.from(response.json)
        ..putIfAbsent('provider', () => response.providerId)
        ..putIfAbsent('role', () => response.role.wireName)
        ..putIfAbsent('roomCode', () => response.roomCode);
      joinInfo = factory.parseJoinInfo(adapterJson);
      if (joinInfo.providerId.trim().toLowerCase() != response.providerId ||
          joinInfo.role != response.role ||
          joinInfo.roomCode != response.roomCode) {
        throw MediaError(
          code: MediaErrorCode.invalidJoinInfo,
          message:
              'The provider adapter returned join information that does not '
              'match the backend response.',
          providerId: response.providerId,
        );
      }
    } on MediaError {
      rethrow;
    } catch (error) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Unable to parse backend join information.',
        details: error,
        providerId: response.providerId,
      );
    }

    final session = factory.createSession(joinInfo);
    try {
      await session.join(joinInfo);
      return MediaRoomSession.attach(
        roomCode: response.roomCode,
        participantId: joinInfo.participantId,
        session: session,
        backend: backend,
        heartbeatInterval: config.heartbeatInterval,
      );
    } catch (_) {
      await session.dispose();
      try {
        await backend.leave(
          response.roomCode,
          participantId: joinInfo.participantId,
        );
      } on MediaBackendError {
        // The media-join failure is the primary error; backend cleanup is
        // best effort and must not replace it.
      }
      rethrow;
    }
  }
}

/// Whether the current platform can run device media sessions.
bool get isMediaPlatformSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
