import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'room_ui_controller.dart';

class RealtimeLiveLikeButton extends StatelessWidget {
  const RealtimeLiveLikeButton({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.liveInteractions == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pending = controller.isPending(RealtimeRoomUiAction.liveLike);
        final likes = controller.liveState?.totalLikes ?? 0;
        final isZh = RealtimeStrings.of(context).isZh;

        Future<void> sendLike() async {
          try {
            await controller.sendLiveLike();
          } catch (error) {
            if (context.mounted) {
              controller.reportActionError(error);
            }
          }
        }

        if (iconOnly) {
          return Tooltip(
            message: '${isZh ? '点赞' : 'Like'} $likes',
            child: InkWell(
              onTap: pending ? null : sendLike,
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB82443),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.favorite_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    if (likes > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        likes > 999 ? '999+' : '$likes',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB82443),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            disabledBackgroundColor: const Color(
              0xFFB82443,
            ).withValues(alpha: .65),
            disabledForegroundColor: Colors.white70,
          ),
          onPressed: pending ? null : sendLike,
          icon: pending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.favorite_rounded),
          label: Text('${isZh ? '点赞' : 'Like'} $likes'),
        );
      },
    );
  }
}

/// Optional live status chip: caller decides where it sits in the page.
