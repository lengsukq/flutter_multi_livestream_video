import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';
import 'media_participant_builder.dart';
import 'media_participant_tile.dart';
import 'media_room_layout_mode.dart';

class MediaMeetingVideoStage extends StatefulWidget {
  const MediaMeetingVideoStage({
    super.key,
    required this.snapshot,
    required this.renderer,
    required this.layoutMode,
    required this.waiting,
    this.participantBuilder,
    this.screenShareOverlayBuilder,
    this.contentStageBuilder,
    this.hasContentControls = false,
  });
  final MediaSnapshot snapshot;
  final MediaTrackRenderer renderer;
  final MediaRoomLayoutMode layoutMode;
  final Widget waiting;
  final MediaParticipantBuilder? participantBuilder;
  final Widget Function(BuildContext context, MediaVideoTrack track)?
  screenShareOverlayBuilder;
  final Widget? Function(BuildContext context, MediaSnapshot snapshot)?
  contentStageBuilder;
  final bool hasContentControls;
  @override
  State<MediaMeetingVideoStage> createState() => _MediaMeetingVideoStageState();
}

class _MediaMeetingVideoStageState extends State<MediaMeetingVideoStage> {
  String? _focusedParticipantId;
  @override
  Widget build(BuildContext context) {
    final value = widget.snapshot;
    final style = RealtimeStyle.of(context);
    final customContent = widget.contentStageBuilder?.call(context, value);
    final stageContent = customContent != null
        ? Column(
            children: [
              Expanded(child: customContent),
              if (value.participants.isNotEmpty)
                SizedBox(height: 116, child: _participantStrip(value)),
            ],
          )
        : widget.contentStageBuilder != null && widget.hasContentControls
        ? (value.participants.isEmpty ? widget.waiting : _grid(value))
        : value.contentShareTrack == null &&
              widget.layoutMode != MediaRoomLayoutMode.presentation
        ? value.participants.isEmpty
              ? widget.waiting
              : _grid(value)
        : Column(
            children: [
              Expanded(child: _screenShare(value)),
              if (value.participants.isNotEmpty)
                SizedBox(height: 116, child: _participantStrip(value)),
            ],
          );

    return ColoredBox(color: style.background, child: stageContent);
  }

  Widget _participantStrip(MediaSnapshot value) => ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    scrollDirection: Axis.horizontal,
    itemCount: value.participants.length,
    separatorBuilder: (_, _) => const SizedBox(width: 8),
    itemBuilder: (context, index) => SizedBox(
      width: 144,
      child: _buildParticipantWidget(
        value.participants[index],
        isFocused: false,
        canFocus: true,
      ),
    ),
  );

  Widget _grid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final participants = value.participants;
      final count = participants.length;
      final focused = count > 1 && _focusedParticipantId != null
          ? participants.where((p) => p.id == _focusedParticipantId).firstOrNull
          : null;
      final isSpeaker = widget.layoutMode == MediaRoomLayoutMode.speaker;
      final effectiveFocused =
          focused ??
          (isSpeaker && count > 1
              ? (participants.where((p) => p.isSpeaking).firstOrNull ??
                    participants.first)
              : null);

      if (effectiveFocused != null) {
        final others = participants
            .where((p) => p.id != effectiveFocused.id)
            .toList(growable: false);
        RealtimeMeetingTileData tile(MediaParticipant participant) =>
            RealtimeMeetingTileData(
              id: participant.id,
              avatarUrl: participant.avatarUrl,
              displayName: participant.displayName.isEmpty
                  ? RealtimeStrings.of(context).participant
                  : participant.displayName,
              isMuted: participant.isMuted,
              isSpeaking: participant.isSpeaking,
              videoWidget: _buildParticipantWidget(
                participant,
                isFocused: participant.id == effectiveFocused.id,
                canFocus: false,
              ),
            );
        return RealtimeMeetingFilmstripStage(
          primaryParticipant: tile(effectiveFocused),
          participants: others.map(tile).toList(growable: false),
          onSelectParticipant: (participant) =>
              setState(() => _focusedParticipantId = participant.id),
        );
      }

      final columns = constraints.maxWidth > 900
          ? (count <= 4 ? 2 : 3)
          : constraints.maxWidth > 600
          ? (count <= 2 ? 2 : 3)
          : (count == 1 ? 1 : 2);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: count == 1 ? 4 / 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return _buildParticipantWidget(
            participant,
            isFocused: false,
            canFocus: count > 1,
          );
        },
      );
    },
  );

  Widget _buildParticipantWidget(
    MediaParticipant participant, {
    required bool isFocused,
    required bool canFocus,
  }) {
    if (widget.participantBuilder != null) {
      return widget.participantBuilder!(context, participant, widget.renderer);
    }
    return MediaParticipantTile(
      participant: participant,
      renderer: widget.renderer,
      isFocused: isFocused,
      onTap: canFocus
          ? () => setState(() {
              _focusedParticipantId = _focusedParticipantId == participant.id
                  ? null
                  : participant.id;
            })
          : null,
    );
  }

  Widget _screenShare(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center, not expand: a contained screen share must keep its own
            // aspect ratio instead of being stretched or cropped, with the
            // stage background showing as letterbox bars.
            Center(
              child: MediaTrackView(
                renderer: widget.renderer,
                track: value.contentShareTrack,
                fit: BoxFit.contain,
              ),
            ),
            if (value.contentShareTrack != null &&
                widget.screenShareOverlayBuilder != null)
              Center(
                child: AspectRatio(
                  aspectRatio: value.contentShareTrack!.aspectRatio,
                  child: widget.screenShareOverlayBuilder!(
                    context,
                    value.contentShareTrack!,
                  ),
                ),
              ),
            Positioned(
              left: 10,
              top: 10,
              child: RealtimePill(
                label: strings.screenShare,
                icon: Icons.present_to_all_rounded,
                foreground: Colors.white,
                background: const Color(0xB3000000),
                borderColor: const Color(0x40FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
