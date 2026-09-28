import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Stable metadata that applications may use for diagnostics or provider
/// pickers without importing a vendor SDK.
class RealtimeProviderMetadata {
  const RealtimeProviderMetadata({required this.displayName, this.description});

  final String displayName;
  final String? description;
}

class RealtimeAdapterNotRegisteredError extends StateError {
  RealtimeAdapterNotRegisteredError(this.providerId, super.message);

  final String providerId;
}

Map<String, RealtimeMediaAdapter> _validatedAdapters(
  Iterable<RealtimeMediaAdapter> adapters,
) {
  final result = <String, RealtimeMediaAdapter>{};
  for (final adapter in adapters) {
    final id = adapter.providerId;
    if (id.isEmpty) {
      throw ArgumentError.value(
        adapter.sessionFactory.providerId,
        'adapter.sessionFactory.providerId',
        'Realtime provider id must not be empty.',
      );
    }
    if (result.containsKey(id)) {
      throw ArgumentError('Duplicate realtime media provider "$id".');
    }
    result[id] = adapter;
  }
  return result;
}

/// Complete media adapter registration used by the high-level SDK.
///
/// Keeping the session factory and renderer together prevents applications
/// from maintaining two provider maps that can drift out of sync.
class RealtimeMediaAdapter {
  const RealtimeMediaAdapter({
    required this.sessionFactory,
    required this.renderer,
    this.metadata,
  });

  final MediaSessionFactory sessionFactory;
  final MediaTrackRenderer renderer;
  final RealtimeProviderMetadata? metadata;

  String get providerId => sessionFactory.providerId.trim().toLowerCase();
}

class RealtimeMediaAdapters {
  RealtimeMediaAdapters(Iterable<RealtimeMediaAdapter> adapters)
    : this._(_validatedAdapters(adapters));

  RealtimeMediaAdapters._(Map<String, RealtimeMediaAdapter> adapters)
    : _adapters = adapters,
      registry = MediaRegistry(
        adapters.values.map((adapter) => adapter.sessionFactory),
      );

  final Map<String, RealtimeMediaAdapter> _adapters;
  final MediaRegistry registry;

  Iterable<String> get providerIds => _adapters.keys;

  RealtimeMediaAdapter? lookup(String providerId) =>
      _adapters[providerId.trim().toLowerCase()];

  RealtimeMediaAdapter require(String providerId) {
    final adapter = lookup(providerId);
    if (adapter == null) {
      throw RealtimeAdapterNotRegisteredError(
        providerId,
        'No complete media adapter is registered for provider "$providerId". '
        'Registered providers: ${providerIds.join(', ')}.',
      );
    }
    return adapter;
  }
}
