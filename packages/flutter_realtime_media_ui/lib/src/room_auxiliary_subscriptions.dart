import 'dart:async';

/// Owns legacy room UI event subscriptions without owning the media session.
///
/// Rebinding invalidates queued events from the previous stream. Disposing a
/// room widget cancels listeners, never the provider-owned event sources.
class RoomAuxiliarySubscriptions {
  StreamSubscription<Object?>? _content;
  StreamSubscription<Object?>? _permission;
  int _contentEpoch = 0;
  int _permissionEpoch = 0;
  bool _disposed = false;

  void bindContent(
    Stream<Object?>? updates, {
    required void Function() invalidate,
  }) {
    if (_disposed) return;
    final epoch = ++_contentEpoch;
    unawaited(_content?.cancel());
    _content = updates?.listen((_) {
      if (!_disposed && epoch == _contentEpoch) invalidate();
    });
  }

  void bindMicrophone(
    Stream<Object?>? updates, {
    required void Function() onPermissionChanged,
  }) {
    if (_disposed) return;
    final epoch = ++_permissionEpoch;
    unawaited(_permission?.cancel());
    _permission = updates?.listen((_) {
      if (!_disposed && epoch == _permissionEpoch) onPermissionChanged();
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_contentEpoch;
    ++_permissionEpoch;
    unawaited(_content?.cancel());
    unawaited(_permission?.cancel());
    _content = null;
    _permission = null;
  }
}
