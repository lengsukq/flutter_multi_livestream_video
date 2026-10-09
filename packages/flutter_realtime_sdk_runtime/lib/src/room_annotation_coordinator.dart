import 'dart:async';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class RoomAnnotationCoordinator {
  RoomAnnotationCoordinator(this.media, this.classroom, this.onFailure) {
    _mediaSub = media.snapshots.listen((_) => _syncAnnotationSource());
    _classSub = classroom.states.listen((_) => _syncAnnotationSource());
  }
  final MediaSession media;
  final ClassroomSession classroom;
  final void Function(RealtimeException) onFailure;
  StreamSubscription<MediaSnapshot>? _mediaSub;
  StreamSubscription<ClassroomState>? _classSub;
  Future<void>? _operation, _disposeFuture;
  String? _applied;
  String _target = '';
  bool _disposed = false;
  void _syncAnnotationSource() {
    if (_disposed || classroom.state?.capabilities.canPublishTools != true) {
      return;
    }
    if (classroom.state?.tools?.content != null) return;
    final track = media.snapshot.contentShareTrack;
    _target = track?.isLocal == true ? track!.id : '';
    if (_applied == _target || _operation != null) {
      return;
    }
    _operation =
        (() async {
              while (!_disposed && _applied != _target) {
                final source = _target;
                await classroom.annotations.setSource(source);
                _applied = source;
              }
            })()
            .catchError((Object error) {
              if (!_disposed) {
                onFailure(
                  normalizeRealtimeException(error, domain: 'annotation'),
                );
              }
            })
            .whenComplete(() => _operation = null);
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    final cleanup = Cleanup();
    await cleanup.run('annotation.media', () async {
      await _mediaSub?.cancel();
    });
    await cleanup.run('annotation.classroom', () async {
      await _classSub?.cancel();
    });
    await cleanup.run('annotation.operation', () async {
      await _operation;
    });
    cleanup.finish(domain: 'annotation');
  }
}
