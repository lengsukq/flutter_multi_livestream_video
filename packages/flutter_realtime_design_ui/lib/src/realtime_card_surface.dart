part of '../flutter_realtime_design_ui.dart';

/// Rounded white content card used by panels, lists and the green-room.
class RealtimeCardSurface extends StatelessWidget {
  const RealtimeCardSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this._radius,
    this.shadow = false,
    this.borderColor,
    this.fillColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? _radius;
  double get radius => _radius ?? RealtimeUiTokens.cardRadius;
  final bool shadow;
  final Color? borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final appearance = RealtimeUiThemeExtension.of(context);
    final effectiveRadius = _radius ?? appearance.cardRadius;
    final effectiveFill = fillColor ?? style.surface;
    final effectiveBorder = borderColor ?? style.border;

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: shadow ? style.cardShadow : const [],
      ),
      child: Material(color: Colors.transparent, child: child),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(effectiveRadius),
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            onTap?.call();
          },
          child: content,
        ),
      );
      content = RealtimeGlassPressable(
        borderRadius: effectiveRadius,
        pressedScale: 0.98,
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
