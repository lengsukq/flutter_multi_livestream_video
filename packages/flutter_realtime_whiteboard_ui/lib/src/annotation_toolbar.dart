import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'whiteboard_strings.dart';

/// Unified Material 3 toolbar widget for screen annotations and whiteboard.
///
/// Shared across classroom in-app surfaces and system-level cross-app overlays.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.tool,
    this.onToolChanged,
    this.drawingEnabled = true,
    this.onDrawingToggle,
    this.onUndo,
    this.onClear,
    this.onClose,
    this.canEdit = true,
    this.canUndo = true,
    this.canClear = true,
    this.canClose = true,
    this.editTooltip,
    this.showDragHandle = true,
    this.compact = false,
  });

  final AnnotationTool tool;
  final ValueChanged<AnnotationTool>? onToolChanged;
  final bool drawingEnabled;
  final VoidCallback? onDrawingToggle;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback? onClose;
  final bool canEdit;
  final bool canUndo;
  final bool canClear;
  final bool canClose;
  final String? editTooltip;
  final bool showDragHandle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = WhiteboardStrings.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: .94),
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showDragHandle)
              Tooltip(
                message: s.t('moveTools'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(Icons.drag_indicator, size: 20),
                ),
              ),
            IconButton(
              tooltip: editTooltip ?? s.t('annotate'),
              isSelected: drawingEnabled,
              onPressed: canEdit ? onDrawingToggle : null,
              icon: Icon(
                drawingEnabled ? Icons.draw_outlined : Icons.pan_tool_outlined,
              ),
            ),
            if (drawingEnabled) ...[
              for (final item in const <(AnnotationTool, IconData, String)>[
                (AnnotationTool.pen, Icons.edit, 'pen'),
                (AnnotationTool.highlight, Icons.highlight, 'highlight'),
                (AnnotationTool.circle, Icons.circle_outlined, 'circle'),
                (AnnotationTool.arrow, Icons.arrow_outward, 'arrow'),
                (AnnotationTool.text, Icons.text_fields, 'label'),
              ])
                IconButton(
                  tooltip: s.t(item.$3),
                  isSelected: tool == item.$1,
                  onPressed: canEdit && onToolChanged != null
                      ? () => onToolChanged!(item.$1)
                      : null,
                  icon: Icon(item.$2),
                ),
              if (onUndo != null)
                IconButton(
                  tooltip: s.t('undo'),
                  onPressed: canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
              if (onClear != null)
                IconButton(
                  tooltip: s.t('clear'),
                  onPressed: canClear ? onClear : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
            if (onClose != null && canClose)
              IconButton(
                tooltip: s.t('close'),
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
