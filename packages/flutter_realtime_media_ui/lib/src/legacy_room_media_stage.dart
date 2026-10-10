part of 'media_room_view.dart';

/// Legacy room presentation only: video layout and contained screen stage.
/// Video state and provider operations remain owned by the media SDK.
mixin _LegacyRoomMediaStage on State<MediaRoomView> {
  MediaRoomLayoutMode get _layoutMode;
  String? get _focusedParticipantId;
  set _focusedParticipantId(String? id);

  Widget _grid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final participants = value.participants;
      final count = participants.length;
      final focused = count > 1 && _focusedParticipantId != null
          ? participants.where((p) => p.id == _focusedParticipantId).firstOrNull
          : null;
      final isSpeaker = _layoutMode == MediaRoomLayoutMode.speaker;
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: _buildParticipantWidget(
                  effectiveFocused,
                  isFocused: true,
                  canFocus: true,
                ),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: others.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _buildParticipantWidget(
                        others[index],
                        isFocused: false,
                        canFocus: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
