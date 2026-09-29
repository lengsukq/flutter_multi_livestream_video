// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_adapter.dart';
import 'provider_plugin.dart';
import 'runtime_platform.dart';

/// One provider implementation that is valid on one or more runtime platforms.
///
/// A driver may expose media, product chat, or both. The application-facing
/// SDK selects the driver for the current platform before building the Core
/// registries, so applications never need platform branches.
class RealtimeProviderDriver {
  const RealtimeProviderDriver({
    required this.plugin,
    required this.platforms,
    this.publicProviderId,
    this.mediaRoomModes = const {},
  });

  final RealtimeProviderPlugin plugin;
  final Set<RealtimeRuntimePlatform> platforms;
  final String? publicProviderId;
  final Set<MediaRoomMode> mediaRoomModes;

  String get providerId => plugin.providerId;
  String get publicId =>
      (publicProviderId ?? plugin.providerId).trim().toLowerCase();
  bool supports(RealtimeRuntimePlatform platform) =>
      platforms.contains(platform);

  bool supportsRoomMode(MediaRoomMode? mode) =>
      mode == null || mediaRoomModes.isEmpty || mediaRoomModes.contains(mode);
}

/// Platform-aware driver catalog used by the default SDK entry point.
class RealtimeDriverRegistry {
  RealtimeDriverRegistry(
    Iterable<RealtimeProviderDriver> drivers, {
    RealtimePlatformResolver platformResolver = resolveRealtimeRuntimePlatform,
  }) : _drivers = List.unmodifiable(drivers),
       _platformResolver = platformResolver;

  final List<RealtimeProviderDriver> _drivers;
  final RealtimePlatformResolver _platformResolver;
  final Map<String, RealtimeRuntimePlatform> _applicationOverrides = {};

  RealtimeRuntimePlatform get platform => _platformResolver();

  Iterable<RealtimeProviderDriver> get drivers => _drivers;

  Iterable<String> get knownProviderIds => {
    ..._drivers.map((driver) => driver.publicId),
    ..._applicationOverrides.keys,
  };

  Iterable<String> get knownEngineIds =>
      _drivers.map((driver) => driver.providerId).toSet();

  Iterable<String> supportedProviderIds([
    RealtimeRuntimePlatform? targetPlatform,
  ]) {
    final target = targetPlatform ?? platform;
    return {
      ..._drivers
          .where((driver) => driver.supports(target))
          .map((driver) => driver.publicId)
          .toSet(),
      ..._applicationOverrides.entries
          .where((entry) => entry.value == target)
          .map((entry) => entry.key),
    };
  }

  bool knowsProvider(String providerId) {
    final id = providerId.trim().toLowerCase();
    return _applicationOverrides.containsKey(id) ||
        _drivers.any(
          (driver) => driver.publicId == id || driver.providerId == id,
        );
  }

  bool supportsProvider(
    String providerId, [
    RealtimeRuntimePlatform? targetPlatform,
  ]) {
    final id = providerId.trim().toLowerCase();
    final target = targetPlatform ?? platform;
    return _applicationOverrides[id] == target ||
        _drivers.any(
          (driver) =>
              (driver.publicId == id || driver.providerId == id) &&
              driver.supports(target),
        );
  }

  String publicProviderForEngine(String engineId) {
    final id = engineId.trim().toLowerCase();
    for (final driver in _drivers) {
      if (driver.providerId == id) return driver.publicId;
    }
    return id;
  }

  String resolveMediaEngine({
    required String providerId,
    String? engineId,
    MediaRoomMode? roomMode,
  }) {
    final requested = providerId.trim().toLowerCase();
    final explicitEngine = engineId?.trim().toLowerCase();
    final mediaDrivers = _drivers
        .where((driver) => driver.plugin.mediaFactory != null)
        .toList(growable: false);

    final legacy = mediaDrivers.where(
      (driver) => driver.providerId == requested,
    );
    if (legacy.isNotEmpty) {
      final driver = legacy.first;
      if (explicitEngine != null &&
          explicitEngine.isNotEmpty &&
          explicitEngine != driver.providerId) {
        throw ArgumentError(
          'Provider "$requested" cannot use engine "$explicitEngine".',
        );
      }
      if (!driver.supportsRoomMode(roomMode)) {
        throw ArgumentError(
          'Engine "${driver.providerId}" does not support room mode '
          '"${roomMode?.wireName}".',
        );
      }
      return driver.providerId;
    }

    final candidates = mediaDrivers
        .where((driver) => driver.publicId == requested)
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw ArgumentError('Unknown media provider "$requested".');
    }

    if (explicitEngine != null && explicitEngine.isNotEmpty) {
      final matches = candidates.where(
        (driver) =>
            driver.providerId == explicitEngine &&
            driver.supportsRoomMode(roomMode),
      );
      if (matches.isEmpty) {
        throw ArgumentError(
          'Provider "$requested" cannot use engine "$explicitEngine".',
        );
      }
      return matches.first.providerId;
    }

    final modeMatches = candidates
        .where((driver) => driver.supportsRoomMode(roomMode))
        .toList(growable: false);
    if (modeMatches.length == 1) return modeMatches.single.providerId;
    if (candidates.length == 1 && roomMode == null) {
      return candidates.single.providerId;
    }
    throw ArgumentError(
      'Provider "$requested" requires an engine or roomMode to select a '
      'media implementation.',
    );
  }

  /// Builds the ordinary provider plugin list used by the existing SDK.
  ///
  /// Known providers without a driver for the current platform are represented
  /// by typed unsupported factories. This lets backend-selected rooms fail as
  /// unsupportedPlatform instead of being misreported as unregistered.
  List<RealtimeProviderPlugin> resolvePlugins({
    Iterable<RealtimeProviderPlugin> additionalPlugins = const [],
  }) {
    _applicationOverrides.clear();
    final target = platform;
    final grouped = <String, _PluginParts>{};

    for (final driver in _drivers.where((driver) => driver.supports(target))) {
      grouped
          .putIfAbsent(driver.providerId, () => _PluginParts())
          .add(driver.plugin);
    }

    final known = <String, _KnownKinds>{};
    for (final driver in _drivers) {
      final kinds = known.putIfAbsent(driver.providerId, () => _KnownKinds());
      kinds.media = kinds.media || driver.plugin.mediaFactory != null;
      kinds.chat = kinds.chat || driver.plugin.chatFactory != null;
      kinds.metadata ??= driver.plugin.metadata;
    }

    for (final entry in known.entries) {
      final parts = grouped.putIfAbsent(entry.key, () => _PluginParts());
      final kinds = entry.value;
      parts.metadata ??= kinds.metadata;
      if (kinds.media && parts.mediaFactory == null) {
        parts.mediaFactory = _UnsupportedMediaFactory(
          providerId: entry.key,
          platform: target,
        );
        parts.renderer = const _UnsupportedMediaRenderer();
      }
      if (kinds.chat && parts.chatFactory == null) {
        parts.chatFactory = _UnsupportedChatFactory(
          providerId: entry.key,
          platform: target,
        );
      }
    }

    // Explicit application plugins override the built-in driver for the same
    // provider. This preserves the existing advanced customization path.
    for (final plugin in additionalPlugins) {
      grouped[plugin.providerId] = _PluginParts.fromPlugin(plugin);
      _applicationOverrides[plugin.providerId] = target;
    }

    return grouped.entries
        .map(
          (entry) => entry.value.toPlugin(
            entry.key,
            fallbackMetadata: const RealtimeProviderMetadata(
              displayName: 'Realtime provider',
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _KnownKinds {
  bool media = false;
  bool chat = false;
  RealtimeProviderMetadata? metadata;
}

class _PluginParts {
  _PluginParts();

  _PluginParts.fromPlugin(RealtimeProviderPlugin plugin)
    : metadata = plugin.metadata,
      mediaFactory = plugin.mediaFactory,
      renderer = plugin.renderer,
      chatFactory = plugin.chatFactory;

  RealtimeProviderMetadata? metadata;
  MediaSessionFactory? mediaFactory;
  MediaTrackRenderer? renderer;
  ChatSessionFactory? chatFactory;

  void add(RealtimeProviderPlugin plugin) {
    metadata ??= plugin.metadata;
    if (plugin.mediaFactory != null) {
      if (mediaFactory != null) {
        throw ArgumentError(
          'Multiple media drivers are registered for provider '
          '"${plugin.providerId}" on the same platform.',
        );
      }
      mediaFactory = plugin.mediaFactory;
      renderer = plugin.renderer;
    }
    if (plugin.chatFactory != null) {
      if (chatFactory != null) {
        throw ArgumentError(
          'Multiple chat drivers are registered for provider '
          '"${plugin.providerId}" on the same platform.',
        );
      }
      chatFactory = plugin.chatFactory;
    }
  }

  RealtimeProviderPlugin toPlugin(
    String providerId, {
    required RealtimeProviderMetadata fallbackMetadata,
  }) => RealtimeProviderPlugin(
    id: providerId,
    metadata: metadata ?? fallbackMetadata,
    mediaFactory: mediaFactory,
    renderer: renderer,
    chatFactory: chatFactory,
  );
}

class _UnsupportedMediaFactory implements MediaSessionFactory {
  const _UnsupportedMediaFactory({
    required this.providerId,
    required this.platform,
  });

  @override
  final String providerId;
  final RealtimeRuntimePlatform platform;

  @override
  Set<MediaRole> get supportedRoles => MediaRole.values.toSet();

  Never _unsupported() => throw MediaError(
    code: MediaErrorCode.unsupportedPlatform,
    message:
        'Provider "$providerId" does not have a media driver for '
        '${platform.name}.',
    providerId: providerId,
    details: {'platform': platform.name},
  );

  @override
  MediaJoinInfo parseJoinInfo(Map<String, dynamic> json) => _unsupported();

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) => _unsupported();
}

class _UnsupportedMediaRenderer extends MediaTrackRenderer {
  const _UnsupportedMediaRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _UnsupportedChatFactory implements ChatSessionFactory {
  const _UnsupportedChatFactory({
    required this.providerId,
    required this.platform,
  });

  @override
  final String providerId;
  final RealtimeRuntimePlatform platform;

  Never _unsupported() => throw ChatError(
    code: ChatErrorCode.unsupportedPlatform,
    message:
        'Provider "$providerId" does not have a chat driver for '
        '${platform.name}.',
    providerId: providerId,
    details: {'platform': platform.name},
  );

  @override
  ChatJoinInfo parseJoinInfo(Map<String, dynamic> json) => _unsupported();

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) => _unsupported();
}
