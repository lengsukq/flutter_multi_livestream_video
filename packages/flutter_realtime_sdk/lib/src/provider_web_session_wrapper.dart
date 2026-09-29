import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'provider_plugin.dart';
import 'provider_web_assets.dart';

const _productChatWebProviders = {'agora-chat', 'ivs-chat'};

/// Defers bundled Web runtime loading until the resolved provider connects.
///
/// The factories retain the original session objects and their optional
/// provider interfaces. They only add setup immediately before session
/// creation, after backend routing has selected the provider.
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
          : _WebAssetsMediaFactory(plugin.mediaFactory!, loader),
      renderer: plugin.renderer,
      chatFactory: plugin.chatFactory == null
          ? null
          : _WebAssetsChatFactory(plugin.chatFactory!, loader),
    ),
];

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
    await loader(
      mediaProviderIds: [providerId],
      includeProductChat: false,
      includeAllMediaProviders: false,
    );
  }

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) =>
      delegate.createSession(joinInfo);
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
