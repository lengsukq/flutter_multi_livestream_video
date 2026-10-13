import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';

sealed class ClassroomCommandState {
  const ClassroomCommandState();
}

final class ClassroomCommandIdle extends ClassroomCommandState {
  const ClassroomCommandIdle();
}

final class ClassroomCommandPending extends ClassroomCommandState {
  const ClassroomCommandPending();
}

final class ClassroomCommandFailed extends ClassroomCommandState {
  const ClassroomCommandFailed(this.error);
  final RealtimeException error;
}

/// Presentation-only action state; the host owns and starts the domain session.
class ClassroomCommandPresenter {
  ClassroomCommandPresenter({required this.onChanged, required this.onError});
  final void Function() onChanged;
  final void Function(RealtimeException error) onError;
  ClassroomCommandState state = const ClassroomCommandIdle();
  bool _disposed = false;
  bool get pending => state is ClassroomCommandPending;
  Future<void> run(Future<void> Function() action) async {
    if (_disposed || pending) return;
    state = const ClassroomCommandPending();
    onChanged();
    try {
      await action();
      if (!_disposed) state = const ClassroomCommandIdle();
    } catch (error, stack) {
      final failure = normalizeRealtimeException(
        error,
        domain: 'classroom.ui',
        stackTrace: stack,
      );
      if (!_disposed) state = ClassroomCommandFailed(failure);
      // Failure still reaches the host when the originating widget has gone away.
      onError(failure);
    } finally {
      if (!_disposed) onChanged();
    }
  }

  void dispose() => _disposed = true;
}
