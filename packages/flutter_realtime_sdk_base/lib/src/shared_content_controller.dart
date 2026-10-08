import 'dart:async';
import 'package:flutter_realtime_screen_annotation/flutter_realtime_screen_annotation.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'classroom_whiteboard_repository.dart';

class SharedContentStatus {
  const SharedContentStatus({
    required this.content,
    required this.busy,
    required this.captureActive,
    this.error,
  });
  final SharedContentState? content;
  final bool busy, captureActive;
  final Object? error;
}

/// Coordinates capture and authoritative content state without touching camera/mic.
class SharedContentController {
  SharedContentController({required this.media, required this.classroom}) {
    _hadLocalCapture = media.snapshot.localScreenShareEnabled;
    whiteboard = WhiteboardSession(ClassroomWhiteboardRepository(classroom));
    systemAnnotations = SystemScreenAnnotationController(
      annotations: classroom.annotations,
    );
    _systemSub = systemAnnotations.changes.listen((_) {
      _emit();
      if (!systemAnnotations.active &&
          classroom.annotations.canvas.embeddedInVideo &&
          !_openingSystem) {
        unawaited(_restoreAnnotationLayer());
      }
    });
    _classSub = classroom.states.listen((_) {
      if (_openingSystem && content?.canManage != true) {
        unawaited(
          systemAnnotations.stop().catchError((Object e) {
            _error = e;
            _emit();
          }),
        );
      }
      _emit();
    });
    _mediaSub = media.snapshots.listen((_) {
      if (!media.snapshot.localScreenShareEnabled &&
          (systemAnnotations.active || _openingSystem)) {
        unawaited(
          stopSystemAnnotations().catchError((Object e) {
            _error = e;
            _emit();
          }),
        );
      }
      _emit();
      _reconcile();
    });
  }
  final MediaSession media;
  final ClassroomSession classroom;
  late final WhiteboardSession whiteboard;
  late final SystemScreenAnnotationController systemAnnotations;
  StreamSubscription<void>? _systemSub;
  bool _openingSystem = false;
  Future<void>? _systemStarting;
  Future<void>? _restoreSystem;
  AnnotationController get screenAnnotations => classroom.annotations;
  final _statuses = StreamController<SharedContentStatus>.broadcast();
  StreamSubscription<ClassroomState>? _classSub;
  StreamSubscription<MediaSnapshot>? _mediaSub;
  bool _busy = false, _disposed = false;
  bool _hadLocalCapture = false;
  Object? _error;
  String? _fallbackSource;
  Future<void>? _reconciling;
  Future<void>? _operation;
  SharedContentState? get content => classroom.state?.tools?.content;
  bool get supported => content != null;
  SharedContentStatus get status => SharedContentStatus(
    content: content,
    busy: _busy,
    captureActive: media.snapshot.localScreenShareEnabled,
    error: _error ?? systemAnnotations.error,
  );
  Stream<SharedContentStatus> get statuses => _statuses.stream;
  // Drawing updates remain inside the annotation widget, never rebuilding video.
  Stream<Object?> get stageUpdates => statuses
      .map(
        (s) => (
          classroom.state != null,
          s.content?.mode,
          s.content?.screen.canvasId,
          s.content?.screen.participantId,
        ),
      )
      .distinct();
  bool get canShare =>
      media is InteractiveMediaSession && media.capabilities.canScreenShare;
  Future<void> startSystemAnnotations({
    SystemAnnotationViewport viewport = const SystemAnnotationViewport(),
    String languageCode = 'en',
    bool embeddedInVideo = true,
  }) async {
    if (_disposed || _busy || _openingSystem) {
      throw StateError('Content is busy');
    }
    if (!media.snapshot.localScreenShareEnabled ||
        content?.mode != SharedContentMode.screen ||
        content?.canManage != true) {
      throw StateError(
        'Share the primary display before opening system annotation tools',
      );
    }
    if (systemAnnotations.active) return;
    _openingSystem = true;
    final starting = Completer<void>();
    _systemStarting = starting.future;
    try {
      final caps = await SystemScreenAnnotationController.capabilities();
      if (!caps.supported) throw UnsupportedError(caps.reason);
      if (_disposed) throw StateError('Content controller disposed');
      // User authorization is requested by the SDK immediately on this action,
      // even if an older custom backend later rejects presentation setup.
      await systemAnnotations.requestPermission();
      if (_disposed ||
          !media.snapshot.localScreenShareEnabled ||
          content?.canManage != true) {
        throw StateError(
          'The shared screen changed while requesting permission',
        );
      }
      await _restoreSystem;
      await classroom.annotations.setEmbeddedInVideo(embeddedInVideo);
      if (classroom.annotations.canvas.embeddedInVideo != embeddedInVideo) {
        throw UnsupportedError(
          'The classroom backend does not support system annotation presentation',
        );
      }
      await systemAnnotations.start(
        viewport: viewport,
        languageCode: languageCode,
      );
      _error = null;
    } catch (e) {
      _error = e;
      await _restoreAnnotationLayer();
      rethrow;
    } finally {
      _openingSystem = false;
      starting.complete();
      _systemStarting = null;
      _emit();
    }
  }

  Future<void> _restoreAnnotationLayer() {
    return _restoreSystem ??= (() async {
      try {
        if (classroom.annotations.canvas.active &&
            classroom.annotations.canEdit &&
            classroom.annotations.canvas.embeddedInVideo) {
          await classroom.annotations.setEmbeddedInVideo(false);
        }
      } catch (e) {
        _error = e;
        _emit();
      }
    })().whenComplete(() => _restoreSystem = null);
  }

  Future<void> stopSystemAnnotations() async {
    await systemAnnotations.stop();
    await _restoreAnnotationLayer();
    _emit();
  }

  void _emit() {
    if (!_disposed) _statuses.add(status);
  }

  Future<void> start() async {
    try {
      await classroom.start();
      if (supported) await whiteboard.start();
      _emit();
    } catch (e) {
      _error = e;
      _emit();
    }
  }

  String _source() {
    final track = media.snapshot.contentShareTrack;
    if (track?.isLocal == true) return track!.id;
    return _fallbackSource ??=
        'capture-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _commit(SharedContentMode mode, int revision) =>
      classroom.toolAction('content.mode', {
        'mode': mode.name,
        'expectedRevision': revision,
        if (mode == SharedContentMode.screen) 'sourceKey': _source(),
      });
  Future<void> selectMode(SharedContentMode mode) {
    if (_busy || _openingSystem) {
      return Future.error(
        StateError('A content change is already in progress'),
      );
    }
    _busy = true;
    _error = null;
    _emit();
    final result = _switch(mode);
    _operation = result;
    return result.whenComplete(() {
      _busy = false;
      _operation = null;
      _emit();
    });
  }

  Future<void> _switch(SharedContentMode mode) async {
    try {
      if (_disposed) throw StateError('Content controller disposed');
      if (!supported) throw UnsupportedError('Shared content is unavailable');
      if (content!.canManage != true) {
        throw StateError('Teacher permission required');
      }
      final revision = content!.revision;
      final interactive = media is InteractiveMediaSession
          ? media as InteractiveMediaSession
          : null;
      if (mode != SharedContentMode.screen) {
        await stopSystemAnnotations();
        if (media.snapshot.localScreenShareEnabled) {
          if (interactive == null) {
            throw UnsupportedError('Cannot stop screen capture');
          }
          await interactive.setScreenShareEnabled(false);
          if (media.snapshot.localScreenShareEnabled) {
            throw StateError('Screen capture has not stopped');
          }
          _fallbackSource = null;
          _hadLocalCapture = false;
        }
        try {
          await _commit(mode, revision);
        } catch (e) {
          throw StateError(
            '内容切换提交失败；共享已停止，可重试 / Capture stopped; retry content change: $e',
          );
        }
      } else {
        if (!canShare) {
          throw UnsupportedError(
            'Screen sharing unavailable on this provider/platform',
          );
        }
        final started = !media.snapshot.localScreenShareEnabled;
        if (started) {
          await interactive!.setScreenShareEnabled(true);
          if (!media.snapshot.localScreenShareEnabled) {
            throw StateError(
              'Screen selection cancelled or capture did not start',
            );
          }
          _fallbackSource = null;
        }
        _hadLocalCapture = true;
        try {
          await _commit(mode, revision);
        } catch (commitError) {
          if (started) {
            try {
              await interactive!.setScreenShareEnabled(false);
              if (media.snapshot.localScreenShareEnabled) {
                throw StateError('Capture remains active');
              }
              _fallbackSource = null;
              _hadLocalCapture = false;
            } catch (stopError) {
              throw StateError(
                '提交失败且共享仍在进行；请停止共享 / Capture remains active: $commitError; $stopError',
              );
            }
          }
          throw StateError(
            '共享模式提交失败，可重试 / Screen mode commit failed: $commitError',
          );
        }
      }
    } catch (e) {
      try {
        await classroom.refresh();
      } catch (_) {}
      _error = e;
      _emit();
      rethrow;
    }
  }

  void _reconcile() {
    if (_disposed ||
        _busy ||
        _error != null ||
        _reconciling != null ||
        content?.canManage != true) {
      return;
    }
    final active = media.snapshot.localScreenShareEnabled;
    final source = active ? _source() : '';
    final current = content!;
    if (active) _hadLocalCapture = true;
    if (active && current.mode == SharedContentMode.whiteboard) return;
    if (!active &&
        !_hadLocalCapture &&
        current.screen.participantId != media.snapshot.localParticipantId) {
      return;
    }
    if (source == current.screen.sourceKey ||
        (!active && current.mode != SharedContentMode.screen)) {
      return;
    }
    _reconciling = classroom.annotations
        .setSource(source)
        .catchError((Object e) {
          _error = e;
          _emit();
        })
        .whenComplete(() {
          if (!active) _hadLocalCapture = false;
          _reconciling = null;
        });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _classSub?.cancel();
    await _mediaSub?.cancel();
    await _systemSub?.cancel();
    await systemAnnotations.dispose();
    await _systemStarting;
    await _restoreAnnotationLayer();
    try {
      await _operation;
      await _reconciling;
    } catch (_) {}
    await whiteboard.dispose();
    await _statuses.close();
  }
}
