import 'package:flutter/foundation.dart';

import '../models/chime_exception.dart';
import '../models/chime_meeting_session.dart';
import '../models/chime_room_session.dart';
import 'chime_backend_client.dart';
import 'chime_backend_transport.dart';
import 'chime_client_config.dart';

/// High-level convenience client for applications using the standard backend
/// contract. Existing applications may continue to use
/// `ChimeMeetingSession.join(JoinInfo)` directly instead.
///
/// Keep this client alive until all [ChimeRoomSession] values created from it
/// have been disposed, because those room sessions use its backend transport
/// for heartbeat and leave notifications.
class ChimeClient {
  ChimeClient({
    required String backendUrl,
    ChimeTokenProvider? tokenProvider,
    ChimeHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration heartbeatInterval = const Duration(seconds: 30),
    ChimeBackendTransport? transport,
  }) : this.withConfig(
         ChimeClientConfig.fromUrl(
           backendUrl,
           tokenProvider: tokenProvider,
           headersProvider: headersProvider,
           requestTimeout: requestTimeout,
           heartbeatInterval: heartbeatInterval,
         ),
         transport: transport,
       );

  ChimeClient.withConfig(
    this.config, {
    ChimeBackendTransport? transport,
  }) : backend = ChimeBackendClient(config, transport: transport);

  final ChimeClientConfig config;
  final ChimeBackendClient backend;

  Future<ChimeRoomSession> createRoomAndJoin({
    String? roomCode,
    required String nickname,
  }) async {
    _ensureMediaPlatformSupported();
    final response = await backend.createRoom(
      roomCode: roomCode,
      nickname: nickname,
    );
    return _joinResponse(response);
  }

  Future<ChimeRoomSession> joinRoom({
    required String roomCode,
    required String nickname,
  }) async {
    _ensureMediaPlatformSupported();
    final response = await backend.joinRoom(
      roomCode: roomCode,
      nickname: nickname,
    );
    return _joinResponse(response);
  }

  void dispose() => backend.dispose();

  void _ensureMediaPlatformSupported() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      throw const ChimeException(
        code: ChimeErrorCode.unsupportedPlatform,
        message: 'AWS Chime meetings are supported on iOS and Android only.',
      );
    }
  }

  Future<ChimeRoomSession> _joinResponse(
    ChimeRoomJoinResponse response,
  ) async {
    final session = ChimeMeetingSession();
    try {
      await session.join(response.joinInfo);
      return ChimeRoomSession.attach(
        roomCode: response.roomCode,
        attendeeId: response.joinInfo.attendee.attendeeId,
        session: session,
        backend: backend,
        heartbeatInterval: config.heartbeatInterval,
      );
    } catch (_) {
      await session.dispose();
      try {
        await backend.leave(
          response.roomCode,
          attendeeId: response.joinInfo.attendee.attendeeId,
        );
      } catch (_) {
        // The media-join error is the primary failure. Backend leave is
        // best-effort cleanup and must not replace it.
      }
      rethrow;
    }
  }
}
