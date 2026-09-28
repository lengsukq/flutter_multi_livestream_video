// ignore_for_file: prefer_initializing_formals

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'provider_plugin.dart';
import 'realtime_client.dart';
import 'realtime_error.dart';
import 'realtime_room.dart';
import 'realtime_chat_room.dart';

typedef RealtimeClientFactory = RealtimeClient Function();

/// Lowest-cognitive-load application entry point.
///
/// Backend-selected rooms are supported, but a backend is not required for
/// direct joins provisioned by the host application.
class RealtimeSdk {
  RealtimeSdk({
    this.backendUrl,
    required Iterable<RealtimeProviderPlugin> plugins,
    RealtimeTokenProvider? tokenProvider,
    RealtimeClientFactory? clientFactory,
  }) : plugins = RealtimePluginRegistry(plugins),
       _tokenProvider = tokenProvider,
       _clientFactory = clientFactory;

  final String? backendUrl;
  final RealtimePluginRegistry plugins;
  final RealtimeTokenProvider? _tokenProvider;
  final RealtimeClientFactory? _clientFactory;

  RealtimeClient createClient() =>
      _clientFactory?.call() ??
      RealtimeClient(
        backendUrl: backendUrl,
        mediaAdapters: plugins.media,
        chatRegistry: plugins.chat,
        tokenProvider: _tokenProvider,
      );

  /// Runs the provider-neutral pre-join diagnostics through the high-level SDK.
  ///
  /// The temporary lower-level client is owned and disposed by this call.
  Future<MediaPreJoinResult> preJoin({
    MediaRole role = MediaRole.participant,
    String? providerId,
    String? roomCode,
    MediaPreJoinRequirements? requirements,
  }) => _guard(() async {
    final client = createClient().newMediaClient();
    try {
      return await client.runPreJoinCheck(
        role: role,
        providerId: providerId,
        roomCode: roomCode,
        requirements: requirements,
      );
    } finally {
      client.dispose();
    }
  });

  Future<RealtimeRoom> createRoom({
    required MediaIdentity user,
    MediaRoomMode mode = MediaRoomMode.meeting,
    MediaRole? role,
    String? roomCode,
  }) => _guard(
    () => createClient().createRoomAndJoinIdentity(
      identity: user,
      roomMode: mode,
      role: role,
      roomCode: roomCode,
    ),
  );

  Future<RealtimeChatRoom> connectChatDirect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) => _guard(
    () => createClient().connectChatDirect(
      joinInfo,
      credentialProvider: credentialProvider,
    ),
  );

  Future<RealtimeChatRoom> createChatRoom({
    required StandaloneChatProvisioner provisioner,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) => _guard(
    () => createClient().createChatRoom(
      provisioner: provisioner,
      userId: userId,
      displayName: displayName,
      role: role,
      roomCode: roomCode,
    ),
  );

  Future<RealtimeChatRoom> joinChatRoom({
    required StandaloneChatProvisioner provisioner,
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  }) => _guard(
    () => createClient().joinChatRoom(
      provisioner: provisioner,
      roomCode: roomCode,
      userId: userId,
      displayName: displayName,
      role: role,
    ),
  );

  /// Joins directly from provider-neutral media join information.
  ///
  /// The host application owns provisioning. This path does not require the
  /// repository Backend Contract or demo-server.
  Future<RealtimeRoom> joinDirect(
    MediaJoinInfo joinInfo, {
    ChatJoinInfo? chatJoinInfo,
    ChatCredentialProvider? chatCredentialProvider,
  }) => _guard(
    () => createClient().joinDirect(
      joinInfo,
      chatJoinInfo: chatJoinInfo,
      chatCredentialProvider: chatCredentialProvider,
    ),
  );

  /// Adopts a room joined through the advanced client, for example after a
  /// custom Pre-Join flow, while still applying facade error semantics.
  Future<RealtimeRoom> adopt(MediaClient client, MediaRoomSession room) =>
      _guard(() => createClient().adopt(client, room));

  Future<RealtimeRoom> joinRoom({
    required String roomCode,
    required MediaIdentity user,
    String? roomOwnerCredential,
    MediaRole? role,
  }) => _guard(
    () => createClient().joinRoomIdentity(
      roomCode: roomCode,
      identity: user,
      roomOwnerCredential: roomOwnerCredential,
      role: role,
    ),
  );

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw mapRealtimeException(error);
    }
  }
}
