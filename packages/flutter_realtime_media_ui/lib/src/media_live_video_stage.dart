import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';
import 'room_regions.dart';
import 'media_participant_builder.dart';

class MediaLiveVideoStage extends StatelessWidget {
  const MediaLiveVideoStage({
    super.key,
    required this.snapshot,
    required this.role,
    required this.participantId,
    required this.roomCode,
    required this.renderer,
    this.participantBuilder,
    this.fit,
  });
  final MediaSnapshot snapshot;
  final MediaRole role;
  final String participantId;
  final String roomCode;
  final MediaTrackRenderer renderer;
  final MediaParticipantBuilder? participantBuilder;
  final BoxFit? fit;
  @override
  Widget build(BuildContext context) {
    final value = snapshot;
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isLocalHost = role == MediaRole.host;

    // In livestream / broadcast, resolve the single host participant.
    final MediaParticipant? hostParticipant = isLocalHost
        ? (value.participants.where((p) => p.isLocal).firstOrNull ??
              (value.localParticipantId != null
                  ? value.participants
                        .where((p) => p.id == value.localParticipantId)
                        .firstOrNull
                  : null) ??
              MediaParticipant(
                id: participantId,
                displayName: participantId,
                isLocal: true,
                isVideoEnabled: value.localVideoEnabled,
              ))
        : (value.participants
                  .where(
                    (p) =>
                        !p.isLocal &&
                        (p.isVideoEnabled || p.videoTrack != null),
                  )
                  .firstOrNull ??
              value.participants.where((p) => !p.isLocal).firstOrNull ??
              value.participants.firstOrNull);

    // If custom participant builder provided, honor it.
    if (participantBuilder != null && hostParticipant != null) {
      return participantBuilder!(context, hostParticipant, renderer);
    }

    if (hostParticipant == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RealtimeGlassSurface(
            radius: RealtimeUiTokens.cardRadius,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RoomWaitingPulse(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(
                      Icons.sensors_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.waitingForHost,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  roomCode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: style.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasVideo =
        hostParticipant.videoTrack != null &&
        (isLocalHost
            ? value.localVideoEnabled
            : hostParticipant.isVideoEnabled);

    if (hasVideo) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight > constraints.maxWidth;
          return Center(
            child: MediaTrackView(
              renderer: renderer,
              track: hostParticipant.videoTrack,
              fit: fit ?? (isPortrait ? BoxFit.cover : BoxFit.contain),
              placeholder: _buildLiveHostOffCameraPlaceholder(
                context,
                hostParticipant,
                strings,
                style,
              ),
            ),
          );
        },
      );
    }

    return _buildLiveHostOffCameraPlaceholder(
      context,
      hostParticipant,
      strings,
      style,
    );
  }

  Widget _buildLiveHostOffCameraPlaceholder(
    BuildContext context,
    MediaParticipant host,
    RealtimeStrings strings,
    RealtimeStyle style,
  ) {
    final name = host.displayName.isEmpty ? host.id : host.displayName;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.sheetRadius,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RealtimeAvatar(name: name, avatarUrl: host.avatarUrl, size: 88),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: style.text,
                ),
              ),
              const SizedBox(height: 8),
              RealtimePill(
                label: strings.cameraOff,
                icon: Icons.videocam_off_rounded,
                foreground: style.danger,
                background: style.dangerSubtle,
                borderColor: style.isDark
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFFFECDD3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
