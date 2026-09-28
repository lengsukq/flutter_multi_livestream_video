import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

class ProviderAdapters {
  ProviderAdapters({required Iterable<RealtimeProviderPlugin> plugins})
    : plugins = RealtimePluginRegistry(plugins);

  final RealtimePluginRegistry plugins;

  RealtimeMediaAdapters get media => plugins.media;
  ChatRegistry get chatRegistry => plugins.chat;
  MediaRegistry get registry => plugins.media.registry;
}
