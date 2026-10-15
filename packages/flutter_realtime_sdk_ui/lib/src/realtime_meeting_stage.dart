import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';
import 'meeting_shared_content.dart';

/// Participant grid, local focus selection and authoritative shared content.
class RealtimeMeetingStage extends StatefulWidget {
  const RealtimeMeetingStage({
    super.key,
    this.bottomControlsInset = 0,
    this.topOverlayInset = 0,
    required this.useGrid,
    this.showFilmstrip = true,
    this.showClassroom = true,
    this.showAnnotations = true,
    this.participantBuilder,
    this.overlayBuilder,
  });

  final double bottomControlsInset;
  final double topOverlayInset;
  final bool useGrid;
  final bool showFilmstrip;
  final bool showClassroom;
  final bool showAnnotations;
  final MediaParticipantBuilder? participantBuilder;
  final WidgetBuilder? overlayBuilder;

  @override
  State<RealtimeMeetingStage> createState() => _RealtimeMeetingStageState();
}

class _RealtimeMeetingStageState extends State<RealtimeMeetingStage> {
  String? _pinnedParticipantId;
  String? _sharedParticipantId;
  (SharedContentMode, String, String)? _sharingIdentity;
  RealtimeRoom? _room;
  Stream<Object?>? _stageUpdates;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (!identical(_room, controller.room)) {
      _room = controller.room;
      _pinnedParticipantId = null;
      _sharedParticipantId = null;
      _sharingIdentity = null;
      _stageUpdates = controller.room.sharedContent?.stageUpdates;
    }
    return StreamBuilder<Object?>(
      stream: widget.showClassroom ? _stageUpdates : null,
      builder: (context, _) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final snapshot = controller.snapshot;
          final shared = MeetingSharedContent(
            room: controller.room,
            snapshot: snapshot,
            showClassroom: widget.showClassroom,
          );
          _reconcileFocus(shared, snapshot.participants);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (shared.active)
                _buildSharing(context, controller, shared)
              else
                _buildMembers(context, controller),
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
        },
      ),
    );
  }

  void _reconcileFocus(
    MeetingSharedContent shared,
    List<MediaParticipant> participants,
  ) {
    final next = shared.active ? shared.identity : null;
    final previous = _sharingIdentity;
    final newContent =
        next != previous &&
        // Arrival of the first direct-share track completes the pending share.
        !(previous != null &&
            next != null &&
            previous.$1 == next.$1 &&
            previous.$1 == SharedContentMode.screen &&
            previous.$3.isEmpty &&
            (previous.$2.isEmpty || previous.$2 == next.$2));
    if (newContent || !participants.any((p) => p.id == _sharedParticipantId)) {
      _sharedParticipantId = null;
    }
    _sharingIdentity = next;
  }

  RealtimeMeetingTileData _tile(
    BuildContext context,
    RealtimeRoomUiController controller,
    MediaParticipant p,
  ) => RealtimeMeetingTileData(
    id: p.id,
    displayName: p.isLocal
        ? '${p.displayName.isEmpty ? p.id : p.displayName} (${RealtimeStrings.of(context).isZh ? '自己' : 'You'})'
        : p.displayName.isEmpty
        ? p.id
        : p.displayName,
    avatarUrl: p.avatarUrl,
    isMuted: p.isMuted,
    isSpeaking: p.isSpeaking,
    videoWidget:
        widget.participantBuilder?.call(context, p, controller.room.renderer) ??
        RealtimeVideoTile(
          key: ValueKey(p.id),
          participant: p,
          showNameTag: false,
        ),
  );

  Widget _buildMembers(
    BuildContext context,
    RealtimeRoomUiController controller,
  ) {
    final participants = controller.snapshot.participants;
    if (widget.useGrid || participants.length <= 1) {
      return RealtimeVideoGrid(
        participantBuilder: widget.participantBuilder,
        padding: EdgeInsets.fromLTRB(8, 8, 8, widget.bottomControlsInset + 8),
      );
    }
    final primary = participants.firstWhere(
      (p) => p.id == _pinnedParticipantId,
      orElse: () => participants.firstWhere(
        (p) => p.isSpeaking && !p.isLocal,
        orElse: () => participants.firstWhere(
          (p) => !p.isLocal && (p.isVideoEnabled || p.videoTrack != null),
          orElse: () => participants.first,
        ),
      ),
    );
    return RealtimeMeetingFilmstripStage(
      primaryParticipant: _tile(context, controller, primary),
      participants: participants
          .where((p) => p.id != primary.id)
          .map((p) => _tile(context, controller, p))
          .toList(),
      showFilmstrip: widget.showFilmstrip,
      bottomControlsInset: widget.bottomControlsInset,
      onSelectParticipant: (tile) =>
          setState(() => _pinnedParticipantId = tile.id),
    );
  }

  Widget _buildSharing(
    BuildContext context,
    RealtimeRoomUiController controller,
    MeetingSharedContent shared,
  ) {
    final participants = controller.snapshot.participants;
    final focused = participants
        .where((p) => p.id == _sharedParticipantId)
        .firstOrNull;
    final zh = RealtimeStrings.of(context).isZh;
    final returnLabel = zh ? '返回共享内容' : 'Return to shared content';
    return Padding(
      padding: EdgeInsets.only(
        top: widget.topOverlayInset,
        bottom: widget.bottomControlsInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: focused == null
                  ? shared.buildMain(
                      context,
                      withAnnotations: widget.showAnnotations,
                    )
                  : RealtimeMeetingFilmstripStage(
                      primaryParticipant: _tile(context, controller, focused),
                      showFilmstrip: false,
                    ),
            ),
            if (focused != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('meeting-return-to-content'),
                  onPressed: () => setState(() => _sharedParticipantId = null),
                  icon: const Icon(Icons.present_to_all_rounded),
                  label: Text(
                    returnLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (widget.showFilmstrip &&
                (participants.isNotEmpty || focused != null))
              RealtimeMeetingParticipantStrip(
                height: constraints.maxHeight < 300 ? 64 : 110,
                participants: participants
                    .where((p) => p.id != focused?.id)
                    .map((p) => _tile(context, controller, p))
                    .toList(),
                onSelectParticipant: (tile) =>
                    setState(() => _sharedParticipantId = tile.id),
                leading: focused == null
                    ? null
                    : Semantics(
                        button: true,
                        label: returnLabel,
                        child: Tooltip(
                          message: returnLabel,
                          child: RealtimeGlassPressable(
                            onTap: () =>
                                setState(() => _sharedParticipantId = null),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  shared.buildPreview(
                                    withAnnotations: widget.showAnnotations,
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: ColoredBox(
                                      color: Colors.black54,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        child: Text(
                                          shared.mode ==
                                                  SharedContentMode.whiteboard
                                              ? (zh ? '白板' : 'Whiteboard')
                                              : (zh ? '屏幕共享' : 'Screen share'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
