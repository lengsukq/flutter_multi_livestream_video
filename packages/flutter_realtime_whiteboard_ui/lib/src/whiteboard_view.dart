import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'annotation_surface.dart';
import 'shared_content_stage_bar.dart';
import 'whiteboard_strings.dart';

/// Independent view: no media, chat or classroom session is required.
/// The host owns and disposes the session. Students follow its active page.
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
      final hasPrev = activeIndex > 0;
      final hasNext = activeIndex >= 0 && activeIndex < state.pages.length - 1;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: SharedContentStageBar(
              title: s.t('whiteboard'),
              badgeIcon: Icons.draw_outlined,
              pageIndex: activeIndex >= 0 ? activeIndex : 0,
              pageCount: state.pages.length,
              onPreviousPage: state.canEdit && !_busy && hasPrev
                  ? () => _run(
                      () => widget.session.selectPage(
                        state.pages[activeIndex - 1].id,
                      ),
                    )
                  : null,
              onNextPage: state.canEdit && !_busy && hasNext
                  ? () => _run(
                      () => widget.session.selectPage(
                        state.pages[activeIndex + 1].id,
                      ),
                    )
                  : null,
              onAddPage: state.canEdit
                  ? () => _run(
                      () => widget.session.addPage(
                        title: s.zh
                            ? '第 ${state.pages.length + 1} 页'
                            : 'Page ${state.pages.length + 1}',
                      ),
                    )
                  : null,
              canAddPage: !_busy && state.pages.length < state.maxPages,
              onDeletePage: state.canEdit
                  ? () => _run(
                      () => widget.session.deletePage(state.activePageId),
                    )
                  : null,
              canDeletePage: !_busy && state.pages.length > 1,
              onStop: widget.onStop,
            ),
          ),
          if (_error != null)
            Text(
              '$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnnotationSurface(
                        key: ValueKey(state.canvas.canvasId),
                        session: widget.session,
                        background: const ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
