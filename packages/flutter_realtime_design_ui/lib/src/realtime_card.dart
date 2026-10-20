part of '../flutter_realtime_design_ui.dart';

class RealtimeCard extends StatelessWidget {
  const RealtimeCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this._radius,
    this.color,
    this.borderColor,
    this.shadow,
    this.clipContent = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? _radius;
  double get radius => _radius ?? 20;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final appearance = RealtimeUiThemeExtension.of(context);
    final effectiveRadius = _radius ?? appearance.cardRadius;
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? style.surface,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(color: borderColor ?? style.border, width: 0.5),
        boxShadow: shadow ?? const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
        child: Material(
          color: Colors.transparent,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );

    return card;
  }
}
