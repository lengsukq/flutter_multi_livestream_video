import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'annotation_surface.dart';
import 'whiteboard_strings.dart';

/// Independent view: no media, chat or classroom session is required.
/// The host owns and disposes the session. Students follow its active page.
class WhiteboardView extends StatefulWidget {
  const WhiteboardView({super.key, required this.session});
  final WhiteboardSession session;
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
      return Column(
        children: [
          Material(
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: state.activePageId,
                    items: state.pages
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.title),
                          ),
                        )
                        .toList(),
                    onChanged: state.canEdit && !_busy
                        ? (id) => _run(() => widget.session.selectPage(id!))
                        : null,
                  ),
                ),
                Text(
                  '${state.pages.indexWhere((p) => p.id == state.activePageId) + 1}/${state.pages.length}',
                ),
                if (state.canEdit) ...[
                  IconButton(
                    tooltip: s.t('addPage'),
                    onPressed: !_busy && state.pages.length < state.maxPages
                        ? () => _run(
                            () => widget.session.addPage(
                              title: s.zh
                                  ? '第 ${state.pages.length + 1} 页'
                                  : 'Page ${state.pages.length + 1}',
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.note_add_outlined),
                  ),
                  IconButton(
                    tooltip: s.t('deletePage'),
                    onPressed: !_busy && state.pages.length > 1
                        ? () => _run(
                            () => widget.session.deletePage(state.activePageId),
                          )
                        : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null)
            Text(
              '$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRect(
                  child: AnnotationSurface(
                    key: ValueKey(state.canvas.canvasId),
                    session: widget.session,
                    background: const ColoredBox(color: Colors.white),
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
