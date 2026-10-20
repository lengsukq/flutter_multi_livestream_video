part of '../flutter_realtime_design_ui.dart';

class RealtimeBadge extends StatelessWidget {
  const RealtimeBadge({
    super.key,
    required this.text,
    this.color,
    this.backgroundColor,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  final String text;
  final Color? color;
  final Color? backgroundColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final fg = color ?? style.onAccent;
    final bg = backgroundColor ?? style.accent;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          height: 1.2,
        ),
      ),
    );
  }
}
