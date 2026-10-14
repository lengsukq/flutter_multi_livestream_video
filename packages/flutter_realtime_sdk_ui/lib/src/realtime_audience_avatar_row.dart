import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

import 'room_ui_controller.dart';

/// An Apple-styled online audience avatar row with stacked circles and a total count badge.
/// Designed for live broadcast stages (both desktop and mobile HUD).
class RealtimeAudienceAvatarRow extends StatelessWidget {
  const RealtimeAudienceAvatarRow({
    super.key,
    this.maxAvatars = 4,
    this.avatarSize = 32.0,
    this.overlap = 8.0,
    this.onViewAll,
    this.onVideo = false,
  });

  final int maxAvatars;
  final double avatarSize;
  final double overlap;
  final VoidCallback? onViewAll;
  final bool onVideo;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final participants = controller.snapshot.participants
            .where((p) => !p.isLocal)
            .toList();
        final totalCount = controller.snapshot.participants.length;
        final displayList = participants.take(maxAvatars).toList();

        return InkWell(
          onTap: onViewAll,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.radiusPill),
          child: Container(
            constraints: BoxConstraints(minHeight: onViewAll == null ? 40 : 48),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: onVideo
                  ? Colors.transparent
                  : isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(RealtimeUiTokens.radiusPill),
              border: onVideo
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onVideo && displayList.isEmpty) ...[
                  const Icon(
                    Icons.people_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                ],
                if (displayList.isNotEmpty)
                  SizedBox(
                    height: avatarSize,
                    width:
                        avatarSize +
                        (displayList.length - 1) * (avatarSize - overlap),
                    child: Stack(
                      children: [
                        for (int i = 0; i < displayList.length; i++)
                          Positioned(
                            left: i * (avatarSize - overlap),
                            child: _AvatarCircle(
                              participant: displayList[i],
                              size: avatarSize,
                              borderColor: isDark
                                  ? const Color(0xFF1E2430)
                                  : Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (displayList.isNotEmpty) const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$totalCount',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: onVideo || isDark
                          ? Colors.white
                          : RealtimeUiTokens.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (onViewAll != null) ...[
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: onVideo || isDark ? Colors.white60 : Colors.black45,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.participant,
    required this.size,
    required this.borderColor,
  });

  final MediaParticipant participant;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final name = participant.displayName.isNotEmpty
        ? participant.displayName
        : participant.id;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: RealtimeAvatar(
          name: name,
          avatarUrl: participant.avatarUrl,
          size: size - 3,
        ),
      ),
    );
  }
}
