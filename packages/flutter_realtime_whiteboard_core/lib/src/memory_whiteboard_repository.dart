import 'whiteboard_command.dart';
import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'annotation_canvas.dart';
import 'annotation_point.dart';
import 'annotation_shape.dart';
import 'annotation_tool.dart';
import 'whiteboard_page.dart';
import 'whiteboard_repository.dart';
import 'whiteboard_state.dart';

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
  // Per-canvas reverse history for consecutive erases. Non-erase writes
  // invalidate it; no eraser strokes are persisted or shared as paint.
  final _erased = <String, List<({int index, AnnotationShape shape})>>{};
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
      case 'erase':
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
          _erased.remove(canvas.canvasId);
        } else if (action == 'undo') {
          final erased = _erased[canvas.canvasId];
          if (erased != null && erased.isNotEmpty) {
            final record = erased.removeLast();
            shapes.insert(min(record.index, shapes.length), record.shape);
          } else if (shapes.isNotEmpty) {
            shapes.removeLast();
          }
        } else if (action == 'erase') {
          final id = JsonReader(data).required<String>('id');
          final index = shapes.indexWhere((s) => s.id == id);
          if (index < 0) {
            throw RealtimeException(
              code: RealtimeErrorCode.invalidState,
              message: 'Shape not found',
            );
          }
          _erased.putIfAbsent(canvas.canvasId, () => []).add((
            index: index,
            shape: shapes.removeAt(index),
          ));
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
                    p.x < -1000 ||
                    p.x > 1000 ||
                    p.y < -1000 ||
                    p.y > 1000,
              )) {
            throw RealtimeException(
              code: RealtimeErrorCode.invalidArgument,
              message: 'Use 1-100 finite whiteboard scene points',
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
            if (shape.tool == AnnotationTool.eraser) {
              throw RealtimeException(
                code: RealtimeErrorCode.invalidArgument,
                message: 'Eraser is not a drawable shape',
              );
            }
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
            _erased.remove(canvas.canvasId);
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
            _erased.remove(canvas.canvasId);
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
