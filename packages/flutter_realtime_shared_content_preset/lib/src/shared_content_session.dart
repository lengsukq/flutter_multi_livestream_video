import 'dart:async';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'shared_content_repository.dart';
import 'shared_content_command.dart';

/// Owns shared-content synchronization without a teaching session.
class SharedContentSession implements AnnotationController {
  SharedContentSession(
    this.repository, {
    this.pollInterval = const Duration(seconds: 2),
    this.onError,
  });
  final SharedContentRepository repository;
  final Duration? pollInterval;
  final void Function(Object error, StackTrace stack)? onError;
  final _states = StreamController<SharedContentState?>.broadcast();
  final _errors = StreamController<RealtimeException>.broadcast();
  final _actions = <Future<SharedContentState?>>{};
  RealtimeException? _lastError;
  RealtimeException? get lastError => _lastError;
  Stream<RealtimeException> get errors => _errors.stream;
  void _reportFailure(Object error, StackTrace stack) {
    if (_disposed) return;
    final failure = normalizeRealtimeException(
      error,
      domain: 'sharedContent',
      operation: 'synchronize',
      stackTrace: stack,
    );
    _lastError = failure;
    _errors.add(failure);
    onError?.call(failure, stack);
  }

  StreamSubscription<SharedContentState?>? _subscription;
  Timer? _poll;
  SharedContentState? _state;
  bool _disposed = false;
  Future<void>? _refresh, _starting, _disposing;
  SharedContentState? get state => _state;
  Stream<SharedContentState?> get states => _states.stream;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  void _accept(SharedContentState? next) {
    if (_disposed ||
        (next != null &&
            next.snapshotRevision < (_state?.snapshotRevision ?? -1))) {
      return;
    }
    _isLoaded = true;
    _lastError = null;
    _state = next;
    _states.add(next);
  }

  Future<void> start() {
    if (_disposed) {
      return Future.error(
        const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'sharedContent.disposed',
        ),
      );
    }
    return _starting ??= _start().catchError((Object error, StackTrace stack) {
      _starting = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _start() async {
    if (_disposed) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'sharedContent.disposed',
      );
    }
    _subscription ??= repository.states.listen(
      _accept,
      onError: (Object error, StackTrace stack) => _reportFailure(error, stack),
    );
    await refresh();
    if (_disposed) return;
    final interval = pollInterval;
    if (interval != null) {
      _poll ??= Timer.periodic(interval, (_) {
        unawaited(
          refresh().catchError(
            (Object error, StackTrace stack) => _reportFailure(error, stack),
          ),
        );
      });
    }
  }

  Future<void> refresh() {
    if (_disposed) {
      return Future.error(
        const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'sharedContent.disposed',
        ),
      );
    }
    return _refresh ??= Future<SharedContentState?>.sync(
      repository.snapshot,
    ).then(_accept).whenComplete(() => _refresh = null);
  }

  Future<void> execute(SharedContentCommand command) async {
    if (_disposed) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'sharedContent.disposed',
      );
    }
    final action = repository.action(command);
    _actions.add(action);
    try {
      _accept(await action);
    } finally {
      _actions.remove(action);
    }
  }

  Future<void> setSource(String sourceKey) => execute(
    SharedContentCommand(SharedContentAction.source, {'sourceKey': sourceKey}),
  );
  Future<void> setEmbeddedInVideo(bool enabled) => execute(
    SharedContentCommand(SharedContentAction.presentation, {
      'canvasId': canvas.canvasId,
      'embeddedInVideo': enabled,
    }),
  );
  @override
  AnnotationCanvas get canvas => state?.screen ?? AnnotationCanvas();
  @override
  Stream<AnnotationCanvas> get canvases =>
      states.map((state) => state?.screen ?? AnnotationCanvas());
  @override
  bool get canEdit => state?.canAnnotateScreen ?? false;
  @override
  Future<void> begin(AnnotationShape shape, {required String canvasId}) =>
      execute(
        SharedContentCommand(SharedContentAction.begin, {
          'canvasId': canvasId,
          ...shape.toJson(),
        }),
      );
  @override
  Future<void> append(
    String shapeId,
    List<AnnotationPoint> points, {
    required String canvasId,
  }) => execute(
    SharedContentCommand(SharedContentAction.append, {
      'canvasId': canvasId,
      'id': shapeId,
      'points': points.map((p) => p.toJson()).toList(),
    }),
  );
  @override
  Future<void> undo() => execute(
    SharedContentCommand(SharedContentAction.undo, {
      'canvasId': canvas.canvasId,
    }),
  );
  @override
  Future<void> clear() => execute(
    SharedContentCommand(SharedContentAction.clear, {
      'canvasId': canvas.canvasId,
    }),
  );
  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    _poll?.cancel();
    final cleanup = Cleanup();
    await cleanup.run('subscription', () async {
      await _subscription?.cancel();
    });
    await cleanup.run('refresh', () async {
      await _refresh;
    });
    await cleanup.run('actions', () async {
      await Future.wait(_actions.toList());
    });
    await cleanup.run('repository', () async {
      await repository.close();
    });
    await cleanup.run('states', _states.close);
    await cleanup.run('errors', _errors.close);
    cleanup.finish(domain: 'sharedContent');
  }
}
