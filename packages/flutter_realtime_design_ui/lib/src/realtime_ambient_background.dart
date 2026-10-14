part of '../flutter_realtime_design_ui.dart';

/// Soft ambient color behind the content and floating glass controls.
class RealtimeAmbientBackground extends StatelessWidget {
  const RealtimeAmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    if (MediaQuery.highContrastOf(context) ||
        !RealtimeUiThemeExtension.of(context).glassEnabled) {
      return ColoredBox(color: style.background, child: child);
    }
    return ColoredBox(
      color: style.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.0, -1.0),
            radius: 1.1,
            colors: [
              style.warningSubtle.withValues(alpha: .45),
              style.warningSubtle.withValues(alpha: 0),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, -0.3),
              radius: 1.25,
              colors: [
                style.surfaceSubtle.withValues(alpha: .4),
                style.surfaceSubtle.withValues(alpha: 0),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, 1.0),
                radius: 1.0,
                colors: [
                  style.successSubtle.withValues(alpha: .35),
                  style.successSubtle.withValues(alpha: 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
