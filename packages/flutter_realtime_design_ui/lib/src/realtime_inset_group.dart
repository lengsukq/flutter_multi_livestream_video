part of '../flutter_realtime_design_ui.dart';

class RealtimeInsetGroup extends StatelessWidget {
  const RealtimeInsetGroup({
    super.key,
    required this.children,
    this.margin,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final isDark = RealtimeStyle.of(context).isDark;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                header!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: RealtimeUiTokens.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          RealtimeCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Text(
                footer!,
                style: const TextStyle(
                  fontSize: 13,
                  color: RealtimeUiTokens.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
