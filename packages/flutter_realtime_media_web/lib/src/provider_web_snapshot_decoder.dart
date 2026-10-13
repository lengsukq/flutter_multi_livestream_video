import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_web_profile.dart';
import 'provider_web_track.dart';
import 'provider_web_decoding.dart';

typedef ProviderWebSnapshotUpdate = ({
  MediaSnapshot snapshot,
  Map<String, ProviderWebVideoTrack> tracks,
  List<MediaEvent> events,
});
ProviderWebSnapshotUpdate decodeProviderWebSnapshot({
  required String providerId,
  required String sessionId,
  required Map<String, dynamic> event,
  required MediaSnapshot previous,
  required Map<String, ProviderWebVideoTrack> previousTracks,
}) {
  final events = <MediaEvent>[];

  final nextTracks = <String, ProviderWebVideoTrack>{};
  final rawTracks = event['tracks'];
  if (rawTracks is List) {
    for (final raw in rawTracks.whereType<Map<Object?, Object?>>()) {
      final value = Map<String, Object?>.from(raw);
      final id = value['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      nextTracks[id] = ProviderWebVideoTrack(
        providerId: providerId,
        sessionId: sessionId,
        id: id,
        participantId: value['participantId']?.toString() ?? '',
        contentOwnerParticipantId: ProviderWebProfile.forProvider(providerId)
            .contentOwner(
              value['participantId']?.toString() ?? '',
              isScreenShare: value['isScreenShare'] == true,
            ),
        isLocal: value['isLocal'] == true,
        isScreenShare: value['isScreenShare'] == true,
        width: webInt(value['width']) ?? 0,
        height: webInt(value['height']) ?? 0,
      );
    }
  }

  final rawParticipants = event['participants'];
  final participants = <MediaParticipant>[];
  if (rawParticipants is List) {
    for (final raw in rawParticipants.whereType<Map<Object?, Object?>>()) {
      final value = Map<String, Object?>.from(raw);
      final id = value['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final trackId = value['videoTrackId']?.toString();
      final videoTrack = trackId == null ? null : nextTracks[trackId];
      participants.add(
        MediaParticipant(
          id: id,
          displayName:
              value['displayName']?.toString().trim().isNotEmpty == true
              ? value['displayName'].toString().trim()
              : id,
          isLocal: value['isLocal'] == true,
          isMuted: value['isMuted'] == true,
          isVideoEnabled: value['isVideoEnabled'] == true || videoTrack != null,
          isSpeaking: value['isSpeaking'] == true,
          videoTrack: videoTrack,
        ),
      );
    }
  }
  final localParticipantId = event['localParticipantId']?.toString();
  final contentShareTrack = nextTracks.values
      .where((track) => track.isScreenShare)
      .firstOrNull;
  final localScreenShareEnabled = nextTracks.values.any(
    (track) => track.isScreenShare && track.isLocal,
  );
  final previousParticipants = {
    for (final item in previous.participants) item.id: item,
  };
  final currentParticipants = {for (final item in participants) item.id: item};
  for (final participant in participants) {
    final previous = previousParticipants[participant.id];
    if (previous == null) events.add(MediaParticipantJoined(participant));
    if (previous?.videoTrack == null && participant.videoTrack != null) {
      events.add(MediaTrackPublished(participant.videoTrack!));
    }
  }
  for (final participant in previous.participants) {
    if (!currentParticipants.containsKey(participant.id)) {
      events.add(
        MediaParticipantLeft(
          participantId: participant.id,
          displayName: participant.displayName,
        ),
      );
    }
  }
  for (final track in previousTracks.values) {
    if (!nextTracks.containsKey(track.id)) {
      events.add(
        MediaTrackUnpublished(
          trackId: track.id,
          participantId: track.participantId,
          wasScreenShare: track.isScreenShare,
        ),
      );
    }
  }
  final localMuted = event['localMuted'];
  final localVideoEnabled = event['localVideoEnabled'];
  final snapshot = previous.copyWith(
    participants: participants,
    localParticipantId: localParticipantId,
    clearLocalParticipantId:
        localParticipantId == null || localParticipantId.isEmpty,
    localMuted: localMuted is bool ? localMuted : null,
    localVideoEnabled: localVideoEnabled is bool ? localVideoEnabled : null,
    localScreenShareEnabled: localScreenShareEnabled,
    contentShareTrack: contentShareTrack,
    clearContentShareTrack: contentShareTrack == null,
  );

  return (
    snapshot: snapshot,
    tracks: Map.unmodifiable(nextTracks),
    events: List.unmodifiable(events),
  );
}
