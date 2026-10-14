part of '../flutter_realtime_design_ui.dart';

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
    final radius = RealtimeUiThemeExtension.of(context).controlRadius;
    return RealtimeGlassPressable(
      borderRadius: radius,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: style.danger,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
