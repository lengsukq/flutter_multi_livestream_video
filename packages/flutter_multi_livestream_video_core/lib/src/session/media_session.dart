import '../model/media_capabilities.dart';
import '../model/media_event.dart';
import '../model/media_role.dart';
import '../model/media_snapshot.dart';
import '../model/media_state.dart';
import 'media_join_info.dart';

/// Connection and lifecycle surface shared by every provider adapter.
///
/// Implementations own exactly one connection attempt at a time. `join`,
/// `leave`, and `dispose` are idempotent or fail with a typed `MediaError`
/// (`invalidState`) — never with a provider-specific exception.
abstract class MediaSession {
  /// Registered provider id, for example `livekit`.
  String get providerId;

  /// Role this session was created for.
  MediaRole get role;

  /// Declared feature set for this session.
  MediaCapabilities get capabilities;

  /// Current lifecycle state.
  MediaSessionState get state;

  /// Latest immutable snapshot.
  MediaSnapshot get snapshot;

  /// Emits state changes. Read [state] for the current value when subscribing
  /// late; this is a broadcast stream and does not replay.
  Stream<MediaSessionState> get states;

  /// Emits a new snapshot whenever session data changes.
  Stream<MediaSnapshot> get snapshots;

  /// Emits typed session events.
  Stream<MediaEvent> get events;

  /// Connects using short-lived information issued by the application backend.
  Future<void> join(MediaJoinInfo joinInfo);

  /// Leaves the session. Safe to call when already idle or ended.
  Future<void> leave();

  /// Releases stream resources. Safe to call more than once.
  Future<void> dispose();
}
