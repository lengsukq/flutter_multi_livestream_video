import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'provider_adapters_model.dart';

ProviderAdapters createProviderAdapters() => ProviderAdapters(
  registry: MediaRegistry(),
  renderers: const {},
  chatRegistry: ChatRegistry(),
);
