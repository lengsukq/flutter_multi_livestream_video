import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'annotation.dart';

enum SharedContentMode { members, screen, whiteboard }

class WhiteboardPage {
  const WhiteboardPage({required this.id, required this.title});
  final String id, title;
  factory WhiteboardPage.fromJson(Map<String, dynamic> value) => WhiteboardPage(
    id: value['id'] as String,
    title: value['title'] as String,
  );
}

/// Only the active canvas is transmitted; repositories retain inactive pages.
class WhiteboardState {
  const WhiteboardState({
    required this.revision,
    required this.canEdit,
    required this.pages,
    required this.activePageId,
    required this.canvas,
    this.maxPages = 20,
  });
  final int revision, maxPages;
  final bool canEdit;
  final List<WhiteboardPage> pages;
  final String activePageId;
  final AnnotationCanvas canvas;
  factory WhiteboardState.fromJson(Map<String, dynamic> value) =>
      WhiteboardState(
        revision: value['revision'] as int? ?? 0,
        canEdit: value['canEdit'] as bool? ?? false,
        maxPages: value['maxPages'] as int? ?? 20,
        pages: List.unmodifiable(
          (value['pages'] as List).map(
            (p) => WhiteboardPage.fromJson(Map<String, dynamic>.from(p as Map)),
          ),
        ),
        activePageId: value['activePageId'] as String,
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
  factory SharedContentState.fromJson(Map<String, dynamic> value) =>
      SharedContentState(
        revision: value['revision'] as int? ?? 0,
        mode: SharedContentMode.values.byName(value['mode'] as String),
        canManage: value['canManage'] as bool? ?? false,
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
  Future<WhiteboardState> action(
    String action,
    Map<String, Object?> data, {
    required String eventId,
  });
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
    if (_closed) throw StateError('Whiteboard repository closed');
  }

  @override
  Future<WhiteboardState> snapshot() async {
    _check();
    return _snapshot();
  }

  @override
  Future<WhiteboardState> action(
    String action,
    Map<String, Object?> data, {
    required String eventId,
  }) async {
    _check();
    if (!canEdit) throw StateError('Whiteboard is read-only');
    final key = jsonEncode([action, data]);
    final previous = _handled[eventId];
    if (previous != null) {
      if (previous != key) throw StateError('Conflicting eventId');
      return _snapshot();
    }
    if (data['expectedRevision'] != _revision) {
      throw StateError('Whiteboard revision changed');
    }
    var canvas = _canvases[_active]!;
    final shapes = List<AnnotationShape>.of(canvas.shapes);
    switch (action) {
      case 'page.add':
        if (_pages.length >= maxPages) {
          throw StateError('Whiteboard page limit reached');
        }
        final title = (data['title'] as String? ?? '').trim();
        if (title.isEmpty || title.length > 120) {
          throw ArgumentError('Use a page title of 1-120 characters');
        }
        _add(title);
      case 'page.select':
        final id = data['pageId'] as String;
        if (!_canvases.containsKey(id)) {
          throw StateError('Page no longer exists');
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
        final id = data['pageId'] as String;
        final index = _pages.indexWhere((p) => p.id == id);
        if (index < 0) throw StateError('Page no longer exists');
        if (_pages.length == 1) throw StateError('Keep at least one page');
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
          throw StateError('Canvas or active page changed');
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
            throw ArgumentError('Use 1-100 normalized points');
          }
          final id = data['id'] as String;
          if (action == 'begin') {
            if (id.isEmpty ||
                id.length > 128 ||
                shapes.any((s) => s.id == id)) {
              throw ArgumentError('Invalid or duplicate shape id');
            }
            if (shapes.length >= 200) {
              throw StateError('Canvas shape limit reached');
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
              throw ArgumentError('Invalid annotation style');
            }
            shapes.add(shape);
          } else {
            final index = shapes.indexWhere((s) => s.id == id);
            if (index < 0) throw StateError('Stroke not found');
            final old = shapes[index];
            if (![
              AnnotationTool.pen,
              AnnotationTool.highlight,
            ].contains(old.tool)) {
              throw StateError('Only freehand strokes accept appended points');
            }
            if (old.points.length + points.length > 2048) {
              throw StateError('Stroke point limit reached');
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
        throw ArgumentError('Unknown whiteboard action');
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
  WhiteboardState? get state => _state;
  Stream<WhiteboardState> get states => _states.stream;
  Stream<Object> get errors => _errors.stream;
  @override
  AnnotationCanvas get canvas => _state?.canvas ?? const AnnotationCanvas();
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
    if (_disposed) return Future.error(StateError('Whiteboard disposed'));
    if (_state != null) return Future<void>.value();
    return _starting ??=
        (() async {
          _subscription ??= repository.states.listen(
            _accept,
            onError: (Object e) {
              if (!_disposed) _errors.add(e);
            },
          );
          _accept(await repository.snapshot());
        })().whenComplete(() {
          _starting = null;
        });
  }

  Future<void> refresh() async {
    if (_disposed) throw StateError('Whiteboard disposed');
    _accept(await repository.snapshot());
  }

  Future<void> _act(String action, Map<String, Object?> data) {
    final result = (_queue ?? Future<void>.value()).then((_) async {
      if (_disposed) throw StateError('Whiteboard disposed');
      if (_state == null) await start();
      if (!canEdit) throw StateError('Whiteboard is read-only');
      _accept(
        await repository.action(
          action,
          {...data, 'expectedRevision': _state!.revision},
          eventId:
              '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
        ),
      );
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

  Future<void> addPage({String? title}) => _act('page.add', {
    'title': title ?? 'Page ${(_state?.pages.length ?? 0) + 1}',
  });
  Future<void> selectPage(String pageId) =>
      _act('page.select', {'pageId': pageId});
  Future<void> deletePage(String pageId) =>
      _act('page.delete', {'pageId': pageId});
  Map<String, Object?> _target(String canvasId) => {
    'canvasId': canvasId,
    'pageId': canvas.sourceKey,
  };
  @override
  Future<void> begin(AnnotationShape shape, {required String canvasId}) =>
      _act('begin', {..._target(canvasId), ...shape.toJson()});
  @override
  Future<void> append(
    String shapeId,
    List<AnnotationPoint> points, {
    required String canvasId,
  }) => _act('append', {
    ..._target(canvasId),
    'id': shapeId,
    'points': points.map((p) => p.toJson()).toList(),
  });
  @override
  Future<void> undo() => _act('undo', _target(canvas.canvasId));
  @override
  Future<void> clear() => _act('clear', _target(canvas.canvasId));
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    try {
      if (_starting != null) await _starting;
      if (_queue != null) await _queue;
    } catch (_) {
      /* callers received errors */
    }
    if (ownsRepository) await repository.close();
    await _states.close();
    await _errors.close();
  }
}
