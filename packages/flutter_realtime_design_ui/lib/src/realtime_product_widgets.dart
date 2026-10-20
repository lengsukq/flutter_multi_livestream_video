part of '../flutter_realtime_design_ui.dart';

/// Small uppercase-ish section label used above rosters and agendas.
class RealtimeSectionHeader extends StatelessWidget {
  const RealtimeSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: style.speakStrong,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

enum RealtimeStatusTone { live, recording, neutral, positive }

/// Compact status capsule: LIVE, recording, elapsed time or a plain chip.
class RealtimeStatusPill extends StatelessWidget {
  const RealtimeStatusPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = RealtimeStatusTone.neutral,
    this.showDot = false,
    this.blink = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final RealtimeStatusTone tone;
  final bool showDot;

  /// Kept for source compatibility. Status dots are static: an endless
  /// animation prevents `pumpAndSettle` from converging in widget tests and
  /// adds motion noise next to a label that already says LIVE/REC.
  final bool blink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final (background, foreground, border) = switch (tone) {
      RealtimeStatusTone.live => (style.live, Colors.white, Colors.transparent),
      RealtimeStatusTone.recording => (
        Colors.transparent,
        style.live,
        style.live,
      ),
      RealtimeStatusTone.positive => (
        style.successSubtle,
        style.speakStrong,
        style.successBorder,
      ),
      RealtimeStatusTone.neutral => (
        style.surface.withValues(alpha: .82),
        style.text,
        style.border,
      ),
    };
    final toneColor = switch (tone) {
      RealtimeStatusTone.live => Colors.white,
      RealtimeStatusTone.recording => style.live,
      RealtimeStatusTone.positive => style.speak,
      RealtimeStatusTone.neutral => style.textMuted,
    };
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: toneColor, shape: BoxShape.circle),
    );

    final content = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(
          color: border,
          width: tone == RealtimeStatusTone.recording ? 1 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[dot, const SizedBox(width: 6)],
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return RealtimeGlassPressable(
      onTap: onTap!,
      borderRadius: RealtimeUiTokens.pillRadius,
      child: content,
    );
  }
}

/// Whiteboard / notebook paper: white surface, light grid, soft border.
class RealtimeBoardSurface extends StatelessWidget {
  const RealtimeBoardSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.gridSize = 24,
    this.showGrid = true,
    this.radius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double gridSize;
  final bool showGrid;
  final double? radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final effectiveRadius =
        radius ?? RealtimeUiThemeExtension.of(context).stageRadius;
    Widget surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: style.board,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(color: style.border),
        boxShadow: style.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: showGrid
            ? CustomPaint(
                painter: _BoardGridPainter(
                  color: style.boardGrid,
                  step: gridSize,
                ),
                child: child,
              )
            : child,
      ),
    );
    if (onTap != null) {
      surface = RealtimeGlassPressable(
        onTap: onTap!,
        borderRadius: effectiveRadius,
        child: surface,
      );
    }
    return surface;
  }
}

class _BoardGridPainter extends CustomPainter {
  const _BoardGridPainter({required this.color, required this.step});
  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_BoardGridPainter oldDelegate) =>
      color != oldDelegate.color || step != oldDelegate.step;
}

/// Level meter for a real audio stream.
///
/// [level] is 0..1. When the host has no level source, pass `null` and the
/// widget renders nothing: the SDK never fabricates fake input activity.
class RealtimeMeter extends StatelessWidget {
  const RealtimeMeter({
    super.key,
    required this.level,
    this.bars = 16,
    this.height = 8,
    this.activeColor,
  });

  final double? level;
  final int bars;
  final double height;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final value = level;
    if (value == null) return const SizedBox.shrink();
    final style = RealtimeStyle.of(context);
    final lit = (value.clamp(0.0, 1.0) * bars).round();
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < bars; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == bars - 1 ? 0 : 3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i < lit
                        ? (activeColor ?? style.speak)
                        : style.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
