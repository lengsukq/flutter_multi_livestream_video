import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Participant grid, focus selection and authoritative shared content.
class RealtimeMeetingStage extends StatefulWidget {
  const RealtimeMeetingStage({
    super.key,
    this.bottomControlsInset = 0,
    this.topOverlayInset = 0,
    required this.useGrid,
    this.showClassroom = true,
    this.showAnnotations = true,
    this.participantBuilder,
    this.overlayBuilder,
  });

  final double bottomControlsInset;
  final double topOverlayInset;
  final bool useGrid;
  final bool showClassroom;
  final bool showAnnotations;
  final MediaParticipantBuilder? participantBuilder;
  final WidgetBuilder? overlayBuilder;

  @override
  State<RealtimeMeetingStage> createState() => _RealtimeMeetingStageState();
}

class _RealtimeMeetingStageState extends State<RealtimeMeetingStage> {
  String? _pinnedParticipantId;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final content = widget.showClassroom
            ? controller.room.sharedContent?.content
            : null;
        final hasShare =
            snapshot.contentShareTrack != null ||
            (content != null && content.mode != SharedContentMode.members);
        if (hasShare) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.showClassroom)
                RealtimeSharedContentStage(
                  withAnnotations: widget.showAnnotations,
                  members: const RealtimeScreenShareStage(),
                )
              else
                const RealtimeScreenShareStage(),
              if (widget.showClassroom && controller.room.classroom != null)
                Positioned(
                  top: widget.topOverlayInset + 8,
                  left: 12,
                  right: 12,
                  child: RealtimeClassroomEventOverlay(
                    classroom: controller.room.classroom!,
                  ),
                ),
              if (widget.overlayBuilder != null)
                widget.overlayBuilder!(context),
            ],
          );
        }

        final participants = snapshot.participants;
        if (widget.useGrid || participants.length <= 1) {
          return Stack(
            fit: StackFit.expand,
            children: [
              RealtimeVideoGrid(
                participantBuilder: widget.participantBuilder,
                padding: EdgeInsets.fromLTRB(
                  8,
                  // Video remains edge-to-edge even when the floating header
                  // is visible; only notification toasts avoid its footprint.
                  8,
                  8,
                  widget.bottomControlsInset + 8,
                ),
              ),
              if (widget.showClassroom && controller.room.classroom != null)
                Positioned(
                  top: widget.topOverlayInset + 8,
                  left: 12,
                  right: 12,
                  child: RealtimeClassroomEventOverlay(
                    classroom: controller.room.classroom!,
                  ),
                ),
              if (widget.overlayBuilder != null)
                widget.overlayBuilder!(context),
            ],
          );
        }

        final primaryMember = participants.firstWhere(
          (p) => p.id == _pinnedParticipantId,
          orElse: () => participants.firstWhere(
            (p) => p.isSpeaking && !p.isLocal,
            orElse: () => participants.firstWhere(
              (p) => !p.isLocal && (p.isVideoEnabled || p.videoTrack != null),
              orElse: () => participants.first,
            ),
          ),
        );

        final otherMembers = participants
            .where((p) => p.id != primaryMember.id)
            .toList();

        Widget buildTile(MediaParticipant p) {
          if (widget.participantBuilder != null) {
            return widget.participantBuilder!(
              context,
              p,
              controller.room.renderer,
            );
          }
          return RealtimeVideoTile(
            key: ValueKey(p.id),
            participant: p,
            showNameTag: false,
          );
        }

        final primaryTile = RealtimeMeetingTileData(
          id: primaryMember.id,
          displayName: _name(primaryMember),
          avatarUrl: primaryMember.avatarUrl,
          isMuted: primaryMember.isMuted,
          isSpeaking: primaryMember.isSpeaking,
          videoWidget: buildTile(primaryMember),
        );

        final otherTiles = otherMembers
            .map(
              (p) => RealtimeMeetingTileData(
                id: p.id,
                displayName: _name(p),
                avatarUrl: p.avatarUrl,
                isMuted: p.isMuted,
                isSpeaking: p.isSpeaking,
                videoWidget: buildTile(p),
              ),
            )
            .toList();

        return Stack(
          fit: StackFit.expand,
          children: [
            RealtimeMeetingFilmstripStage(
              primaryParticipant: primaryTile,
              participants: otherTiles,
              bottomControlsInset: widget.bottomControlsInset,
              onSelectParticipant: (tile) {
                setState(() => _pinnedParticipantId = tile.id);
              },
              // The layout switch lives in the shared header so it cannot be
              // obscured by that same header's floating surface.
              onToggleLayout: null,
            ),
            if (widget.showClassroom && controller.room.classroom != null)
              Positioned(
                top: widget.topOverlayInset + 8,
                left: 12,
                right: 12,
                child: RealtimeClassroomEventOverlay(
                  classroom: controller.room.classroom!,
                ),
              ),
            if (widget.overlayBuilder != null) widget.overlayBuilder!(context),
          ],
        );
      },
    );
  }

  String _name(MediaParticipant p) {
    if (p.isLocal) {
      return '${p.displayName.isNotEmpty ? p.displayName : p.id} (You)';
    }
    return p.displayName.isNotEmpty ? p.displayName : p.id;
  }
}
