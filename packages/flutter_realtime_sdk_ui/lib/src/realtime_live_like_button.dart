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
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(error.toString())));
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
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFFFF5252)],
                  ),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
