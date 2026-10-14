part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassTile extends StatelessWidget {
  const RealtimeGlassTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.margin = const EdgeInsets.only(bottom: 8),
    this._radius,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? _radius;
  double get radius => _radius ?? RealtimeUiTokens.controlRadius;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      margin: margin,
      padding: padding,
      radius: _radius ?? RealtimeUiThemeExtension.of(context).controlRadius,
      opacity: 0.88,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 13,
                      color: style.textMuted,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
