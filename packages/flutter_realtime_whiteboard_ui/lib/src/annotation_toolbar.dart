import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'color_picker_dialog.dart';
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
    this.showDrawingToggle = true,
    this.compact = false,
    this.fixedTop = false,
    this.selectedColor,
    this.onColorChanged,
    this.availableColors,
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
  final bool showDrawingToggle;
  final bool compact;
  final bool fixedTop;
  final int? selectedColor;
  final ValueChanged<int>? onColorChanged;
  final List<int>? availableColors;

  static const defaultColors = <int>[
    0xff1e293b, // slate dark
    0xff2563eb, // blue
    0xffdc2626, // red
    0xfff59e0b, // amber
    0xff16a34a, // green
  ];

  @override
  Widget build(BuildContext context) {
    final s = WhiteboardStrings.of(context);
    final theme = Theme.of(context);
    final showTools = drawingEnabled || fixedTop;
    final borderRadius = BorderRadius.circular(fixedTop ? 16 : 20);

    Widget divider() => Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: theme.colorScheme.surface.withValues(
            alpha: fixedTop ? .94 : .88,
          ),
          elevation: fixedTop ? 3 : 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fixedTop ? 8 : 6,
              vertical: 4,
            ),
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
                if (showDrawingToggle)
                  IconButton(
                    tooltip: editTooltip ?? s.t('annotate'),
                    isSelected: drawingEnabled,
                    onPressed: canEdit ? onDrawingToggle : null,
                    icon: Icon(
                      drawingEnabled
                          ? Icons.draw_outlined
                          : Icons.pan_tool_outlined,
                    ),
                  ),
                if (showTools) ...[
                  if (showDrawingToggle || showDragHandle) divider(),
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
                  if (onColorChanged != null) ...[
                    divider(),
                    for (final c in (availableColors ?? defaultColors))
                      Tooltip(
                        message: s.t('color'),
                        child: InkWell(
                          onTap: canEdit ? () => onColorChanged!(c) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == c
                                      ? (theme.brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87)
                                      : Colors.transparent,
                                  width: selectedColor == c ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  if (selectedColor == c)
                                    BoxShadow(
                                      color: Color(c).withValues(alpha: 0.45),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: s.t('moreColors'),
                      iconSize: 18,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: const EdgeInsets.all(4),
                      onPressed: canEdit
                          ? () {
                              unawaited(
                                showWhiteboardColorPicker(
                                  context,
                                  initialColor:
                                      selectedColor ?? defaultColors.first,
                                ).then((color) {
                                  if (color != null) onColorChanged!(color);
                                }),
                              );
                            }
                          : null,
                      icon: Icon(
                        Icons.palette_outlined,
                        color:
                            selectedColor != null &&
                                !(availableColors ?? defaultColors).contains(
                                  selectedColor,
                                )
                            ? Color(selectedColor!)
                            : null,
                      ),
                    ),
                  ],
                  if (onUndo != null || onClear != null) divider(),
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
                if (onClose != null && canClose) ...[
                  divider(),
                  IconButton(
                    tooltip: s.t('close'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
