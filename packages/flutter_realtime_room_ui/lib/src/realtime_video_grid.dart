import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'realtime_room_ui_scope.dart';
import 'realtime_video_tile.dart';

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
