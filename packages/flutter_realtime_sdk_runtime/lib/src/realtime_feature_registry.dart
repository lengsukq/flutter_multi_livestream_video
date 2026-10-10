import 'dart:async';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_interaction_core/flutter_realtime_interaction_core.dart';

/// The optional feature boundary. Plugins can use media/chat and the neutral
/// Interaction API without depending on SDK UI or a particular product flow.
class RealtimeFeatureContext {
  const RealtimeFeatureContext({
    required this.media,
    required this.interactions,
    this.chat,
    this.backendUrl,
    this.tokenProvider,
    this.requestTimeout,
    this.reportError,
  });

  final MediaRoomSession media;
  final ChatSession? chat;
  final InteractionSession Function() interactions;

  /// Optional backend authority used by opt-in feature repositories.
  final String? backendUrl;
  final Future<String?> Function()? tokenProvider;
  final Duration? requestTimeout;

  /// Reports optional feature failures into the room's diagnostic channel.
  final void Function(Object error, StackTrace stack)? reportError;

  String get roomCode => media.roomCode;
  String get participantId => media.participantId;
  String get providerId => media.providerId;
}

/// Prebuilt classroom/live features and app-defined extensions implement the
/// same room-scoped lifecycle. Nothing is instantiated unless registered.
abstract interface class RealtimeFeaturePlugin {
  String get id;

  /// Return null when a room is not eligible; it will not appear in [activeIds].
  FutureOr<Object?> attach(RealtimeFeatureContext context);
  FutureOr<void> detach(Object feature);
}

/// Optional start lifecycle for business sessions that load a trusted snapshot
/// after they have attached to a room. Normal custom features may omit it.
abstract interface class RealtimeStartingFeaturePlugin {
  Future<void> start(Object feature);
}

class _AttachedFeature {
  const _AttachedFeature(this.plugin, this.value);
  final RealtimeFeaturePlugin plugin;
  final Object value;
}

/// A feature failure is reported without preventing unrelated features from
/// attaching. Disposal is idempotent and runs in reverse registration order.
class RealtimeFeatureRegistry {
  RealtimeFeatureRegistry(
    Iterable<RealtimeFeaturePlugin> plugins, {
    this.onError,
  }) : _plugins = List.unmodifiable(plugins) {
    final ids = <String>{};
    for (final plugin in _plugins) {
      if (plugin.id.trim().isEmpty || !ids.add(plugin.id)) {
        throw ArgumentError.value(
          plugin.id,
          'plugins',
          'Duplicate/empty feature ID',
        );
      }
    }
  }

  Future<void> _startOnce(RealtimeFeaturePlugin plugin, Object feature) =>
      _starts.putIfAbsent(plugin.id, () => _start(plugin, feature));

  /// Starts attached optional business sessions. A failure is isolated from
  /// other feature sessions and passed through [onError].
  Future<void> startAttached() async {
    _startRequested = true;
    final operations = <Future<void>>[];
    for (final plugin in _plugins) {
      if (_disposed) break;
      final feature = _attached[plugin.id]?.value;
      if (feature == null || plugin is! RealtimeStartingFeaturePlugin) continue;
      operations.add(_startOnce(plugin, feature));
    }
    await Future.wait(operations);
  }

  Future<void> _start(RealtimeFeaturePlugin plugin, Object feature) async {
    try {
      await (plugin as RealtimeStartingFeaturePlugin).start(feature);
    } catch (error, stack) {
      if (!_disposed) onError?.call(plugin.id, error, stack);
    }
  }

  final List<RealtimeFeaturePlugin> _plugins;
  final void Function(String featureId, Object error, StackTrace stack)?
  onError;
  final _attached = <String, _AttachedFeature>{};
  Future<void>? _initialization;
  Future<void>? _disposal;
  bool _startRequested = false;
  final _starts = <String, Future<void>>{};
  bool _disposed = false;

  Iterable<String> get registeredIds => _plugins.map((plugin) => plugin.id);
  Iterable<String> get activeIds => _attached.keys;

  T? get<T extends Object>(String id) {
    final value = _attached[id]?.value;
    return value is T ? value : null;
  }

  bool contains(String id) => _attached.containsKey(id);

  Future<void> initialize(RealtimeFeatureContext context) {
    if (_disposed) throw StateError('Feature registry was disposed');
    return _initialization ??= _initialize(context);
  }

  Future<void> _initialize(RealtimeFeatureContext context) async {
    final pending = <Future<void>>[];
    for (final plugin in _plugins) {
      if (_disposed) break;
      try {
        // Sync presets become visible immediately, even if a plugin before
        // them is still attaching. Slow extensions cannot serialize startup.
        final result = plugin.attach(context);
        if (result is Future<Object?>) {
          pending.add(_attachPending(plugin, result));
        } else {
          final Object? instance = result;
          if (instance == null) continue;
          if (_disposed) {
            pending.add(_detach(plugin, instance));
          } else {
            _attached[plugin.id] = _AttachedFeature(plugin, instance);
          }
        }
      } catch (error, stack) {
        onError?.call(plugin.id, error, stack);
      }
    }
    await Future.wait(pending);
  }

  Future<void> _attachPending(
    RealtimeFeaturePlugin plugin,
    Future<Object?> future,
  ) async {
    try {
      final instance = await future;
      if (instance == null) return;
      if (_disposed) {
        await _detach(plugin, instance);
      } else {
        _attached[plugin.id] = _AttachedFeature(plugin, instance);
        if (_startRequested && plugin is RealtimeStartingFeaturePlugin) {
          await _startOnce(plugin, instance);
        }
      }
    } catch (error, stack) {
      onError?.call(plugin.id, error, stack);
    }
  }

  Future<void> _detach(RealtimeFeaturePlugin plugin, Object instance) async {
    try {
      await plugin.detach(instance);
    } catch (error, stack) {
      onError?.call(plugin.id, error, stack);
    }
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    // Always release in reverse *registration* order, not async completion
    // order, so dependency teardown remains deterministic.
    for (final plugin in _plugins.reversed) {
      final entry = _attached.remove(plugin.id);
      if (entry != null) await _detach(plugin, entry.value);
    }
    // An in-flight attach checks _disposed and detaches itself upon completion.
    // Do not wait for a potentially stalled backend request.
  }
}
