import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';

import 'room_ui_controller.dart';

/// Independently placeable room title; contains no AppBar or navigation.
class RealtimeRoomInfo extends StatelessWidget {
  const RealtimeRoomInfo({super.key, this.style});
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return Text(controller.room.roomCode, style: style);
  }
}

/// Connection status that can be placed beside the title or over the video.
///
/// Renders as a [RealtimePill] so it matches the surrounding glassmorphic
/// header instead of the default Material chip, with a localized label.
class RealtimeConnectionIndicator extends StatelessWidget {
  const RealtimeConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.snapshot.state;
        final strings = RealtimeStrings.of(context);
        final (foreground, background, border, dot) = switch (state) {
          MediaSessionState.connected => (
            const Color(0xFF059669),
            const Color(0xFF10B981).withValues(alpha: 0.15),
            const Color(0xFF10B981).withValues(alpha: 0.35),
            const Color(0xFF10B981),
          ),
          MediaSessionState.connecting ||
          MediaSessionState.joining ||
          MediaSessionState.reconnecting ||
          MediaSessionState.leaving => (
            const Color(0xFFD97706),
            const Color(0xFFF59E0B).withValues(alpha: 0.15),
            const Color(0xFFF59E0B).withValues(alpha: 0.4),
            const Color(0xFFF59E0B),
          ),
          MediaSessionState.failed => (
            const Color(0xFFDC2626),
            const Color(0xFFEF4444).withValues(alpha: 0.12),
            const Color(0xFFEF4444).withValues(alpha: 0.4),
            const Color(0xFFEF4444),
          ),
          _ => (
            RealtimeUiTokens.textMuted,
            RealtimeUiTokens.surfaceSubtle,
            RealtimeUiTokens.border,
            null,
          ),
        };
        return Semantics(
          label: 'Connection: ${strings.mediaConnectionState(state)}',
          child: RealtimePill(
            label: strings.mediaConnectionState(state),
            leadingDotColor: dot,
            foreground: foreground,
            background: background,
            borderColor: border,
          ),
        );
      },
    );
  }
}

/// Renders one participant from the room without owning the entire stage.
class RealtimeVideoTile extends StatelessWidget {
  const RealtimeVideoTile({
    super.key,
    required this.participant,
    this.onTap,
    this.isFocused = false,
  });

  final MediaParticipant participant;
  final VoidCallback? onTap;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return MediaParticipantTile(
      participant: participant,
      renderer: controller.room.renderer,
      isFocused: isFocused,
      onTap: onTap,
    );
  }
}

/// Only renders media tiles. The application decides its size and position.
class RealtimeVideoGrid extends StatelessWidget {
  const RealtimeVideoGrid({
    super.key,
    this.participants,
    this.crossAxisCount,
    this.spacing = 8,
    this.padding = const EdgeInsets.all(8),
    this.onParticipantTap,
  });

  final List<MediaParticipant>? participants;
  final int? crossAxisCount;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final ValueChanged<MediaParticipant>? onParticipantTap;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final members = participants ?? controller.snapshot.participants;
        if (members.isEmpty) {
          return const Center(child: Icon(Icons.people_outline, size: 48));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                crossAxisCount ??
                math.min(
                  members.length,
                  math.max(1, (constraints.maxWidth / 290).ceil()),
                );
            return GridView.builder(
              padding: padding,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: math.max(1, columns),
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: 16 / 9,
              ),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return RealtimeVideoTile(
                  key: ValueKey(member.id),
                  participant: member,
                  onTap: onParticipantTap == null
                      ? null
                      : () => onParticipantTap!(member),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Entire remote/local shared frame with contain fit, independently positioned.
class RealtimeScreenShareStage extends StatelessWidget {
  const RealtimeScreenShareStage({
    super.key,
    this.placeholder,
    this.showBar = true,
  });
  final Widget? placeholder;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final zh = RealtimeStrings.of(context).isZh;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final track = controller.snapshot.contentShareTrack;
        final trackView = MediaTrackView(
          renderer: controller.room.renderer,
          track: track,
          fit: BoxFit.contain,
          placeholder: placeholder,
        );
        if (!showBar || track == null) return trackView;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: SharedContentStageBar(
                title: zh ? '屏幕共享' : 'Screen Share',
                badgeIcon: Icons.screen_share_outlined,
                subtitle: track.isLocal
                    ? (zh ? '您正在共享屏幕' : 'You are sharing screen')
                    : (zh ? '正在查看共享画面' : 'Viewing shared screen'),
                onStop: track.isLocal ? controller.toggleScreenShare : null,
              ),
            ),
            Expanded(child: trackView),
          ],
        );
      },
    );
  }
}
