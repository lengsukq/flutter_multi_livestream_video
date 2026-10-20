import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Persistent meeting header with an attached tablet navigation tier.
///
/// Room title and online count on the left, live/recording/timer chips in the
/// middle, attendee avatars and actions on the right. Unlike the previous
/// floating glass header this bar never fades, so the room identity and the
/// leave action are always reachable.
class RealtimeMeetingTopBar extends StatelessWidget {
  const RealtimeMeetingTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeText = 'RT',
    this.centerActions = const [],
    this.trailingActions = const [],
    this.statusWidgets = const [],
    this.leadingActions = const [],
    this.audienceNames = const [],
    this.audienceCount,
    this.onHome,
    this.userAvatarUrl,
    this.userDisplayName,
    this.compact = false,
    this.dense = false,
    this.brand,
    this.inviteAction,
  });
  final String title;
  final String? subtitle;
  final String badgeText;
  final List<Widget> centerActions;
  final List<Widget> trailingActions;

  /// Connection, elapsed-time and recording indicators.
  final List<Widget> statusWidgets;

  /// Actions placed before the title (for example a back button).
  final List<Widget> leadingActions;

  /// Avatar stack shown before the participant count.
  final List<String> audienceNames;
  final int? audienceCount;
  final VoidCallback? onHome;
  final String? userAvatarUrl;
  final String? userDisplayName;
  final bool compact;

  /// Single-line stage overlay; kept for host integrations that pass it.
  final bool dense;

  /// Product mark shown before the room identity.
  final Widget? brand;

  /// Optional labelled invite action on roomy headers.
  final VoidCallback? inviteAction;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Material(
      color: style.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: style.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            // Give accessibility text enough vertical room without making
            // the normal meeting header taller on phones and tablets.
            height: MediaQuery.textScalerOf(context).scale(17) >= 28 ? 84 : 56,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final small =
                    compact ||
                    constraints.maxWidth < 600 ||
                    MediaQuery.textScalerOf(context).scale(17) >= 28;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: small ? 10 : 16),
                  child: Row(
                    children: [
                      ...leadingActions,
                      if (!small && onHome != null)
                        IconButton(
                          tooltip: RealtimeStrings.of(context).isZh
                              ? '首页'
                              : 'Home',
                          onPressed: onHome,
                          icon: const Icon(Icons.home_outlined),
                        ),
                      if (!small && brand != null) ...[
                        brand!,
                        const SizedBox(width: 14),
                        Container(width: 1, height: 26, color: style.border),
                        const SizedBox(width: 14),
                      ],
                      if (constraints.maxWidth >= 600 && brand == null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: style.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: style.border),
                          ),
                          child: Icon(
                            Icons.videocam_outlined,
                            color: style.textSecondary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      // Tight flex: absorbs the free space so trailing
                      // actions stay against the right edge instead of
                      // floating mid-bar when text is short.
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (small &&
                                constraints.maxWidth >= 600 &&
                                MediaQuery.textScalerOf(context).scale(17) < 28)
                              Text(
                                RealtimeStrings.of(context).isZh
                                    ? '会议房间'
                                    : 'Meeting room',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: style.textMuted,
                                ),
                              ),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: RealtimeFonts.displayOf(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: style.text,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: style.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (statusWidgets.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        // Tight flex: a loose slot would leave dead space
                        // between the chips and the trailing actions.
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final status in statusWidgets)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: status,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (!small && centerActions.isNotEmpty) ...[
                        ...centerActions,
                        const SizedBox(width: 8),
                      ],
                      if (!small && audienceNames.isNotEmpty) ...[
                        RealtimeAvatarStack(
                          names: audienceNames,
                          size: 28,
                          maxVisible: 4,
                        ),
                        if (audienceCount != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            RealtimeStrings.of(context).isZh
                                ? '${audienceCount!} 人'
                                : '${audienceCount!} people',
                            style: TextStyle(
                              fontSize: 12,
                              color: style.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                      ],
                      if (!small && inviteAction != null) ...[
                        const SizedBox(width: 8),
                        _InviteButton(onPressed: inviteAction!),
                        const SizedBox(width: 4),
                      ],
                      ...trailingActions,
                      if (!small &&
                          (userDisplayName != null ||
                              userAvatarUrl != null)) ...[
                        const SizedBox(width: 6),
                        RealtimeAvatar(
                          name: userDisplayName ?? '',
                          avatarUrl: userAvatarUrl,
                          size: 32,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Semantics(
      button: true,
      label: RealtimeStrings.of(context).isZh ? '邀请' : 'Invite',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          onTap: onPressed,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
              border: Border.all(color: style.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 16,
                  color: style.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  RealtimeStrings.of(context).isZh ? '邀请' : 'Invite',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
