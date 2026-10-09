import 'whiteboard_command.dart';
import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'annotation.dart';

enum SharedContentMode { members, screen, whiteboard }

class WhiteboardPage {
  const WhiteboardPage({required this.id, required this.title});
  final String id, title;
  factory WhiteboardPage.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => WhiteboardPage._fromJsonUnchecked(value));
  factory WhiteboardPage._fromJsonUnchecked(Map<String, dynamic> value) =>
      WhiteboardPage(
        id: JsonReader(value).required<String>('id'),
        title: JsonReader(value).required<String>('title'),
      );
}

/// Only the active canvas is transmitted; repositories retain inactive pages.
class WhiteboardState {
  WhiteboardState({
    required this.revision,
    required this.canEdit,
    required List<WhiteboardPage> pages,
    required this.activePageId,
    required this.canvas,
    this.maxPages = 20,
  }) : pages = List.unmodifiable(pages);
  final int revision, maxPages;
  final bool canEdit;
  final List<WhiteboardPage> pages;
  final String activePageId;
  final AnnotationCanvas canvas;
  factory WhiteboardState.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => WhiteboardState._fromJsonUnchecked(value));
  factory WhiteboardState._fromJsonUnchecked(Map<String, dynamic> value) =>
      WhiteboardState(
        revision: JsonReader(value).optional<int>('revision') ?? 0,
        canEdit: JsonReader(value).optional<bool>('canEdit') ?? false,
        maxPages: JsonReader(value).optional<int>('maxPages') ?? 20,
        pages: JsonReader(
          value,
        ).objects('pages', WhiteboardPage.fromJson, optional: false),
        activePageId: JsonReader(value).required<String>('activePageId'),
        canvas: AnnotationCanvas.fromJson(
          Map<String, dynamic>.from(value['canvas'] as Map),
        ),
      );
}

class SharedContentState {
  const SharedContentState({
    required this.mode,
    required this.whiteboard,
    required this.screen,
    required this.canManage,
    this.revision = 0,
  });
  final SharedContentMode mode;
  final WhiteboardState whiteboard;
  final AnnotationCanvas screen;
  final bool canManage;
  final int revision;
  factory SharedContentState.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => SharedContentState._fromJsonUnchecked(value));
  factory SharedContentState._fromJsonUnchecked(Map<String, dynamic> value) =>
      SharedContentState(
        revision: JsonReader(value).optional<int>('revision') ?? 0,
        mode: JsonReader(value).enumValue('mode', SharedContentMode.values),
        canManage: JsonReader(value).optional<bool>('canManage') ?? false,
        whiteboard: WhiteboardState.fromJson(
          Map<String, dynamic>.from(value['whiteboard'] as Map),
        ),
        screen: AnnotationCanvas.fromJson(
          Map<String, dynamic>.from(value['screen'] as Map),
        ),
      );
}

abstract interface class WhiteboardRepository {
  Stream<WhiteboardState> get states;
  Future<WhiteboardState> snapshot();
  Future<WhiteboardState> action(WhiteboardCommand command);
  Future<void> close();
}

/// Local, offline repository. A remote implementation must authorize requests
/// independently; canEdit is never a substitute for backend authorization.
class MemoryWhiteboardRepository implements WhiteboardRepository {
  MemoryWhiteboardRepository({this.canEdit = true, this.maxPages = 20}) {
    if (maxPages < 1) throw ArgumentError.value(maxPages, 'maxPages');
    _add('Page 1');
  }
  final bool canEdit;
  final int maxPages;
  final _states = StreamController<WhiteboardState>.broadcast();
  final _pages = <WhiteboardPage>[];
  final _canvases = <String, AnnotationCanvas>{};
  final _handled = <String, String>{};
  int _revision = 0, _sequence = 0;
  String _active = '';
  bool _closed = false;
  String _id() => 'local-${++_sequence}';
  void _add(String title) {
    final id = _id();
    _pages.add(WhiteboardPage(id: id, title: title));
    _canvases[id] = AnnotationCanvas(
      canvasId: _id(),
      sourceKey: id,
      participantId: 'local',
    );
    _active = id;
  }

  @override
  Stream<WhiteboardState> get states => _states.stream;
  WhiteboardState _snapshot() => WhiteboardState(
    revision: _revision,
    canEdit: canEdit,
    maxPages: maxPages,
    pages: List.unmodifiable(_pages),
    activePageId: _active,
    canvas: _canvases[_active]!,
  );
  void _check() {
    if (_closed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Whiteboard repository closed',
      );
    }
  }

  @override
  Future<WhiteboardState> snapshot() async {
    _check();
    return _snapshot();
  }

  @override
  Future<WhiteboardState> action(WhiteboardCommand command) async {
    final action = command.action.wireName;
    final data = command.payload;
    final eventId = command.eventId;
    _check();
    if (!canEdit) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Whiteboard is read-only',
      );
    }
    final key = jsonEncode([action, data]);
    final previous = _handled[eventId];
    if (previous != null) {
      if (previous != key) {
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Conflicting eventId',
        );
      }
      return _snapshot();
    }
    if (data['expectedRevision'] != _revision) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Whiteboard revision changed',
      );
    }
    var canvas = _canvases[_active]!;
    final shapes = List<AnnotationShape>.of(canvas.shapes);
    switch (action) {
      case 'page.add':
        if (_pages.length >= maxPages) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidState,
            message: 'Whiteboard page limit reached',
          );
        }
        final title = (JsonReader(data).optional<String>('title') ?? '').trim();
        if (title.isEmpty || title.length > 120) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidArgument,
            message: 'Use a page title of 1-120 characters',
          );
        }
        _add(title);
      case 'page.select':
        final id = JsonReader(data).required<String>('pageId');
        if (!_canvases.containsKey(id)) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidState,
            message: 'Page no longer exists',
          );
        }
        _active = id;
        final selected = _canvases[id]!;
        _canvases[id] = AnnotationCanvas(
          canvasId: _id(),
          sourceKey: id,
          participantId: selected.participantId,
          shapes: selected.shapes,
        );
      case 'page.delete':
        final id = JsonReader(data).required<String>('pageId');
        final index = _pages.indexWhere((p) => p.id == id);
        if (index < 0) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidState,
            message: 'Page no longer exists',
          );
        }
        if (_pages.length == 1) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidState,
            message: 'Keep at least one page',
          );
        }
        _pages.removeAt(index);
        _canvases.remove(id);
        if (_active == id) {
          _active = _pages[max(0, index - 1)].id;
          final selected = _canvases[_active]!;
          _canvases[_active] = AnnotationCanvas(
            canvasId: _id(),
            sourceKey: _active,
            participantId: selected.participantId,
            shapes: selected.shapes,
          );
        }
      case 'begin':
      case 'append':
      case 'undo':
      case 'clear':
        if (data['pageId'] != _active || data['canvasId'] != canvas.canvasId) {
          throw RealtimeException(
            code: RealtimeErrorCode.invalidState,
            message: 'Canvas or active page changed',
          );
        }
        if (action == 'clear') {
          shapes.clear();
        } else if (action == 'undo') {
          if (shapes.isNotEmpty) shapes.removeLast();
        } else {
          final points = (data['points'] as List)
              .map(
                (p) => AnnotationPoint.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList();
          if (points.isEmpty ||
              points.length > 100 ||
              points.any(
                (p) =>
                    !p.x.isFinite ||
                    !p.y.isFinite ||
                    p.x < 0 ||
                    p.x > 1 ||
                    p.y < 0 ||
                    p.y > 1,
              )) {
            throw RealtimeException(
              code: RealtimeErrorCode.invalidArgument,
              message: 'Use 1-100 normalized points',
            );
          }
          final id = JsonReader(data).required<String>('id');
          if (action == 'begin') {
            if (id.isEmpty ||
                id.length > 128 ||
                shapes.any((s) => s.id == id)) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidArgument,
                message: 'Invalid or duplicate shape id',
              );
            }
            if (shapes.length >= 200) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidState,
                message: 'Canvas shape limit reached',
              );
            }
            final shape = AnnotationShape.fromJson(
              Map<String, dynamic>.from(data),
            );
            if (shape.color < 0 ||
                shape.color > 0xffffffff ||
                shape.width < 1 ||
                shape.width > 20 ||
                (shape.tool == AnnotationTool.text &&
                    (shape.text.trim().isEmpty || shape.text.length > 200))) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidArgument,
                message: 'Invalid annotation style',
              );
            }
            shapes.add(shape);
          } else {
            final index = shapes.indexWhere((s) => s.id == id);
            if (index < 0) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidState,
                message: 'Stroke not found',
              );
            }
            final old = shapes[index];
            if (![
              AnnotationTool.pen,
              AnnotationTool.highlight,
            ].contains(old.tool)) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidState,
                message: 'Only freehand strokes accept appended points',
              );
            }
            if (old.points.length + points.length > 2048) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidState,
                message: 'Stroke point limit reached',
              );
            }
            shapes[index] = AnnotationShape(
              id: old.id,
              tool: old.tool,
              color: old.color,
              width: old.width,
              text: old.text,
              points: List.unmodifiable([...old.points, ...points]),
            );
          }
        }
        canvas = AnnotationCanvas(
          canvasId: canvas.canvasId,
          sourceKey: canvas.sourceKey,
          participantId: canvas.participantId,
          shapes: List.unmodifiable(shapes),
        );
        _canvases[_active] = canvas;
      default:
        throw RealtimeException(
          code: RealtimeErrorCode.invalidArgument,
          message: 'Unknown whiteboard action',
        );
    }
    _revision++;
    _handled[eventId] = key;
    if (_handled.length > 1000) _handled.remove(_handled.keys.first);
    final state = _snapshot();
    _states.add(state);
    return state;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _states.close();
  }
}

class WhiteboardSession implements AnnotationController {
  WhiteboardSession(this.repository, {this.ownsRepository = true});
  factory WhiteboardSession.local({bool canEdit = true, int maxPages = 20}) =>
      WhiteboardSession(
        MemoryWhiteboardRepository(canEdit: canEdit, maxPages: maxPages),
      );
  final WhiteboardRepository repository;
  final bool ownsRepository;
  final _states = StreamController<WhiteboardState>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  static final _random = Random.secure();
  WhiteboardState? _state;
  StreamSubscription<WhiteboardState>? _subscription;
  Future<void>? _queue;
  Future<void>? _starting;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);
  WhiteboardState? get state => _state;
  Stream<WhiteboardState> get states => _states.stream;
  Stream<Object> get errors => _errors.stream;
  @override
  AnnotationCanvas get canvas => _state?.canvas ?? AnnotationCanvas();
  @override
  Stream<AnnotationCanvas> get canvases => states.map((s) => s.canvas);
  @override
  bool get canEdit => _state?.canEdit ?? false;
  void _accept(WhiteboardState value) {
    if (_disposed || (_state != null && value.revision < _state!.revision)) {
      return;
    }
    _state = value;
    _states.add(value);
  }

  Future<void> start() {
    if (_disposed) {
      return Future.error(
        const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Whiteboard disposed',
          domain: 'whiteboard',
        ),
      );
    }

    if (_state != null) return Future<void>.value();
    return _starting ??=
        (() async {
          _subscription ??= repository.states.listen(
            _accept,
            onError: (Object e) {
              if (!_disposed) _errors.add(e);
            },
          );
          await refresh();
        })().whenComplete(() {
          _starting = null;
        });
  }

  Future<void> refresh() async {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Whiteboard disposed',
      );
    }
    try {
      _accept(await repository.snapshot());
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'whiteboard',
          operation: 'snapshot',
          stackTrace: stack,
        ),
        stack,
      );
    }
  }

  Future<void> _act(WhiteboardAction action, Map<String, Object?> data) {
    final result = (_queue ?? Future<void>.value()).then((_) async {
      if (_disposed) {
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Whiteboard disposed',
        );
      }
      if (_state == null) await start();
      if (!canEdit) {
        throw RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Whiteboard is read-only',
        );
      }
      try {
        _accept(
          await repository.action(
            WhiteboardCommand(
              action,
              {...data, 'expectedRevision': _state!.revision},
              eventId:
                  '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
            ),
          ),
        );
      } catch (error, stack) {
        Error.throwWithStackTrace(
          normalizeRealtimeException(
            error,
            domain: 'whiteboard',
            operation: action.wireName,
            stackTrace: stack,
          ),
          stack,
        );
      }
    });
    final tail = result.catchError((Object e) {
      if (!_disposed) _errors.add(e);
    });
    _queue = tail;
    unawaited(
      tail.then((_) {
        if (identical(_queue, tail)) _queue = null;
      }),
    );
    return result;
  }

  Future<void> addPage({String? title}) => _act(WhiteboardAction.pageAdd, {
    'title': title ?? 'Page ${(_state?.pages.length ?? 0) + 1}',
  });
  Future<void> selectPage(String pageId) =>
      _act(WhiteboardAction.pageSelect, {'pageId': pageId});
  Future<void> deletePage(String pageId) =>
      _act(WhiteboardAction.pageDelete, {'pageId': pageId});
  Map<String, Object?> _target(String canvasId) => {
    'canvasId': canvasId,
    'pageId': canvas.sourceKey,
  };
  @override
  Future<void> begin(AnnotationShape shape, {required String canvasId}) =>
      _act(WhiteboardAction.begin, {..._target(canvasId), ...shape.toJson()});
  @override
  Future<void> append(
    String shapeId,
    List<AnnotationPoint> points, {
    required String canvasId,
  }) => _act(WhiteboardAction.append, {
    ..._target(canvasId),
    'id': shapeId,
    'points': points.map((p) => p.toJson()).toList(),
  });
  @override
  Future<void> undo() => _act(WhiteboardAction.undo, _target(canvas.canvasId));
  @override
  Future<void> clear() =>
      _act(WhiteboardAction.clear, _target(canvas.canvasId));
  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('whiteboard.subscription', () async {
      await _subscription?.cancel();
    });
    await cleanup.run('whiteboard.queue', () async {
      await _queue;
    });
    if (ownsRepository) {
      await cleanup.run('whiteboard.repository', repository.close);
    }
    await cleanup.run('whiteboard.states', _states.close);
    await cleanup.run('whiteboard.errors', _errors.close);
    cleanup.finish(domain: 'whiteboard');
  }
}
