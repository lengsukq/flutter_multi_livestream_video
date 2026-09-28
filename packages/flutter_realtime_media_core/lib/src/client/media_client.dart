import '../diagnostics/media_permission_probe.dart';
import '../diagnostics/media_pre_join.dart';
import '../diagnostics/media_pre_join_runner.dart';
import '../model/media_error.dart';
import '../model/media_identity.dart';
import '../model/media_role.dart';
import '../model/media_room_mode.dart';
import '../model/media_room_summary.dart';
import '../session/media_join_info.dart';
import '../session/media_credential_refresh.dart';
import '../session/media_room_session.dart';
import '../session/media_session_factory.dart';
import 'media_backend_client.dart';
import 'media_backend_config.dart';
import 'media_backend_error.dart';
import 'media_backend_transport.dart';
import 'media_room_services.dart';

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
  /// Creates a frontend-only media client.
  ///
  /// This entry point does not require the repository Backend Contract. Use
  /// [join] with a [MediaJoinInfo] obtained from any trusted provisioning
  /// mechanism. Backend-oriented create/discovery helpers are unavailable.
  MediaClient.direct({
    MediaRegistry? registry,
    MediaPermissionProbe? permissionProbe,
    this.provisioner,
    this.discovery,
  }) : config = null,
       registry = registry ?? MediaRegistry.global,
       backend = null,
       permissionProbe = permissionProbe ?? const DefaultMediaPermissionProbe();

  MediaClient({
    required String backendUrl,
    MediaRegistry? registry,
    MediaTokenProvider? tokenProvider,
    MediaHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration heartbeatInterval = const Duration(seconds: 30),
    MediaBackendTransport? transport,
    MediaPermissionProbe? permissionProbe,
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
         permissionProbe: permissionProbe,
       );

  MediaClient.withConfig(
    MediaBackendConfig config, {
    MediaRegistry? registry,
    MediaBackendTransport? transport,
    MediaPermissionProbe? permissionProbe,
  }) : config = config,
       registry = registry ?? MediaRegistry.global,
       backend = MediaBackendClient(config, transport: transport),
       permissionProbe = permissionProbe ?? const DefaultMediaPermissionProbe(),
       provisioner = null,
       discovery = null;

  final MediaBackendConfig? config;
  final MediaRegistry registry;
  final MediaBackendClient? backend;
  final MediaPermissionProbe permissionProbe;
  final MediaRoomProvisioner? provisioner;
  final MediaRoomDiscovery? discovery;

  /// Joins provider media directly from already provisioned join information.
  ///
  /// This is the frontend SDK-first path. Core validates the registered adapter
  /// and role, then delegates to the provider client SDK without requiring the
  /// repository demo backend.
  Future<MediaRoomSession> join(MediaJoinInfo joinInfo) async {
    final factory = registry.require(joinInfo.providerId);
    if (!factory.supportedRoles.contains(joinInfo.role)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'The ${joinInfo.providerId} adapter does not support the '
            '${joinInfo.role.wireName} role.',
        providerId: joinInfo.providerId,
      );
    }
    final session = factory.createSession(joinInfo);
    try {
      await session.join(joinInfo);
      return MediaRoomSession.direct(
        roomCode: joinInfo.roomCode,
        participantId: joinInfo.participantId,
        session: session,
      );
    } catch (_) {
      await session.dispose();
      rethrow;
    }
  }

  /// Runs provider-neutral checks without creating or joining a room.
  Future<MediaPreJoinResult> runPreJoinCheck({
    MediaRole role = MediaRole.participant,
    String? providerId,
    String? roomCode,
    MediaPreJoinRequirements? requirements,
  }) {
    return MediaPreJoinRunner(
      backend: backend,
      registry: registry,
      permissionProbe: permissionProbe,
    ).run(
      MediaPreJoinRequest(
        role: role,
        providerId: providerId,
        roomCode: roomCode,
        requirements: requirements,
      ),
    );
  }

  /// Creates a room and joins it as [nickname].
  ///
  /// Provider selection belongs to the application backend. The backend
  /// returns the granted provider in the join response and this client then
  /// resolves the matching adapter from [registry].
  Future<MediaRoomSession> createRoomAndJoin({
    required String nickname,
    MediaRole role = MediaRole.participant,
    String? roomCode,
    String? deviceId,
  }) async {
    final response = await _requireBackend('create rooms').createRoom(
      role: role,
      roomCode: roomCode,
      nickname: nickname,
      deviceId: deviceId,
    );
    return _joinResponse(response);
  }

  String? _normalizedOptionalProvider(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  /// Returns rooms advertised by the backend for lightweight discovery.
  Future<List<MediaRoomSummary>> listRooms() =>
      (discovery ?? backend)?.listRooms() ??
      Future<List<MediaRoomSummary>>.error(
        const MediaError(
          code: MediaErrorCode.unsupportedFeature,
          message: 'Room discovery requires a MediaRoomDiscovery extension.',
        ),
      );

  Future<MediaRoomSession> joinRoomIdentity({
    required String roomCode,
    required MediaIdentity identity,
    String? roomOwnerCredential,
    MediaRole? role,
  }) async {
    final value = identity.normalized();
    final custom = provisioner;
    if (custom != null) {
      return _joinResponse(
        await custom.join(
          roomCode: roomCode,
          identity: value,
          role: role,
          roomOwnerCredential: roomOwnerCredential,
        ),
        credentialRefresher: custom,
      );
    }
    return _joinResponse(
      await _requireBackend(
        'provision room join credentials',
      ).joinRoomWithIdentity(
        role: role,
        roomCode: roomCode,
        userId: value.userId,
        displayName: value.displayName,
        deviceId: value.deviceId,
        roomOwnerCredential: roomOwnerCredential,
      ),
    );
  }

  Future<MediaRoomSession> createRoomAndJoinIdentity({
    required MediaIdentity identity,
    MediaRoomMode roomMode = MediaRoomMode.meeting,
    MediaRole? role,
    String? roomCode,
  }) async {
    final value = identity.normalized();
    final custom = provisioner;
    if (custom != null) {
      return _joinResponse(
        await custom.create(
          identity: value,
          roomMode: roomMode,
          role: role,
          roomCode: roomCode,
        ),
        credentialRefresher: custom,
      );
    }
    return _joinResponse(
      await _requireBackend('create rooms').createRoomWithIdentity(
        role: role,
        roomMode: roomMode,
        roomCode: roomCode,
        userId: value.userId,
        displayName: value.displayName,
        deviceId: value.deviceId,
      ),
    );
  }

  /// Joins an existing room as [nickname].
  ///
  /// The room code identifies the room; the backend owns the room-to-provider
  /// mapping and returns provider-specific join credentials.
  Future<MediaRoomSession> joinRoom({
    required String roomCode,
    required String nickname,
    MediaRole role = MediaRole.participant,
    String? deviceId,
    String? roomOwnerCredential,
  }) async {
    final response = await _requireBackend('provision room join credentials')
        .joinRoom(
          role: role,
          roomCode: roomCode,
          nickname: nickname,
          deviceId: deviceId,
          roomOwnerCredential: roomOwnerCredential,
        );
    return _joinResponse(response);
  }

  /// Closes the backend transport. Room sessions must be disposed first.
  void dispose() => backend?.dispose();

  MediaBackendClient _requireBackend(String operation) {
    final value = backend;
    if (value != null) return value;
    throw MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message:
          'Cannot $operation without a configured provisioning backend. '
          'Use MediaClient.join(MediaJoinInfo) for the frontend-only path.',
    );
  }

  Future<MediaRoomSession> _joinResponse(
    MediaRoomJoinResponse response, {
    MediaRoomProvisioner? credentialRefresher,
  }) async {
    final backend = this.backend;
    final factory = registry.require(response.providerId);
    if (!factory.supportedRoles.contains(response.role)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'The ${response.providerId} adapter does not support the '
            '${response.role.wireName} role.',
        providerId: response.providerId,
      );
    }

    final joinInfo = _parseJoinInfo(
      factory: factory,
      response: response,
      parseErrorMessage: 'Unable to parse backend join information.',
    );
    final participantCredential = response.json['participantCredential']
        ?.toString()
        .trim();
    final roomOwnerCredential = response.json['roomOwnerCredential']
        ?.toString()
        .trim();

    final session = factory.createSession(joinInfo);
    if (session case final MediaCredentialRefreshable refreshable) {
      Future<MediaJoinInfo>? refreshInFlight;
      refreshable.setCredentialRefreshCallback((currentJoinInfo) {
        final current = refreshInFlight;
        if (current != null) return current;
        late final Future<MediaJoinInfo> future;
        future =
            _refreshCredentials(
              factory: factory,
              currentJoinInfo: currentJoinInfo,
              participantCredential: participantCredential,
              provisioner: credentialRefresher,
            ).whenComplete(() {
              if (identical(refreshInFlight, future)) refreshInFlight = null;
            });
        refreshInFlight = future;
        return future;
      });
    }
    try {
      await session.join(joinInfo);
      if (backend == null) {
        return MediaRoomSession.direct(
          roomCode: response.roomCode,
          participantId: joinInfo.participantId,
          session: session,
        );
      }
      return MediaRoomSession.attach(
        roomCode: response.roomCode,
        participantId: joinInfo.participantId,
        participantCredential:
            participantCredential == null || participantCredential.isEmpty
            ? null
            : participantCredential,
        roomOwnerCredential:
            roomOwnerCredential == null || roomOwnerCredential.isEmpty
            ? null
            : roomOwnerCredential,
        chatProvider: _normalizedOptionalProvider(
          response.json['chatProvider'],
        ),
        backendMetadata: response.json,
        session: session,
        presence: backend,
        management: backend,
        heartbeatInterval:
            config?.heartbeatInterval ?? const Duration(seconds: 30),
      );
    } catch (_) {
      await session.dispose();
      try {
        await backend?.leave(
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

  Future<MediaJoinInfo> _refreshCredentials({
    required MediaSessionFactory factory,
    required MediaJoinInfo currentJoinInfo,
    String? participantCredential,
    MediaRoomProvisioner? provisioner,
  }) async {
    try {
      final response = provisioner != null
          ? await provisioner.refresh(
              roomCode: currentJoinInfo.roomCode,
              participantId: currentJoinInfo.participantId,
              role: currentJoinInfo.role,
              participantCredential: participantCredential,
            )
          : await _requireBackend(
              'refresh backend-issued credentials',
            ).refreshCredentials(
              roomCode: currentJoinInfo.roomCode,
              participantId: currentJoinInfo.participantId,
              role: currentJoinInfo.role,
              participantCredential: participantCredential,
            );
      final responseRole = response.json['role'];
      if (responseRole != null && MediaRole.tryParse(responseRole) == null) {
        throw MediaError(
          code: MediaErrorCode.invalidJoinInfo,
          message:
              'The backend returned an invalid role during credential refresh.',
          providerId: currentJoinInfo.providerId,
        );
      }
      final refreshed = _parseJoinInfo(
        factory: factory,
        response: response,
        parseErrorMessage: 'Unable to parse refreshed media credentials.',
      );
      if (response.providerId != currentJoinInfo.providerId ||
          response.roomCode != currentJoinInfo.roomCode ||
          response.role != currentJoinInfo.role ||
          refreshed.participantId != currentJoinInfo.participantId ||
          refreshed.providerId.trim().toLowerCase() !=
              currentJoinInfo.providerId) {
        throw MediaError(
          code: MediaErrorCode.invalidJoinInfo,
          message:
              'The backend changed the provider, room, participant, or role '
              'during credential refresh.',
          providerId: currentJoinInfo.providerId,
        );
      }
      return refreshed;
    } on MediaError {
      rethrow;
    } on MediaBackendError catch (error) {
      throw MediaError(
        code: MediaErrorCode.nativeError,
        message: 'Unable to refresh media credentials.',
        details: error,
        providerId: currentJoinInfo.providerId,
      );
    } catch (error) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Unable to parse refreshed media credentials.',
        details: error,
        providerId: currentJoinInfo.providerId,
      );
    }
  }

  MediaJoinInfo _parseJoinInfo({
    required MediaSessionFactory factory,
    required MediaRoomJoinResponse response,
    required String parseErrorMessage,
  }) {
    try {
      final adapterJson = Map<String, dynamic>.from(response.json)
        ..putIfAbsent('provider', () => response.providerId)
        ..putIfAbsent('role', () => response.role.wireName)
        ..putIfAbsent('roomCode', () => response.roomCode);
      final joinInfo = factory.parseJoinInfo(adapterJson);
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
      return joinInfo;
    } on MediaError {
      rethrow;
    } catch (error) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: parseErrorMessage,
        details: error,
        providerId: response.providerId,
      );
    }
  }
}

/// Whether the provider-neutral media client can run on this platform.
///
/// Provider adapters perform their own runtime capability checks before
/// creating a media session. Register only adapters that support the current
/// platform in the host application's media registry.
bool get isMediaPlatformSupported => true;
