part of '../flutter_realtime_design_ui.dart';

class RealtimeCupertinoSwitchRow extends StatelessWidget {
  const RealtimeCupertinoSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.statusWidget,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? statusWidget;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.w600),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                          color: RealtimeUiTokens.textMuted,
                          fontSize: 13,
                        ) ??
                        const TextStyle(
                          fontSize: 13,
                          color: RealtimeUiTokens.textMuted,
                        ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (statusWidget != null) ...[
            statusWidget!,
            const SizedBox(width: 8),
          ],
          CupertinoSwitch(
            value: value,
            activeTrackColor: RealtimeStyle.of(context).primary,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
