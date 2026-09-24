import '../model/media_error.dart';
import '../model/media_role.dart';
import 'media_join_info.dart';
import 'media_session.dart';

/// Creates provider sessions and parses provider join payloads.
///
/// Each adapter package exports one factory, for example `LiveKitSessionFactory`
/// with `providerId == 'livekit'`, and registers it in a [MediaRegistry].
abstract class MediaSessionFactory {
  /// Provider id used by the backend contract (`provider` field).
  String get providerId;

  /// Roles this adapter can create sessions for.
  Set<MediaRole> get supportedRoles;

  /// Parses the backend join response into provider-neutral join information.
  ///
  /// Throws `MediaError` with `invalidJoinInfo` when required fields are
  /// missing.
  MediaJoinInfo parseJoinInfo(Map<String, dynamic> json);

  /// Creates the session matching `joinInfo.role`.
  ///
  /// Throws `MediaError` with `unsupportedFeature` for a role that
  /// [supportedRoles] does not contain.
  MediaSession createSession(MediaJoinInfo joinInfo);
}

/// Registry of provider adapters available to an application.
///
/// Registration is explicit: an app that only uses one provider never pulls in
/// another provider's SDK.
class MediaRegistry {
  MediaRegistry([Iterable<MediaSessionFactory> factories = const []]) {
    for (final factory in factories) {
      register(factory);
    }
  }

  /// Process-wide registry for apps that prefer not to thread an instance
  /// through their widget tree. Tests should create their own instance.
  static final MediaRegistry global = MediaRegistry();

  final Map<String, MediaSessionFactory> _factories = {};

  /// Registered provider ids in registration order.
  Iterable<String> get providerIds => _factories.keys;

  /// Registers [factory], replacing any previous adapter with the same id.
  void register(MediaSessionFactory factory) {
    final id = factory.providerId.trim().toLowerCase();
    if (id.isEmpty) {
      throw ArgumentError.value(
        factory.providerId,
        'factory.providerId',
        'Provider id must not be empty.',
      );
    }
    _factories[id] = factory;
  }

  /// Removes a provider. Returns whether anything was removed.
  bool unregister(String providerId) =>
      _factories.remove(providerId.trim().toLowerCase()) != null;

  /// Looks up a provider adapter, returning null when absent.
  MediaSessionFactory? lookup(String providerId) =>
      _factories[providerId.trim().toLowerCase()];

  /// Looks up a provider adapter or throws a typed error.
  MediaSessionFactory require(String providerId) {
    final factory = lookup(providerId);
    if (factory == null) {
      throw MediaError(
        code: MediaErrorCode.providerNotRegistered,
        message:
            'No media adapter is registered for provider "$providerId". '
            'Registered providers: ${providerIds.join(', ')}.',
        providerId: providerId,
      );
    }
    return factory;
  }
}
