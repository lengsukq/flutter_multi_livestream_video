import 'dart:async';
import 'failure.dart';

/// Explicit diagnostic ownership for callbacks that cannot await an operation.
void observeDetached<T>(
  Future<T>? operation, {
  void Function(RealtimeException)? onFailure,
}) {
  if (operation == null) return;
  final zone = Zone.current;
  unawaited(
    operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        final failure = normalizeRealtimeException(error, stackTrace: stack);
        if (onFailure != null) {
          onFailure(failure);
        } else {
          zone.handleUncaughtError(failure, stack);
        }
      },
    ),
  );
}
