import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'provider_plugin.dart';
import 'provider_web_assets.dart';

const _productChatWebProviders = {'agora-chat', 'ivs-chat'};

/// Defers bundled Web runtime loading until a provider operation needs it.
///
/// The wrappers preserve optional pre-join interfaces implemented by each
/// factory and load any bundled Web runtime before invoking them.
List<RealtimeProviderPlugin> wrapWebProviderPlugins(
  Iterable<RealtimeProviderPlugin> plugins,
  RealtimeProviderWebAssetsLoader loader,
) => [
  for (final plugin in plugins)
    RealtimeProviderPlugin(
      id: plugin.id,
      metadata: plugin.metadata,
      mediaFactory: plugin.mediaFactory == null
          ? null
          : _wrapWebAssetsMediaFactory(plugin.mediaFactory!, loader),
      renderer: plugin.renderer,
      chatFactory: plugin.chatFactory == null
          ? null
          : _WebAssetsChatFactory(plugin.chatFactory!, loader),
    ),
];

MediaSessionFactory _wrapWebAssetsMediaFactory(
  MediaSessionFactory delegate,
  RealtimeProviderWebAssetsLoader loader,
) {
  if (delegate is MediaPreJoinProbe && delegate is MediaLocalPreviewFactory) {
    return _WebAssetsMediaFactoryWithPreJoinAndPreview(delegate, loader);
  }
  if (delegate is MediaPreJoinProbe) {
    return _WebAssetsMediaFactoryWithPreJoinProbe(delegate, loader);
  }
  if (delegate is MediaLocalPreviewFactory) {
    return _WebAssetsMediaFactoryWithLocalPreview(delegate, loader);
  }
  return _WebAssetsMediaFactory(delegate, loader);
}

class _WebAssetsMediaFactory
    implements MediaSessionFactory, MediaSessionPreparer {
  const _WebAssetsMediaFactory(this.delegate, this.loader);

  final MediaSessionFactory delegate;
  final RealtimeProviderWebAssetsLoader loader;

  @override
  String get providerId => delegate.providerId;

  @override
  Set<MediaRole> get supportedRoles => delegate.supportedRoles;

  @override
  MediaJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      delegate.parseJoinInfo(json);

  @override
  Future<void> prepareSession(MediaJoinInfo joinInfo) async {
    if (delegate case final MediaSessionPreparer preparer) {
      await preparer.prepareSession(joinInfo);
    }
    await _loadProviderAssets();
  }

  Future<void> _loadProviderAssets() => loader(
    mediaProviderIds: [providerId],
    includeProductChat: false,
    includeAllMediaProviders: false,
  );

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) =>
      delegate.createSession(joinInfo);
}

class _WebAssetsMediaFactoryWithPreJoinProbe extends _WebAssetsMediaFactory
    implements MediaPreJoinProbe {
  const _WebAssetsMediaFactoryWithPreJoinProbe(super.delegate, super.loader);

  @override
  Future<MediaPreJoinProbeResult> runPreJoinProbe(
    MediaPreJoinProbeRequest request,
  ) async {
    await _loadProviderAssets();
    return (delegate as MediaPreJoinProbe).runPreJoinProbe(request);
  }
}

class _WebAssetsMediaFactoryWithLocalPreview extends _WebAssetsMediaFactory
    implements MediaLocalPreviewFactory {
  const _WebAssetsMediaFactoryWithLocalPreview(super.delegate, super.loader);

  @override
  Future<MediaLocalPreviewSession> createLocalPreview({
    required MediaRole role,
  }) async {
    await _loadProviderAssets();
    return (delegate as MediaLocalPreviewFactory).createLocalPreview(
      role: role,
    );
  }
}

class _WebAssetsMediaFactoryWithPreJoinAndPreview extends _WebAssetsMediaFactory
    implements MediaPreJoinProbe, MediaLocalPreviewFactory {
  const _WebAssetsMediaFactoryWithPreJoinAndPreview(
    super.delegate,
    super.loader,
  );

  @override
  Future<MediaPreJoinProbeResult> runPreJoinProbe(
    MediaPreJoinProbeRequest request,
  ) async {
    await _loadProviderAssets();
    return (delegate as MediaPreJoinProbe).runPreJoinProbe(request);
  }

  @override
  Future<MediaLocalPreviewSession> createLocalPreview({
    required MediaRole role,
  }) async {
    await _loadProviderAssets();
    return (delegate as MediaLocalPreviewFactory).createLocalPreview(
      role: role,
    );
  }
}

class _WebAssetsChatFactory implements ChatSessionFactory, ChatSessionPreparer {
  const _WebAssetsChatFactory(this.delegate, this.loader);

  final ChatSessionFactory delegate;
  final RealtimeProviderWebAssetsLoader loader;

  @override
  String get providerId => delegate.providerId;

  @override
  ChatJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      delegate.parseJoinInfo(json);

  @override
  Future<void> prepareSession(ChatJoinInfo joinInfo) async {
    if (delegate case final ChatSessionPreparer preparer) {
      await preparer.prepareSession(joinInfo);
    }
    await loader(
      includeProductChat: _productChatWebProviders.contains(providerId),
      includeAllMediaProviders: false,
    );
  }

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) =>
      delegate.createSession(joinInfo);
}
