part of '../flutter_realtime_design_ui.dart';

/// A quiet trailing action for an inline text field (paste, generate, etc.).
///
/// Intentionally avoids the outlined/colored [RealtimePill] treatment, which
/// belongs to status badges and standalone actions rather than text inputs.
class RealtimeFieldAction extends StatelessWidget {
  const RealtimeFieldAction({
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
    final radius = (RealtimeUiThemeExtension.of(context).controlRadius - 6)
        .clamp(0.0, double.infinity);
    final foreground = onPressed == null
        ? style.textMuted.withValues(alpha: .45)
        : style.textMuted;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          excludeFromSemantics: true,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          hoverColor: style.surface.withValues(alpha: .9),
          focusColor: style.surface.withValues(alpha: .9),
          splashColor: style.border.withValues(alpha: .45),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
