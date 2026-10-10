import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

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
class RealtimeConnectionIndicator extends StatelessWidget {
  const RealtimeConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.snapshot.state;
        return Semantics(
          label: 'Connection: ${state.name}',
          child: Chip(
            label: Text(state.name),
            avatar: Icon(
              state == MediaSessionState.connected
                  ? Icons.circle
                  : Icons.info_outline,
              size: 12,
              color: state == MediaSessionState.connected
                  ? Colors.green
                  : Colors.orange,
            ),
            visualDensity: VisualDensity.compact,
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
  const RealtimeScreenShareStage({super.key, this.placeholder});
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MediaTrackView(
        renderer: controller.room.renderer,
        track: controller.snapshot.contentShareTrack,
        fit: BoxFit.contain,
        placeholder: placeholder,
      ),
    );
  }
}
