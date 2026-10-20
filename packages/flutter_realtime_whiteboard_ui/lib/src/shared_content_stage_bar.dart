import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'whiteboard_strings.dart';

/// Opaque teal sharing status bar with accessible labels and actions.
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
    final style = RealtimeStyle.of(context);
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(primary: Colors.white),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
    final strings = WhiteboardStrings.of(context);
    Widget action(
      IconData icon,
      String label,
      VoidCallback? callback, {
      bool selected = false,
    }) => IconButton(
      tooltip: label,
      onPressed: callback,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        backgroundColor: selected
            ? Colors.white.withValues(alpha: .18)
            : Colors.transparent,
      ),
      icon: Icon(icon, size: 18),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.speakStrong,
        borderRadius: BorderRadius.circular(
          RealtimeUiThemeExtension.of(context).controlRadius,
        ),
        border: MediaQuery.highContrastOf(context)
            ? Border.all(color: Colors.white)
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480 ||
              RealtimeBreakpoints.textScaleIsLarge(context)) {
            return _compactBar(context, strings, theme);
          }
          return Row(
            children: [
              Icon(
                badgeIcon ?? Icons.present_to_all_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (pageCount != null && pageCount! > 0) ...[
                action(
                  Icons.chevron_left_rounded,
                  strings.t('prevPage'),
                  onPreviousPage,
                ),
                Text(
                  '${(pageIndex ?? 0) + 1} / $pageCount',
                  style: theme.textTheme.bodySmall,
                ),
                action(
                  Icons.chevron_right_rounded,
                  strings.t('nextPage'),
                  onNextPage,
                ),
                if (onAddPage != null)
                  action(
                    Icons.add_circle_outline_rounded,
                    strings.t('addPage'),
                    canAddPage ? onAddPage : null,
                  ),
                if (onDeletePage != null)
                  action(
                    Icons.delete_outline_rounded,
                    strings.t('deletePage'),
                    canDeletePage ? onDeletePage : null,
                  ),
              ],
              ...?extraActions,
              if (onToggleAnnotation != null && canAnnotate)
                action(
                  annotationEnabled ? Icons.edit_rounded : Icons.edit_outlined,
                  strings.t('annotate'),
                  onToggleAnnotation,
                  selected: annotationEnabled,
                ),
              if (onStop != null)
                Tooltip(
                  message: stopTooltip ?? strings.t('stopSharing'),
                  child: TextButton.icon(
                    onPressed: onStop,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: .14),
                    ),
                    icon: const Icon(Icons.square_rounded, size: 13),
                    label: Text(stopTooltip ?? strings.t('stopSharing')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _compactBar(
    BuildContext context,
    WhiteboardStrings s,
    ThemeData theme,
  ) {
    final actions = <({String title, VoidCallback? action})>[
      if (pageCount != null && pageCount! > 0) ...[
        (title: s.t('prevPage'), action: onPreviousPage),
        (title: s.t('nextPage'), action: onNextPage),
        if (onAddPage != null)
          (title: s.t('addPage'), action: canAddPage ? onAddPage : null),
        if (onDeletePage != null)
          (
            title: s.t('deletePage'),
            action: canDeletePage ? onDeletePage : null,
          ),
      ],
      if (onToggleAnnotation != null && canAnnotate)
        (title: s.t('annotate'), action: onToggleAnnotation),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              badgeIcon ?? Icons.present_to_all_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (pageCount != null && pageCount! > 0)
                    Text(
                      '${(pageIndex ?? 0) + 1} / $pageCount',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              PopupMenuButton<VoidCallback>(
                iconColor: Colors.white,
                tooltip: s.zh ? '共享内容操作' : 'Shared content actions',
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  for (final item in actions)
                    PopupMenuItem<VoidCallback>(
                      value: item.action,
                      enabled: item.action != null,
                      child: Text(item.title),
                    ),
                ],
              ),
            if (onStop != null)
              IconButton(
                tooltip: stopTooltip ?? s.t('stopSharing'),
                onPressed: onStop,
                color: Colors.white,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        if (extraActions != null) Wrap(children: extraActions!),
      ],
    );
  }
}
