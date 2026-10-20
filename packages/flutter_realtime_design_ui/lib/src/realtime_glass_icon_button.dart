part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassIconButton extends StatelessWidget {
  const RealtimeGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.danger = false,
    this.badgeCount = 0,
    this.size = 48,
    this._radius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final bool danger;
  final int badgeCount;
  final double size;
  final double? _radius;
  double get radius => _radius ?? RealtimeUiTokens.controlRadius;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final effectiveRadius =
        _radius ?? RealtimeUiThemeExtension.of(context).controlRadius;
    final targetSize = size < 44 ? 44.0 : size;
    final bgColor = danger
        ? style.live
        : active
        ? style.accent
        : style.surfaceSubtle;
    final borderColor = danger
        ? style.live
        : active
        ? style.primaryBorder
        : style.border;
    final fgColor = danger
        ? Colors.white
        : active
        ? style.onAccent
        : style.textSecondary;

    Widget button = RealtimeGlassPressable(
      borderRadius: effectiveRadius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: AnimatedContainer(
            duration: RealtimeUiThemeExtension.of(
              context,
            ).duration(context, RealtimeUiTokens.animNormal),
            curve: Curves.easeOutCubic,
            width: targetSize,
            height: targetSize,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(effectiveRadius),
              border: Border.all(color: borderColor, width: 1.1),
              boxShadow: danger
                  ? [
                      BoxShadow(
                        color: RealtimeUiTokens.danger.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : active
                  ? [
                      BoxShadow(
                        color: style.accent.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 19, color: fgColor),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: RealtimeUiThemeExtension.of(
                        context,
                      ).duration(context, RealtimeUiTokens.animNormal),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: style.live,
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.pillRadius,
                          ),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
