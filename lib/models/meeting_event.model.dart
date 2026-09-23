import 'video_tile.model.dart';

/// Camera to use for local video capture.
enum CameraPosition { front, back }

/// Base type for events emitted by the native Chime SDK.
sealed class ChimeEvent {
  const ChimeEvent();

  /// Parses the platform-neutral method-channel event payload.
  static ChimeEvent? fromJson(dynamic value) {
    if (value is! Map) return null;

    final json = Map<String, dynamic>.from(value);
    switch (json['type']) {
      case 'audioSessionConnecting':
        return MeetingSessionEvent(
          MeetingSessionEventKind.audioConnecting,
          reconnecting: json['reconnecting'] as bool?,
        );
      case 'audioSessionStarted':
        return MeetingSessionEvent(
          MeetingSessionEventKind.audioStarted,
          reconnecting: json['reconnecting'] as bool?,
        );
      case 'audioSessionDropped':
        return const MeetingSessionEvent(MeetingSessionEventKind.audioDropped);
      case 'audioSessionReconnectCancelled':
        return const MeetingSessionEvent(
          MeetingSessionEventKind.audioReconnectCancelled,
        );
      case 'audioSessionStopped':
        return MeetingSessionEvent(
          MeetingSessionEventKind.audioStopped,
          statusCode: json['statusCode']?.toString(),
        );
      case 'videoSessionConnecting':
        return const MeetingSessionEvent(
          MeetingSessionEventKind.videoConnecting,
        );
      case 'videoSessionStarted':
        return MeetingSessionEvent(
          MeetingSessionEventKind.videoStarted,
          statusCode: json['statusCode']?.toString(),
        );
      case 'videoSessionStopped':
        return MeetingSessionEvent(
          MeetingSessionEventKind.videoStopped,
          statusCode: json['statusCode']?.toString(),
        );
      case 'connectionBecamePoor':
        return const ConnectionQualityEvent(ConnectionQuality.poor);
      case 'connectionRecovered':
        return const ConnectionQualityEvent(ConnectionQuality.recovered);
      case 'cameraAvailabilityChanged':
        return CameraAvailabilityEvent(json['available'] == true);
      case 'attendeeVolumeChanged':
        return AttendeeVolumeEvent(
          attendeeId: json['attendeeId']?.toString() ?? '',
          externalUserId: json['externalUserId']?.toString() ?? '',
          volumeLevel: _parseVolumeLevel(json['volumeLevel']?.toString()),
        );
      case 'attendeeSignalStrengthChanged':
        return AttendeeSignalStrengthEvent(
          attendeeId: json['attendeeId']?.toString() ?? '',
          externalUserId: json['externalUserId']?.toString() ?? '',
          signalStrength: _parseSignalStrength(
            json['signalStrength']?.toString(),
          ),
        );
      case 'videoTilePaused':
      case 'videoTileResumed':
      case 'videoTileSizeChanged':
        final tileJson = json['videoTile'];
        if (tileJson is! Map) return null;
        final kind = switch (json['type']) {
          'videoTilePaused' => VideoTileEventKind.paused,
          'videoTileResumed' => VideoTileEventKind.resumed,
          _ => VideoTileEventKind.sizeChanged,
        };
        return VideoTileEvent(
          kind,
          VideoTileModel.fromJson(Map<String, dynamic>.from(tileJson)),
        );
      default:
        return null;
    }
  }
}

enum MeetingSessionEventKind {
  audioConnecting,
  audioStarted,
  audioDropped,
  audioReconnectCancelled,
  audioStopped,
  videoConnecting,
  videoStarted,
  videoStopped,
}

class MeetingSessionEvent extends ChimeEvent {
  final MeetingSessionEventKind kind;
  final bool? reconnecting;
  final String? statusCode;

  const MeetingSessionEvent(this.kind, {this.reconnecting, this.statusCode});
}

enum ConnectionQuality { poor, recovered }

class ConnectionQualityEvent extends ChimeEvent {
  final ConnectionQuality quality;

  const ConnectionQualityEvent(this.quality);
}

class CameraAvailabilityEvent extends ChimeEvent {
  final bool available;

  const CameraAvailabilityEvent(this.available);
}

enum MeetingVolumeLevel { muted, notSpeaking, low, medium, high, unknown }

class AttendeeVolumeEvent extends ChimeEvent {
  final String attendeeId;
  final String externalUserId;
  final MeetingVolumeLevel volumeLevel;

  const AttendeeVolumeEvent({
    required this.attendeeId,
    required this.externalUserId,
    required this.volumeLevel,
  });
}

enum MeetingSignalStrength { none, low, high, unknown }

class AttendeeSignalStrengthEvent extends ChimeEvent {
  final String attendeeId;
  final String externalUserId;
  final MeetingSignalStrength signalStrength;

  const AttendeeSignalStrengthEvent({
    required this.attendeeId,
    required this.externalUserId,
    required this.signalStrength,
  });
}

enum VideoTileEventKind { paused, resumed, sizeChanged }

class VideoTileEvent extends ChimeEvent {
  final VideoTileEventKind kind;
  final VideoTileModel videoTile;

  const VideoTileEvent(this.kind, this.videoTile);
}

MeetingVolumeLevel _parseVolumeLevel(String? value) {
  final normalized = value?.split('.').last.replaceAll('_', '').toLowerCase();
  return switch (normalized) {
    'muted' => MeetingVolumeLevel.muted,
    'notspeaking' => MeetingVolumeLevel.notSpeaking,
    'low' => MeetingVolumeLevel.low,
    'medium' => MeetingVolumeLevel.medium,
    'high' => MeetingVolumeLevel.high,
    _ => MeetingVolumeLevel.unknown,
  };
}

MeetingSignalStrength _parseSignalStrength(String? value) {
  return switch (value?.split('.').last.toLowerCase()) {
    'none' => MeetingSignalStrength.none,
    'low' => MeetingSignalStrength.low,
    'high' => MeetingSignalStrength.high,
    _ => MeetingSignalStrength.unknown,
  };
}
