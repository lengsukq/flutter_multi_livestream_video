import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
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
    final style = RealtimeStyle.of(context);
    final showTools = drawingEnabled || fixedTop;
    final borderRadius = BorderRadius.circular(RealtimeUiTokens.controlRadius);

    Widget divider() => Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
    );

    // Selected tools invert to amber, matching the reference teaching toolbar.
    Widget toolButton({
      required IconData icon,
      required String tooltip,
      required bool selected,
      required VoidCallback? onPressed,
    }) => Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? style.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
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

    return ClipRRect(
      borderRadius: borderRadius,
      child: RealtimeGlassSurface(
        radius: RealtimeUiTokens.controlRadius,
        blur: RealtimeUiTokens.subtleBlur,
        shadow: false,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: style.border),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fixedTop ? 6 : 4,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: style.textMuted,
                      ),
                    ),
                  ),
                if (showDrawingToggle)
                  toolButton(
                    icon: drawingEnabled
                        ? Icons.draw_outlined
                        : Icons.pan_tool_outlined,
                    tooltip: editTooltip ?? s.t('annotate'),
                    selected: drawingEnabled,
                    onPressed: canEdit ? onDrawingToggle : null,
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
                    toolButton(
                      icon: item.$2,
                      tooltip: s.t(item.$3),
                      selected: tool == item.$1,
                      onPressed: canEdit && onToolChanged != null
                          ? () => onToolChanged!(item.$1)
                          : null,
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
                        minWidth: 32,
                        minHeight: 32,
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
                            : style.textSecondary,
                      ),
                    ),
                  ],
                  if (onUndo != null || onClear != null) divider(),
                  if (onUndo != null)
                    toolButton(
                      icon: Icons.undo,
                      tooltip: s.t('undo'),
                      selected: false,
                      onPressed: canUndo ? onUndo : null,
                    ),
                  if (onClear != null)
                    toolButton(
                      icon: Icons.delete_sweep_outlined,
                      tooltip: s.t('clear'),
                      selected: false,
                      onPressed: canClear ? onClear : null,
                    ),
                ],
                if (onClose != null && canClose) ...[
                  divider(),
                  toolButton(
                    icon: Icons.close,
                    tooltip: s.t('close'),
                    selected: false,
                    onPressed: onClose,
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
