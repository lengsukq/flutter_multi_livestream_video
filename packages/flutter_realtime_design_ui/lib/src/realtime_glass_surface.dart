part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassSurface extends StatelessWidget {
  const RealtimeGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this._radius,
    this._opacity,
    this._blur,
    this.shadow = true,
    this.borderColor = RealtimeUiTokens.border,
    this.fillColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? _radius;
  final double? _opacity;
  final double? _blur;
  double get radius => _radius ?? RealtimeUiTokens.cardRadius;
  double get opacity => _opacity ?? .82;
  double get blur => _blur ?? RealtimeUiTokens.subtleBlur;
  final bool shadow;
  final Color borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final appearance = RealtimeUiThemeExtension.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final opaque = highContrast || !appearance.glassEnabled;
    final effectiveRadius = _radius ?? appearance.cardRadius;
    final effectiveBlur = opaque ? 0.0 : _blur ?? appearance.blur;
    final effectiveOpacity = opaque ? 1.0 : _opacity ?? appearance.glassOpacity;

    Widget content = Container(
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: (fillColor ?? style.surface).withValues(alpha: effectiveOpacity),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: highContrast
              ? style.text
              : borderColor == RealtimeUiTokens.border
              ? Colors.white.withValues(alpha: 0.8)
              : borderColor,
          width: highContrast ? 1.5 : 1.0,
        ),
        boxShadow: shadow ? style.cardShadow : const [],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(effectiveRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    Widget surface = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: effectiveBlur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: content,
              )
            : content,
      ),
    );

    if (onTap != null) {
      surface = RealtimeGlassPressable(
        borderRadius: effectiveRadius,
        pressedScale: 0.98,
        child: surface,
      );
    }

    return surface;
  }
}
