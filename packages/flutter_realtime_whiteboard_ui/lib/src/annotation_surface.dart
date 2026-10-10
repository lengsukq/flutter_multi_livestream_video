import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'whiteboard_strings.dart';
import 'movable_annotation_toolbar.dart';
import 'annotation_toolbar.dart';

/// This widget must occupy the contained shared-video rectangle (not the full
/// viewport). Its logical points then align on phones, tablets and desktops.
class AnnotationSurface extends StatefulWidget {
  const AnnotationSurface({
    super.key,
    required this.session,
    this.background,
    this.allowEditing = true,
    this.enableNavigation = true,
    this.toolbarAtTop = false,
    this.editTooltip,
  });
  final AnnotationController session;
  final Widget? background;
  final bool allowEditing;
  final bool enableNavigation;
  final bool toolbarAtTop;
  final String? editTooltip;
  @override
  State<AnnotationSurface> createState() => _AnnotationSurfaceState();
}

class _AnnotationSurfaceState extends State<AnnotationSurface> {
  AnnotationTool _tool = AnnotationTool.pen;
  bool _editing = false;
  AnnotationShape? _draft;
  final _batch = <AnnotationPoint>[];
  Timer? _flushTimer;
  Future<void> _work = Future.value();
  String? _failedStroke;
  Object? _error;
  bool _finishing = false;
  static final _random = math.Random.secure();
  String _canvasId = '';
  final _transform = TransformationController();
  @override
  void dispose() {
    _flushTimer?.cancel();
    _transform.dispose();
    super.dispose();
  }

  AnnotationPoint _point(Offset offset, Size size) {
    final scene = _transform.toScene(offset);
    return AnnotationPoint(
      (scene.dx / size.width).clamp(0.0, 1.0),
      (scene.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _enqueue(Future<void> Function() operation, {String? strokeId}) {
    _work = _work.then((_) async {
      if (strokeId != null && _failedStroke == strokeId) return;
      try {
        await operation();
      } catch (e) {
        if (strokeId != null) _failedStroke = strokeId;
        if (mounted) setState(() => _error = e);
      }
    });
  }

  void _start(Offset offset, Size size) {
    if (_finishing || _draft != null) return;
    final canvas = widget.session.canvas;
    if (!canvas.active) return;
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    _canvasId = canvas.canvasId;
    final shape = AnnotationShape(
      id: id,
      tool: _tool,
      points: [_point(offset, size)],
      color: _tool == AnnotationTool.highlight ? 0xffffeb3b : 0xfff59e0b,
      width: _tool == AnnotationTool.highlight ? 16 : 3,
    );
    setState(() {
      _draft = shape;
      _error = null;
    });
    _failedStroke = null;
    if (_tool == AnnotationTool.pen || _tool == AnnotationTool.highlight) {
      _enqueue(
        () => widget.session.begin(shape, canvasId: canvas.canvasId),
        strokeId: id,
      );
      _flushTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _flush(),
      );
    }
  }

  void _update(Offset offset, Size size) {
    final shape = _draft;
    if (shape == null || shape.points.length >= 2048) return;
    final point = _point(offset, size);
    final freehand =
        shape.tool == AnnotationTool.pen ||
        shape.tool == AnnotationTool.highlight;
    setState(
      () => _draft = AnnotationShape(
        id: shape.id,
        tool: shape.tool,
        points: freehand
            ? [...shape.points, point]
            : [shape.points.first, point],
        color: shape.color,
        width: shape.width,
      ),
    );
    if (freehand) {
      _batch.add(point);
      if (_batch.length >= 100) _flush();
    }
  }

  void _flush() {
    final shape = _draft;
    if (shape == null || _batch.isEmpty) return;
    final points = List<AnnotationPoint>.of(_batch);
    _batch.clear();
    final canvasId = _canvasId;
    _enqueue(
      () => widget.session.append(shape.id, points, canvasId: canvasId),
      strokeId: shape.id,
    );
  }

  void _finish() {
    final shape = _draft;
    if (shape == null || _finishing) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    _finishing = true;
    if (shape.tool == AnnotationTool.pen ||
        shape.tool == AnnotationTool.highlight) {
      _flush();
    } else {
      final canvasId = _canvasId;
      _enqueue(
        () => widget.session.begin(shape, canvasId: canvasId),
        strokeId: shape.id,
      );
    }
    unawaited(
      _work.then((_) {
        if (mounted) {
          setState(() {
            _draft = null;
            _finishing = false;
          });
        }
      }),
    );
  }

  Future<void> _label(Offset offset, Size size) async {
    final canvas = widget.session.canvas;
    if (!canvas.active) return;
    final s = WhiteboardStrings.of(context);
    final text = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _AnnotationLabelDialog(strings: s),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final shape = AnnotationShape(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
      tool: AnnotationTool.text,
      points: [_point(offset, size)],
      text: text,
    );
    _enqueue(() => widget.session.begin(shape, canvasId: canvas.canvasId));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AnnotationCanvas>(
    stream: widget.session.canvases,
    initialData: widget.session.canvas,
    builder: (context, snapshot) {
      final canvas = snapshot.data ?? AnnotationCanvas();
      // System-window strokes already occur in captured video. Editing happens
      // in that window, and drawing vectors here would duplicate the video ink.
      final teacher =
          widget.session.canEdit &&
          widget.allowEditing &&
          !canvas.embeddedInVideo;
      final matches = canvas.active;
      final s = WhiteboardStrings.of(context);
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                panEnabled: widget.enableNavigation && (!teacher || !_editing),
                scaleEnabled:
                    widget.enableNavigation && (!teacher || !_editing),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.background != null) widget.background!,
                      IgnorePointer(
                        child: CustomPaint(
                          painter: AnnotationPainter([
                            if (matches && !canvas.embeddedInVideo)
                              ...canvas.shapes.where(
                                (shape) => shape.id != _draft?.id,
                              ),
                            if (!canvas.embeddedInVideo &&
                                _draft != null &&
                                _canvasId == canvas.canvasId)
                              _draft!,
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !teacher || !_editing || !matches,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _tool == AnnotationTool.text
                      ? null
                      : (event) => _start(event.localPosition, size),
                  onPanUpdate: _tool == AnnotationTool.text
                      ? null
                      : (event) => _update(event.localPosition, size),
                  onPanEnd: _tool == AnnotationTool.text
                      ? null
                      : (_) => _finish(),
                  onPanCancel: _tool == AnnotationTool.text ? null : _finish,
                  onTapUp: _tool == AnnotationTool.text
                      ? (event) => _label(event.localPosition, size)
                      : null,
                ),
              ),
              if (teacher)
                MovableAnnotationToolbar(
                  startAtTop: widget.toolbarAtTop,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnnotationToolbar(
                      tool: _tool,
                      drawingEnabled: _editing,
                      canEdit: matches,
                      canUndo: _draft == null && !_finishing,
                      canClear: _draft == null && !_finishing,
                      canClose: false,
                      editTooltip: widget.editTooltip ?? s.t('annotate'),
                      onToolChanged: _draft != null || _finishing
                          ? null
                          : (tool) => setState(() => _tool = tool),
                      onDrawingToggle: () => setState(() {
                        if (_editing) _finish();
                        _editing = !_editing;
                      }),
                      onUndo: () => _enqueue(widget.session.undo),
                      onClear: () => _enqueue(widget.session.clear),
                    ),
                  ),
                ),
              if (_error != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('${s.t('syncError')} $_error'),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

/// Public for hosts that supply their own annotation toolbar and gestures.
class AnnotationPainter extends CustomPainter {
  AnnotationPainter(this.shapes);
  final List<AnnotationShape> shapes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final shape in shapes) {
      if (shape.points.isEmpty) continue;
      Offset position(AnnotationPoint p) =>
          Offset(p.x * size.width, p.y * size.height);
      final start = position(shape.points.first),
          end = position(shape.points.last);
      // Widths and labels scale with the content, not device pixel density.
      final scale = size.shortestSide / 720;
      final paint = Paint()
        ..color = Color(shape.color)
        ..strokeWidth = math.max(1, shape.width * scale)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      switch (shape.tool) {
        case AnnotationTool.pen:
        case AnnotationTool.highlight:
          if (shape.tool == AnnotationTool.highlight) {
            paint.color = paint.color.withValues(alpha: .35);
          }
          final path = Path()..moveTo(start.dx, start.dy);
          for (final point in shape.points.skip(1)) {
            final p = position(point);
            path.lineTo(p.dx, p.dy);
          }
          if (shape.points.length == 1) {
            canvas.drawCircle(
              start,
              paint.strokeWidth / 2,
              paint..style = PaintingStyle.fill,
            );
          } else {
            canvas.drawPath(path, paint);
          }
        case AnnotationTool.circle:
          canvas.drawOval(Rect.fromPoints(start, end), paint);
        case AnnotationTool.arrow:
          canvas.drawLine(start, end, paint);
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final length = math.max(8.0, 18 * scale);
          for (final delta in [-.5, .5]) {
            canvas.drawLine(
              end,
              end -
                  Offset(math.cos(angle + delta), math.sin(angle + delta)) *
                      length,
              paint,
            );
          }
        case AnnotationTool.text:
          final label = TextPainter(
            text: TextSpan(
              text: shape.text,
              style: TextStyle(
                color: paint.color,
                fontSize: math.max(10, 22 * scale),
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          label.layout(maxWidth: math.max(1, size.width - start.dx));
          label.paint(canvas, start);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) =>
      !identical(shapes, oldDelegate.shapes);
}

class _AnnotationLabelDialog extends StatefulWidget {
  const _AnnotationLabelDialog({required this.strings});

  final WhiteboardStrings strings;

  @override
  State<_AnnotationLabelDialog> createState() => _AnnotationLabelDialogState();
}

class _AnnotationLabelDialogState extends State<_AnnotationLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.t('label')),
      content: TextField(
        controller: _controller,
        maxLength: 200,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(s.t('submit')),
        ),
      ],
    );
  }
}
