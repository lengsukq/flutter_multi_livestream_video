import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';

import 'room_ui_controller.dart';
import 'room_media_components.dart';

/// Only renders the broadcaster; audience members are roster entries.
class RealtimeLiveVideoStage extends StatelessWidget {
  const RealtimeLiveVideoStage({super.key, this.placeholder});

  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final members = snapshot.participants;
        final localHost = controller.room.media.role == MediaRole.host;
        final MediaParticipant? host = localHost
            ? (members.where((p) => p.isLocal).firstOrNull ??
                  members
                      .where((p) => p.id == snapshot.localParticipantId)
                      .firstOrNull ??
                  MediaParticipant(
                    id: controller.room.media.participantId,
                    displayName: controller.room.media.participantId,
                    isLocal: true,
                    isVideoEnabled: snapshot.localVideoEnabled,
                  ))
            : (members
                      .where(
                        (p) =>
                            !p.isLocal &&
                            (p.isVideoEnabled || p.videoTrack != null),
                      )
                      .firstOrNull ??
                  members.where((p) => !p.isLocal).firstOrNull);
        return host == null
            ? (placeholder ??
                  const Center(
                    child: Icon(Icons.videocam_off_outlined, size: 56),
                  ))
            : RealtimeVideoTile(key: ValueKey(host.id), participant: host);
      },
    );
  }
}

/// A short floating chat feed for live broadcasts. No room layout is imposed.
/// The same chat messages are available separately in RealtimeChatPanel.
class RealtimeLiveChatFeed extends StatelessWidget {
  const RealtimeLiveChatFeed({super.key, this.maxMessages = 5});

  final int maxMessages;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.chat == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.messages;
        final count = messages.length < maxMessages
            ? messages.length
            : maxMessages;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var index = messages.length - count;
              index < messages.length;
              index++
            )
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${messages[index].displayName.isEmpty ? messages[index].userId : messages[index].displayName}: ${messages[index].message}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Live gift control usable in a toolbar, side panel or floating overlay.
/// The provider-neutral SDK session retains gift retry/idempotency semantics.
class RealtimeLiveGiftButton extends StatelessWidget {
  const RealtimeLiveGiftButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final session = RealtimeRoomUiScope.of(context).room.liveInteractions;
    if (session == null) return const SizedBox.shrink();
    return LiveGiftControlButton(
      key: ObjectKey(session),
      session: session,
      showLabel: showLabel,
    );
  }
}

/// A live gift ticker without any fixed Stack position.
class RealtimeLiveGiftBanner extends StatelessWidget {
  const RealtimeLiveGiftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = RealtimeRoomUiScope.of(context).room.liveInteractions;
    return session == null
        ? const SizedBox.shrink()
        : LiveGiftBanner(key: ObjectKey(session), session: session);
  }
}

/// Like counter and send button. Shared controller prevents duplicate sends.
class RealtimeLiveLikeButton extends StatelessWidget {
  const RealtimeLiveLikeButton({super.key});

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
        return FilledButton.tonalIcon(
          onPressed: pending
              ? null
              : () async {
                  try {
                    await controller.sendLiveLike();
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                },
          icon: pending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.favorite_rounded),
          label: Text(
            '${RealtimeStrings.of(context).isZh ? '点赞' : 'Like'} $likes',
          ),
        );
      },
    );
  }
}

/// Optional live status chip: caller decides where it sits in the page.
class RealtimeLiveStatus extends StatelessWidget {
  const RealtimeLiveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isViewer = controller.room.media.role == MediaRole.viewer;
        return Chip(
          avatar: Icon(
            isViewer ? Icons.visibility_outlined : Icons.sensors,
            size: 16,
          ),
          label: Text(
            '${isViewer ? (strings.isZh ? '观看中' : 'Watching') : strings.liveStatus} · ${controller.snapshot.participants.length}',
          ),
        );
      },
    );
  }
}

/// Displays a short-lived heart for each confirmed live-like update.
/// Animations belong to this widget, while one shared controller owns events.
class RealtimeLiveHeartsOverlay extends StatelessWidget {
  const RealtimeLiveHeartsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.liveInteractions == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 1100),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.8),
              end: const Offset(0, -1.5),
            ).animate(animation),
            child: child,
          ),
        ),
        child: controller.receivedLikeCount == 0
            ? const SizedBox.shrink(key: ValueKey(0))
            : Icon(
                Icons.favorite,
                key: ValueKey(controller.receivedLikeCount),
                color: Colors.pinkAccent,
                size: 32,
              ),
      ),
    );
  }
}
