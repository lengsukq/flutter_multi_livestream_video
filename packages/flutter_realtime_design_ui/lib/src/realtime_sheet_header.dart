part of '../flutter_realtime_design_ui.dart';

class RealtimeSheetHeader extends StatelessWidget {
  const RealtimeSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.admin_panel_settings_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: style.primarySubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            border: Border.all(color: style.primaryBorder),
          ),
          child: Icon(icon, color: style.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: style.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: style.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
