part of 'realtime_ui_style.dart';

/// Reusable frosted glass card for displaying an active room in a discovery
/// list.
class RealtimeRoomCard extends StatelessWidget {
  const RealtimeRoomCard({super.key, required this.room, required this.onJoin});

  final MediaRoomSummary room;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isBroadcast = room.roomMode == MediaRoomMode.broadcast;
    final strings = RealtimeStrings.of(context);
    final modeLabel = isBroadcast ? strings.live : strings.meeting;

    return RealtimeGlassSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: RealtimeUiTokens.controlRadius,
      opacity: 0.84,
      blur: RealtimeUiTokens.subtleBlur,
      onTap: onJoin,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isBroadcast
                  ? (style.isDark
                        ? const Color(0xFF3B1219)
                        : const Color(0xFFFFF1F2))
                  : style.primarySubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(
                color: isBroadcast
                    ? (style.isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFECDD3))
                    : style.primaryBorder,
              ),
            ),
            child: Icon(
              isBroadcast ? Icons.podcasts_rounded : Icons.groups_2_rounded,
              size: 20,
              color: isBroadcast
                  ? (style.isDark
                        ? const Color(0xFFFB7185)
                        : const Color(0xFFE11D48))
                  : style.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.roomCode,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  strings.roomCardSummary(modeLabel, room.attendeeCount),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: style.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              backgroundColor: isBroadcast
                  ? const Color(0xFFE11D48)
                  : style.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.pillRadius,
                ),
              ),
            ),
            child: Text(
              isBroadcast ? strings.watchLive : strings.join,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted glass modal dialog with large rounded corners (`32.0`) and Gaussian
/// backdrop blur.
class RealtimeGlassDialog extends StatelessWidget {
  const RealtimeGlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.iconColor = RealtimeUiTokens.primary,
    this.iconBackground = RealtimeUiTokens.primarySubtle,
    this.actions = const [],
    this.maxWidth = 480,
  });

  final Widget title;
  final Widget content;
  final IconData? icon;
  final Color iconColor;
  final Color iconBackground;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RealtimeGlassSurface(
        radius: RealtimeUiTokens.sheetRadius,
        opacity: 0.92,
        blur: RealtimeUiTokens.blur,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: RealtimeStyle.of(context).text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    child: title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(child: content),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Presents a frosted glass modal bottom sheet with `32.0` top corners and a
/// glass pill drag handle.
Future<T?> showRealtimeGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  backgroundColor: Colors.transparent,
  barrierColor:
      (Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : const Color(0xFF0F172A))
          .withValues(alpha: 0.40),
  elevation: 0,
  builder: (sheetContext) {
    final style = RealtimeStyle.of(sheetContext);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RealtimeUiTokens.sheetRadius),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.surface,
            gradient: style.glassGradient,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RealtimeUiTokens.sheetRadius),
            ),
            border: Border(top: BorderSide(color: style.border, width: 1.4)),
            boxShadow: style.cardShadow,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 10),
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: style.borderStrong,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.pillRadius,
                      ),
                    ),
                  ),
                ),
                Flexible(child: builder(sheetContext)),
              ],
            ),
          ),
        ),
      ),
    );
  },
);

class RealtimeSheetHeader extends StatelessWidget {
  const RealtimeSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.admin_panel_settings_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: style.primarySubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            border: Border.all(color: style.primaryBorder),
          ),
          child: Icon(icon, color: style.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: style.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: style.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class RealtimeDangerButton extends StatelessWidget {
  const RealtimeDangerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.controlRadius,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: style.danger,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
