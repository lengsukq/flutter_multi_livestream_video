// ignore_for_file: prefer_initializing_formals

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'default_driver_catalog.dart';
import 'provider_driver.dart';
import 'provider_plugin.dart';
import 'provider_web_assets.dart';
import 'provider_web_session_wrapper.dart';
import 'realtime_client.dart';
import 'realtime_error.dart';
import 'realtime_room.dart';
import 'realtime_chat_room.dart';
import 'runtime_platform.dart';

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
    this.driverRegistry,
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) : plugins = RealtimePluginRegistry(
         _pluginsForRuntime(
           plugins,
           platform:
               driverRegistry?.platform ?? resolveRealtimeRuntimePlatform(),
           webAssetsLoader: webAssetsLoader ?? ensureRealtimeProviderWebAssets,
         ),
       ),
       _tokenProvider = tokenProvider,
       _clientFactory = clientFactory;

  /// Creates the batteries-included SDK.
  ///
  /// Built-in providers are selected by provider id and runtime platform
  /// inside the SDK. Applications may still override or extend providers with
  /// [additionalPlugins], without writing Web/iOS/Android/Desktop branches.
  factory RealtimeSdk.standard({
    String? backendUrl,
    RealtimeTokenProvider? tokenProvider,
    RealtimeClientFactory? clientFactory,
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
    Iterable<RealtimeProviderPlugin> additionalPlugins = const [],
    Iterable<RealtimeProviderDriver>? drivers,
    RealtimeProviderWebAssetsLoader? webAssetsLoader,
  }) {
    final registry = RealtimeDriverRegistry(
      drivers ?? createDefaultRealtimeDrivers(),
      platformResolver: platformResolver,
    );
    return RealtimeSdk(
      backendUrl: backendUrl,
      plugins: registry.resolvePlugins(additionalPlugins: additionalPlugins),
      tokenProvider: tokenProvider,
      clientFactory: clientFactory,
      driverRegistry: registry,
      webAssetsLoader: webAssetsLoader,
    );
  }

  void _validateDeclaredMediaProvider(
    Object? declared, {
    required String requestedProvider,
    required String engineProvider,
  }) {
    final value = declared?.toString().trim().toLowerCase();
    if (value == null ||
        value.isEmpty ||
        value == requestedProvider ||
        value == engineProvider) {
      return;
    }
    final publicProvider =
        driverRegistry?.publicProviderForEngine(engineProvider) ??
        engineProvider;
    if (value == publicProvider) return;
    throw RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message:
          'Credential field "provider" declares provider "$value", '
          'but "$requestedProvider" was requested.',
      providerId: requestedProvider,
    );
  }

  MediaRoomMode? _parseRoomMode(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'meeting' => MediaRoomMode.meeting,
      'broadcast' || 'live' => MediaRoomMode.broadcast,
      null || '' => null,
      _ => throw ArgumentError('Unsupported roomMode "$normalized".'),
    };
  }

  final String? backendUrl;
  final RealtimePluginRegistry plugins;
  final RealtimeDriverRegistry? driverRegistry;
  final RealtimeTokenProvider? _tokenProvider;
  final RealtimeClientFactory? _clientFactory;
  RealtimeRuntimePlatform get platform =>
      driverRegistry?.platform ?? resolveRealtimeRuntimePlatform();

  Iterable<String> get supportedProviderIds =>
      driverRegistry?.supportedProviderIds() ?? plugins.providerIds;

  bool supportsProvider(String providerId) =>
      driverRegistry?.supportsProvider(providerId) ??
      plugins.lookup(providerId) != null;

  RealtimeClient createClient() =>
      _clientFactory?.call() ??
      RealtimeClient(
        backendUrl: backendUrl,
        mediaAdapters: plugins.media,
        chatRegistry: plugins.chat,
        tokenProvider: _tokenProvider,
        publicProviderResolver: driverRegistry?.publicProviderForEngine,
      );

  /// Lists backend-provisioned rooms without exposing a lower-level client.
  Future<List<MediaRoomSummary>> listRooms() => _guard(() async {
    final client = createClient().newMediaClient();
    try {
      return await client.listRooms();
    } finally {
      client.dispose();
    }
  });

  /// Checks backend reachability and whether its active provider is available
  /// on this SDK's runtime platform.
  Future<MediaDoctorReport> diagnoseBackend() => _guard(() async {
    final client = createClient().newMediaClient();
    try {
      final backend = client.backend;
      if (backend == null) {
        throw const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Backend diagnostics require a configured backend URL.',
          suggestedAction: 'configure-backend',
        );
      }
      final report = await MediaDoctor.check(
        backend: backend,
        registry: client.registry,
      );
      return _applyPlatformSupportToDoctorReport(report);
    } finally {
      client.dispose();
    }
  });

  /// Parses raw provider media credentials through the selected SDK driver.
  ///
  /// Applications can keep provider credential JSON opaque and avoid
  /// importing provider-specific JoinInfo classes. The payload shape remains
  /// provider-defined; only platform selection and parsing are centralized.
  MediaJoinInfo parseMediaCredentials({
    required String providerId,
    required Map<String, dynamic> joinPayload,
  }) {
    final normalizedProvider = providerId.trim().toLowerCase();
    try {
      final json = Map<String, dynamic>.from(joinPayload);
      final roomMode = _parseRoomMode(json['roomMode']);
      final registry = driverRegistry;
      final engineProvider =
          registry?.resolveMediaEngine(
            providerId: normalizedProvider,
            engineId: json['engine']?.toString(),
            roomMode: roomMode,
          ) ??
          normalizedProvider;
      _assertPlatformSupport(engineProvider);
      _validateDeclaredMediaProvider(
        json['provider'],
        requestedProvider: normalizedProvider,
        engineProvider: engineProvider,
      );
      json['provider'] = engineProvider;
      json['engine'] = engineProvider;
      return plugins.media.registry.require(engineProvider).parseJoinInfo(json);
    } on ArgumentError catch (error) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: error.message?.toString() ?? error.toString(),
        providerId: normalizedProvider,
        details: error,
      );
    } catch (error) {
      throw mapRealtimeException(error, providerId: normalizedProvider);
    }
  }

  /// Parses raw Product Chat credentials through the selected SDK driver.
  ChatJoinInfo parseChatCredentials({
    required String providerId,
    required Map<String, dynamic> joinPayload,
  }) {
    final normalizedProvider = providerId.trim().toLowerCase();
    _assertPlatformSupport(normalizedProvider);
    try {
      final json = Map<String, dynamic>.from(joinPayload);
      _validateDeclaredProvider(
        json['chatProvider'],
        normalizedProvider,
        field: 'chatProvider',
      );
      json['chatProvider'] = normalizedProvider;
      return plugins.chat.require(normalizedProvider).parseJoinInfo(json);
    } catch (error) {
      throw mapRealtimeException(error, providerId: normalizedProvider);
    }
  }

  /// Direct media join using raw provider credential JSON.
  ///
  /// Media and Product Chat providers remain independent. When Product Chat is
  /// supplied, both [chatProviderId] and [chatJoinPayload] are required.
  Future<RealtimeRoom> joinWithCredentials({
    required String mediaProviderId,
    required Map<String, dynamic> mediaJoinPayload,
    String? chatProviderId,
    Map<String, dynamic>? chatJoinPayload,
    ChatCredentialProvider? chatCredentialProvider,
  }) {
    final normalizedChatProvider = chatProviderId?.trim();
    if ((normalizedChatProvider == null || normalizedChatProvider.isEmpty) !=
        (chatJoinPayload == null)) {
      return Future.error(
        const RealtimeException(
          code: RealtimeErrorCode.invalidArgument,
          message:
              'chatProviderId and chatJoinPayload must be supplied together.',
        ),
      );
    }

    final media = parseMediaCredentials(
      providerId: mediaProviderId,
      joinPayload: mediaJoinPayload,
    );
    final chat = chatJoinPayload == null
        ? null
        : parseChatCredentials(
            providerId: normalizedChatProvider!,
            joinPayload: chatJoinPayload,
          );
    return joinDirect(
      media,
      chatJoinInfo: chat,
      chatCredentialProvider: chatCredentialProvider,
    );
  }

  /// Direct Product Chat connection using raw provider credential JSON.
  Future<RealtimeChatRoom> connectChatWithCredentials({
    required String providerId,
    required Map<String, dynamic> joinPayload,
    ChatCredentialProvider? credentialProvider,
  }) => connectChatDirect(
    parseChatCredentials(providerId: providerId, joinPayload: joinPayload),
    credentialProvider: credentialProvider,
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
      final requestedProvider = providerId?.trim().toLowerCase();
      var coreProvider = requestedProvider;
      final registry = driverRegistry;
      if (registry != null &&
          coreProvider != null &&
          coreProvider.isNotEmpty &&
          client.registry.lookup(coreProvider) == null &&
          registry.knowsProvider(coreProvider)) {
        coreProvider = registry.resolveMediaEngine(
          providerId: coreProvider,
          roomMode: role == MediaRole.participant
              ? MediaRoomMode.meeting
              : MediaRoomMode.broadcast,
        );
      }
      var result = await client.runPreJoinCheck(
        role: role,
        providerId: coreProvider,
        roomCode: roomCode,
        requirements: requirements,
      );
      final publicProvider =
          requestedProvider ??
          (result.providerId == null
              ? null
              : registry?.publicProviderForEngine(result.providerId!) ??
                    result.providerId);
      if (publicProvider != null && publicProvider != result.providerId) {
        result = MediaPreJoinResult(
          role: result.role,
          providerId: publicProvider,
          checks: result.checks,
        );
      }
      return _applyPlatformSupportToPreJoin(result);
    } finally {
      client.dispose();
    }
  });

  Future<RealtimeRoom> createRoom({
    required MediaIdentity user,
    MediaRoomMode mode = MediaRoomMode.meeting,
    MediaRole? role,
    String? roomCode,
  }) => _guard(() async {
    return createClient().createRoomAndJoinIdentity(
      identity: user,
      roomMode: mode,
      role: role,
      roomCode: roomCode,
    );
  });

  Future<RealtimeChatRoom> connectChatDirect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) => _guard(() async {
    _assertPlatformSupport(joinInfo.providerId);
    return createClient().connectChatDirect(
      joinInfo,
      credentialProvider: credentialProvider,
    );
  });

  Future<RealtimeChatRoom> createChatRoom({
    required StandaloneChatProvisioner provisioner,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) => _guard(() async {
    return createClient().createChatRoom(
      provisioner: provisioner,
      userId: userId,
      displayName: displayName,
      role: role,
      roomCode: roomCode,
    );
  });

  Future<RealtimeChatRoom> joinChatRoom({
    required StandaloneChatProvisioner provisioner,
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  }) => _guard(() async {
    return createClient().joinChatRoom(
      provisioner: provisioner,
      roomCode: roomCode,
      userId: userId,
      displayName: displayName,
      role: role,
    );
  });

  /// Joins directly from provider-neutral media join information.
  ///
  /// The host application owns provisioning. This path does not require the
  /// repository Backend Contract or demo-server.
  Future<RealtimeRoom> joinDirect(
    MediaJoinInfo joinInfo, {
    ChatJoinInfo? chatJoinInfo,
    ChatCredentialProvider? chatCredentialProvider,
  }) => _guard(() async {
    _assertPlatformSupport(joinInfo.providerId);
    final productChat = chatJoinInfo;
    if (productChat != null) {
      _assertPlatformSupport(productChat.providerId);
    }
    return createClient().joinDirect(
      joinInfo,
      chatJoinInfo: chatJoinInfo,
      chatCredentialProvider: chatCredentialProvider,
    );
  });

  /// Adopts a room joined through the advanced client, for example after a
  /// custom Pre-Join flow, while still applying facade error semantics.
  Future<RealtimeRoom> adopt(MediaClient client, MediaRoomSession room) =>
      _guard(() async {
        _assertPlatformSupport(room.providerId);
        final chatProvider = room.chatProvider;
        if (chatProvider != null) _assertPlatformSupport(chatProvider);
        return createClient().adopt(client, room);
      });

  Future<RealtimeRoom> joinRoom({
    required String roomCode,
    required MediaIdentity user,
    String? roomOwnerCredential,
    MediaRole? role,
  }) => _guard(() async {
    return createClient().joinRoomIdentity(
      roomCode: roomCode,
      identity: user,
      roomOwnerCredential: roomOwnerCredential,
      role: role,
    );
  });

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw mapRealtimeException(error);
    }
  }

  void _assertPlatformSupport(String providerId) {
    final registry = driverRegistry;
    if (registry == null ||
        !registry.knowsProvider(providerId) ||
        registry.supportsProvider(providerId)) {
      return;
    }
    throw RealtimeException(
      code: RealtimeErrorCode.unsupportedPlatform,
      message:
          'Provider "$providerId" is not available on '
          '${registry.platform.name}.',
      providerId: providerId,
      suggestedAction: 'choose-supported-provider',
      details: {'platform': registry.platform.name},
    );
  }

  void _validateDeclaredProvider(
    Object? declared,
    String expected, {
    required String field,
  }) {
    final value = declared?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty || value == expected) return;
    throw RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message:
          'Credential field "$field" declares provider "$value", '
          'but "$expected" was requested.',
      providerId: expected,
    );
  }

  MediaPreJoinResult _applyPlatformSupportToPreJoin(MediaPreJoinResult result) {
    final registry = driverRegistry;
    final providerId = result.providerId;
    if (registry == null ||
        providerId == null ||
        !registry.knowsProvider(providerId) ||
        registry.supportsProvider(providerId)) {
      return result;
    }

    final platformCheck = MediaPreJoinCheck(
      type: MediaPreJoinCheckType.provider,
      status: MediaPreJoinStatus.unsupported,
      severity: MediaPreJoinSeverity.blocking,
      message:
          'Provider "$providerId" has no driver for '
          '${registry.platform.name}.',
      details: {'platform': registry.platform.name},
    );
    final checks = <MediaPreJoinCheck>[];
    var replaced = false;
    for (final check in result.checks) {
      if (check.type == MediaPreJoinCheckType.provider && !replaced) {
        checks.add(platformCheck);
        replaced = true;
      } else {
        checks.add(check);
      }
    }
    if (!replaced) checks.add(platformCheck);
    return MediaPreJoinResult(
      role: result.role,
      providerId: providerId,
      checks: List.unmodifiable(checks),
    );
  }

  MediaDoctorReport _applyPlatformSupportToDoctorReport(
    MediaDoctorReport report,
  ) {
    final registry = driverRegistry;
    final providerId = report.activeProvider;
    if (registry == null || providerId == null) {
      return report;
    }

    final known = registry.knowsProvider(providerId);
    final supported = known && registry.supportsProvider(providerId);

    final checks = report.checks
        .map((check) {
          if (check.id == 'providers') {
            return MediaDoctorCheck(
              id: check.id,
              status: registry.supportedProviderIds().isEmpty
                  ? MediaDoctorStatus.fail
                  : MediaDoctorStatus.pass,
              message:
                  'Registered public providers: '
                  '${registry.supportedProviderIds().join(', ')}.',
            );
          }
          if (check.id != 'active-provider') return check;
          if (supported) {
            return MediaDoctorCheck(
              id: check.id,
              status: MediaDoctorStatus.pass,
              message:
                  'Backend active provider $providerId is available on '
                  '${registry.platform.name}.',
            );
          }
          if (!known) return check;
          return MediaDoctorCheck(
            id: check.id,
            status: MediaDoctorStatus.fail,
            message:
                'Backend active provider $providerId has no driver for '
                '${registry.platform.name}.',
          );
        })
        .toList(growable: false);
    return MediaDoctorReport(
      List.unmodifiable(checks),
      activeProvider: report.activeProvider,
      activeChatProvider: report.activeChatProvider,
      backendReachable: report.backendReachable,
    );
  }
}

Iterable<RealtimeProviderPlugin> _pluginsForRuntime(
  Iterable<RealtimeProviderPlugin> plugins, {
  required RealtimeRuntimePlatform platform,
  required RealtimeProviderWebAssetsLoader webAssetsLoader,
}) => platform == RealtimeRuntimePlatform.web
    ? wrapWebProviderPlugins(plugins, webAssetsLoader)
    : plugins;
