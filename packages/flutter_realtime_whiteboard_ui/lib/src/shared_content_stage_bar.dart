import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'whiteboard_strings.dart';

/// Unified Material 3 / Glassmorphic stage bar for shared content.
///
/// Used identically for Whiteboard and Screen Share stages to give viewers and
/// presenters a consistent, polished header with status, page controls,
/// annotation toggle, and stop sharing action.
class SharedContentStageBar extends StatelessWidget {
  const SharedContentStageBar({
    super.key,
    required this.title,
    this.badgeIcon,
    this.subtitle,
    this.pageIndex,
    this.pageCount,
    this.onPreviousPage,
    this.onNextPage,
    this.onAddPage,
    this.onDeletePage,
    this.canAddPage = false,
    this.canDeletePage = false,
    this.annotationEnabled = false,
    this.onToggleAnnotation,
    this.canAnnotate = true,
    this.onStop,
    this.stopTooltip,
    this.extraActions,
  });

  final String title;
  final IconData? badgeIcon;
  final String? subtitle;

  // Pagination (used in Whiteboard mode)
  final int? pageIndex;
  final int? pageCount;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onAddPage;
  final VoidCallback? onDeletePage;
  final bool canAddPage;
  final bool canDeletePage;

  // Annotation toggle
  final bool annotationEnabled;
  final VoidCallback? onToggleAnnotation;
  final bool canAnnotate;

  // Stop sharing action
  final VoidCallback? onStop;
  final String? stopTooltip;

  final List<Widget>? extraActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = RealtimeStyle.of(context).isDark;
    final appearance = RealtimeUiThemeExtension.of(context);
    final opaque =
        !appearance.glassEnabled || MediaQuery.highContrastOf(context);
    final s = WhiteboardStrings.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(appearance.controlRadius),
      child: BackdropFilter(
        enabled: !opaque,
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(
              alpha: opaque ? 1 : 0.88,
            ),
            borderRadius: BorderRadius.circular(appearance.controlRadius),
            border: Border.all(
              color: (isDark ? Colors.white12 : Colors.black12),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge Icon & Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon ?? Icons.present_to_all_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // Whiteboard Pagination Section
              if (pageCount != null && pageCount! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  height: 18,
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  iconSize: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: s.t('prevPage'),
                  onPressed: onPreviousPage,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${(pageIndex ?? 0) + 1} / $pageCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: s.t('nextPage'),
                  onPressed: onNextPage,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                if (onAddPage != null)
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: s.t('addPage'),
                    onPressed: canAddPage ? onAddPage : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                if (onDeletePage != null)
                  IconButton(
                    iconSize: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: s.t('deletePage'),
                    onPressed: canDeletePage ? onDeletePage : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],

              if (extraActions != null) ...[
                const SizedBox(width: 6),
                ...extraActions!,
              ],

              // Annotation Toggle
              if (onToggleAnnotation != null && canAnnotate) ...[
                const SizedBox(width: 6),
                Container(
                  height: 18,
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  iconSize: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  isSelected: annotationEnabled,
                  tooltip: s.t('annotate'),
                  onPressed: onToggleAnnotation,
                  icon: Icon(
                    annotationEnabled
                        ? Icons.edit_rounded
                        : Icons.edit_outlined,
                  ),
                ),
              ],

              // Stop sharing action
              if (onStop != null) ...[
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFFF3B30,
                    ).withValues(alpha: isDark ? 0.25 : 0.12),
                    foregroundColor: const Color(0xFFFF3B30),
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: stopTooltip ?? s.t('stopSharing'),
                  onPressed: onStop,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
