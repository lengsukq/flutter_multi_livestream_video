import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'annotation_surface.dart';
import 'whiteboard_strings.dart';

/// Independent view: no media, chat or classroom session is required.
/// The host owns and disposes the session. Students follow its active page.
///
/// Reference classroom shape: a 60 pt vertical teaching-tool rail on the left,
/// a page-tab bar across the top and a 16:9 board with zoom controls. The rail
/// only exposes tools the whiteboard core can actually execute.
class WhiteboardView extends StatefulWidget {
  const WhiteboardView({super.key, required this.session, this.onStop});
  final WhiteboardSession session;
  final VoidCallback? onStop;
  @override
  State<WhiteboardView> createState() => _WhiteboardViewState();
}

class _WhiteboardViewState extends State<WhiteboardView> {
  Object? _error;
  bool _busy = false;
  AnnotationTool _tool = AnnotationTool.pen;
  int _selectedColor = 0xff1f2a3c;
  bool _drawingEnabled = true;
  int _zoomPercent = 100;
  final _transform = TransformationController();

  static const _penColors = <int>[
    0xff1f2a3c,
    0xff2563eb,
    0xffd93a3f,
    0xfff5c518,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_run(widget.session.start));
  }

  @override
  void didUpdateWidget(WhiteboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      unawaited(_run(widget.session.start));
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await operation();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setZoom(double scale) {
    final next = scale.clamp(1.0, 3.0);
    final size = _viewportSize;
    if (size == null) return;
    // Zoom around the viewport center so the visible region stays put.
    final center = Offset(size.width / 2, size.height / 2);
    final scene = _transform.toScene(center);
    final matrix = Matrix4.identity()
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1)
      ..translateByDouble(center.dx, center.dy, 0, 1);
    _transform.value = matrix;
    setState(() => _zoomPercent = (next * 100).round());
  }

  Size? _viewportSize;

  @override
  Widget build(BuildContext context) => StreamBuilder<WhiteboardState>(
    stream: widget.session.states,
    initialData: widget.session.state,
    builder: (context, snapshot) {
      final state = snapshot.data;
      final s = WhiteboardStrings.of(context);
      if (state == null) {
        return Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Text('$_error'),
        );
      }
      final activeIndex = state.pages.indexWhere(
        (p) => p.id == state.activePageId,
      );
      final style = RealtimeStyle.of(context);
      final rail = state.canEdit ? _buildToolRail(context, state) : null;

      return Material(
        color: style.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                RealtimeBreakpoints.isWide(
                  context,
                  MediaQuery.sizeOf(context).width,
                ) &&
                constraints.maxWidth >= 600 &&
                constraints.maxHeight >= 420;
            final body = Column(
              children: [
                _buildPageBar(context, state, activeIndex, s),
                if (!wide && state.canEdit)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: _buildHorizontalToolbar(context, state),
                  ),
                if (_error != null)
                  Text(
                    '$_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 8 : 12,
                      8,
                      wide ? 8 : 12,
                      12,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: RealtimeBoardSurface(
                          radius: RealtimeUiThemeExtension.of(
                            context,
                          ).stageRadius,
                          child: LayoutBuilder(
                            builder: (context, board) {
                              _viewportSize = board.biggest;
                              return AnnotationSurface(
                                key: ValueKey(state.canvas.canvasId),
                                session: widget.session,
                                tool: _tool,
                                selectedColor: _selectedColor,
                                drawingEnabled: _drawingEnabled,
                                toolbarPlacement:
                                    AnnotationToolbarPlacement.none,
                                transformationController: _transform,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (rail == null) return body;
            if (!wide) return body;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rail,
                Expanded(child: body),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _buildPageBar(
    BuildContext context,
    WhiteboardState state,
    int activeIndex,
    WhiteboardStrings s,
  ) {
    final style = RealtimeStyle.of(context);
    final pageTabs = <Widget>[
      for (var i = 0; i < state.pages.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _PageTab(
            label: state.pages[i].title.isEmpty
                ? (s.zh ? '第 ${i + 1} 页' : 'Page ${i + 1}')
                : state.pages[i].title,
            selected: i == activeIndex,
            onTap: state.canEdit && !_busy && i != activeIndex
                ? () => _run(() => widget.session.selectPage(state.pages[i].id))
                : null,
          ),
        ),
      if (state.canEdit)
        IconButton(
          tooltip: s.t('addPage'),
          iconSize: 18,
          onPressed: _busy || state.pages.length >= state.maxPages
              ? null
              : () => _run(
                  () => widget.session.addPage(
                    title: s.zh
                        ? '第 ${state.pages.length + 1} 页'
                        : 'Page ${state.pages.length + 1}',
                  ),
                ),
          icon: const Icon(Icons.add_rounded),
        ),
    ];
    final trailing = <Widget>[
      _ZoomControl(
        percent: _zoomPercent,
        onZoomOut: _zoomPercent <= 100
            ? null
            : () => _setZoom(_zoomPercent / 100 - .25),
        onZoomIn: _zoomPercent >= 300
            ? null
            : () => _setZoom(_zoomPercent / 100 + .25),
        onReset: _zoomPercent == 100 ? null : () => _setZoom(1),
      ),
      if (state.canEdit) ...[
        const SizedBox(width: 4),
        IconButton(
          tooltip: s.t('deletePage'),
          iconSize: 18,
          onPressed: _busy || state.pages.length <= 1
              ? null
              : () => _run(() => widget.session.deletePage(state.activePageId)),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
      if (widget.onStop != null) ...[
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: widget.onStop,
          style: FilledButton.styleFrom(
            backgroundColor: style.speakStrong,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: TextStyle(
              fontFamily: RealtimeFonts.bodyOf(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          icon: const Icon(Icons.stop_rounded, size: 16),
          label: Text(s.t('stopSharing')),
        ),
      ],
    ];
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(bottom: BorderSide(color: style.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below the tablet breakpoint the fixed trailing controls cannot
          // share a row with the page tabs, so the whole bar scrolls.
          if (constraints.maxWidth < 640) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [...pageTabs, const SizedBox(width: 8), ...trailing],
              ),
            );
          }
          return Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: pageTabs),
                ),
              ),
              const SizedBox(width: 8),
              ...trailing,
            ],
          );
        },
      ),
    );
  }

  /// Vertical rails mirror the reference teaching tools. Only implemented
  /// tools appear; the rail has no decorative dead buttons.
  Widget _buildToolRail(BuildContext context, WhiteboardState state) {
    final style = RealtimeStyle.of(context);
    final s = WhiteboardStrings.of(context);
    return Container(
      width: 60,
      color: style.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _RailTool(
              icon: _drawingEnabled
                  ? Icons.pan_tool_outlined
                  : Icons.near_me_outlined,
              tooltip: s.t('annotate'),
              selected: !_drawingEnabled,
              onTap: () => setState(() => _drawingEnabled = !_drawingEnabled),
            ),
            const _RailDivider(),
            for (final entry in const <(AnnotationTool, IconData, String)>[
              (AnnotationTool.pen, Icons.edit_rounded, 'pen'),
              (AnnotationTool.highlight, Icons.brush_rounded, 'highlight'),
              (AnnotationTool.circle, Icons.circle_outlined, 'circle'),
              (AnnotationTool.arrow, Icons.arrow_outward_rounded, 'arrow'),
              (AnnotationTool.text, Icons.title_rounded, 'label'),
            ])
              _RailTool(
                icon: entry.$2,
                tooltip: s.t(entry.$3),
                selected: _tool == entry.$1,
                onTap: () => setState(() {
                  _tool = entry.$1;
                  _drawingEnabled = true;
                }),
              ),
            const _RailDivider(),
            for (final color in _penColors)
              _ColorDot(
                color: Color(color),
                selected: _selectedColor == color,
                onTap: () => setState(() => _selectedColor = color),
              ),
            const _RailDivider(),
            _RailTool(
              icon: Icons.undo_rounded,
              tooltip: s.t('undo'),
              onTap: _busy ? null : () => _run(widget.session.undo),
            ),
            _RailTool(
              icon: Icons.delete_sweep_outlined,
              tooltip: s.t('clear'),
              onTap: _busy ? null : () => _run(widget.session.clear),
            ),
          ],
        ),
      ),
    );
  }

  /// Tablets and phones keep the same tools in a compact horizontal strip.
  Widget _buildHorizontalToolbar(BuildContext context, WhiteboardState state) {
    final style = RealtimeStyle.of(context);
    final s = WhiteboardStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in const <(AnnotationTool, IconData, String)>[
            (AnnotationTool.pen, Icons.edit_rounded, 'pen'),
            (AnnotationTool.highlight, Icons.brush_rounded, 'highlight'),
            (AnnotationTool.circle, Icons.circle_outlined, 'circle'),
            (AnnotationTool.arrow, Icons.arrow_outward_rounded, 'arrow'),
            (AnnotationTool.text, Icons.title_rounded, 'label'),
          ])
            _RailTool(
              icon: entry.$2,
              tooltip: s.t(entry.$3),
              selected: _tool == entry.$1,
              compact: true,
              onTap: () => setState(() {
                _tool = entry.$1;
                _drawingEnabled = true;
              }),
            ),
          for (final color in _penColors)
            _ColorDot(
              color: Color(color),
              selected: _selectedColor == color,
              onTap: () => setState(() => _selectedColor = color),
            ),
          _RailTool(
            icon: Icons.undo_rounded,
            tooltip: s.t('undo'),
            compact: true,
            onTap: _busy ? null : () => _run(widget.session.undo),
          ),
          _RailTool(
            icon: Icons.delete_sweep_outlined,
            tooltip: s.t('clear'),
            compact: true,
            onTap: _busy ? null : () => _run(widget.session.clear),
          ),
        ],
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  const _PageTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: RealtimeUiTokens.animFast,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? style.surfaceSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? style.border : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? style.text : style.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.percent,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
  });
  final int percent;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom out',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded),
          ),
          InkWell(
            onTap: onReset,
            child: SizedBox(
              width: 42,
              child: Text(
                '$percent%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: style.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zoom in',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _RailTool extends StatelessWidget {
  const _RailTool({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final size = compact ? 34.0 : 40.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 1 : 8,
            vertical: compact ? 2 : 3,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: AnimatedContainer(
              duration: RealtimeUiTokens.animFast,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: selected ? style.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? style.onAccent : style.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? style.text : style.border,
              width: selected ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(
      width: 24,
      height: 1,
      child: ColoredBox(color: RealtimeStyle.of(context).border),
    ),
  );
}
