import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_adapter.dart';

/// Self-describing provider extension point for the application-facing SDK.
///
/// A plugin may expose media, product chat, or both. Backend room responses
/// remain authoritative about which registered provider is actually used.
class RealtimeProviderPlugin {
  const RealtimeProviderPlugin({
    required this.id,
    required this.metadata,
    this.mediaFactory,
    this.renderer,
    this.chatFactory,
  }) : assert(
         (mediaFactory == null) == (renderer == null),
         'A media factory and renderer must be registered together.',
       );

  final String id;
  final RealtimeProviderMetadata metadata;
  final MediaSessionFactory? mediaFactory;
  final MediaTrackRenderer? renderer;
  final ChatSessionFactory? chatFactory;

  String get providerId => id.trim().toLowerCase();

  RealtimeMediaAdapter? get mediaAdapter {
    final factory = mediaFactory;
    final trackRenderer = renderer;
    if (factory == null || trackRenderer == null) return null;
    return RealtimeMediaAdapter(
      sessionFactory: factory,
      renderer: trackRenderer,
      metadata: metadata,
    );
  }
}

/// Validated plugin set used to build the underlying media/chat registries.
class RealtimePluginRegistry {
  RealtimePluginRegistry(Iterable<RealtimeProviderPlugin> plugins)
    : _plugins = _validate(plugins) {
    final mediaAdapters = <RealtimeMediaAdapter>[];
    final chatFactories = <ChatSessionFactory>[];
    for (final plugin in _plugins.values) {
      final media = plugin.mediaAdapter;
      if (media != null) mediaAdapters.add(media);
      final chat = plugin.chatFactory;
      if (chat != null) chatFactories.add(chat);
    }
    media = RealtimeMediaAdapters(mediaAdapters);
    chat = ChatRegistry(chatFactories);
  }

  final Map<String, RealtimeProviderPlugin> _plugins;
  late final RealtimeMediaAdapters media;
  late final ChatRegistry chat;

  Iterable<String> get providerIds => _plugins.keys;

  RealtimeProviderPlugin? lookup(String providerId) =>
      _plugins[providerId.trim().toLowerCase()];

  RealtimeProviderPlugin require(String providerId) {
    final plugin = lookup(providerId);
    if (plugin == null) {
      throw StateError(
        'No realtime plugin is registered for provider "$providerId". '
        'Registered providers: ${providerIds.join(', ')}.',
      );
    }
    return plugin;
  }

  static Map<String, RealtimeProviderPlugin> _validate(
    Iterable<RealtimeProviderPlugin> plugins,
  ) {
    final result = <String, RealtimeProviderPlugin>{};
    for (final plugin in plugins) {
      final id = plugin.providerId;
      if (id.isEmpty) {
        throw ArgumentError.value(
          plugin.id,
          'plugin.id',
          'Realtime provider id must not be empty.',
        );
      }
      if ((plugin.mediaFactory == null) != (plugin.renderer == null)) {
        throw ArgumentError(
          'Realtime provider "$id" must register its media factory and '
          'renderer together.',
        );
      }
      if (plugin.mediaFactory == null && plugin.chatFactory == null) {
        throw ArgumentError(
          'Realtime provider "$id" must expose media, chat, or both.',
        );
      }
      if (plugin.mediaFactory != null &&
          plugin.mediaFactory!.providerId.trim().toLowerCase() != id) {
        throw ArgumentError(
          'Media factory provider "${plugin.mediaFactory!.providerId}" does '
          'not match plugin "$id".',
        );
      }
      if (plugin.chatFactory != null &&
          plugin.chatFactory!.providerId.trim().toLowerCase() != id) {
        throw ArgumentError(
          'Chat factory provider "${plugin.chatFactory!.providerId}" does '
          'not match plugin "$id".',
        );
      }
      if (result.containsKey(id)) {
        throw ArgumentError('Duplicate realtime provider plugin "$id".');
      }
      result[id] = plugin;
    }
    return result;
  }
}
