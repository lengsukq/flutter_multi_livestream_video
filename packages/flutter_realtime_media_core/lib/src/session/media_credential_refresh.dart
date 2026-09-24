import 'media_join_info.dart';

/// Callback used by adapters when their short-lived credentials expire.
///
/// The callback returns fresh credentials for the same provider session. The
/// Core client validates that the backend did not change the room or identity.
typedef MediaCredentialRefreshCallback =
    Future<MediaJoinInfo> Function(MediaJoinInfo currentJoinInfo);

/// Optional capability implemented by sessions whose provider credentials can
/// expire while a room is active.
///
/// Adapters that do not implement this interface keep their existing behavior.
abstract interface class MediaCredentialRefreshable {
  /// Installs or clears the provider-neutral credential renewal callback.
  void setCredentialRefreshCallback(MediaCredentialRefreshCallback? callback);
}
