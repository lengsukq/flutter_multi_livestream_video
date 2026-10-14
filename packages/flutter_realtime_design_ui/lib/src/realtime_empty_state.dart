part of '../flutter_realtime_design_ui.dart';

class RealtimeEmptyState extends StatelessWidget {
  const RealtimeEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = RealtimeStyle.of(context).isDark;
    final primary = iconColor ?? RealtimeUiTokens.iosBlue;

    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28, color: primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: RealtimeUiTokens.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
