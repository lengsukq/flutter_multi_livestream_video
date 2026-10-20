part of '../flutter_realtime_design_ui.dart';

/// Flat cool-gray workspace background.
///
/// The reference product keeps the workspace calm: a gray-blue canvas, white
/// content cards and no colored glow behind the controls.
class RealtimeAmbientBackground extends StatelessWidget {
  const RealtimeAmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: RealtimeStyle.of(context).background, child: child);
}
