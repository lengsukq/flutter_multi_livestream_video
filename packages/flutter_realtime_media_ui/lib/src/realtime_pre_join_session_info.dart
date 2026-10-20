import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// How the host wants the local user to enter the room.
///
/// [standard] keeps the current microphone/camera choices, [audioOnly] joins
/// with the camera off, and [screenShare] asks the room page to start sharing
/// the screen after the connection is established.
enum RealtimePreJoinJoinIntent { standard, audioOnly, screenShare }

extension RealtimePreJoinJoinIntentSettings on RealtimePreJoinJoinIntent {
  /// Applies the media part of the intent to the pre-join selections.
  ///
  /// Screen sharing is a room action, not a preview setting, so it leaves the
  /// camera and microphone untouched.
  MediaLocalPreviewSettings applyTo(MediaLocalPreviewSettings settings) =>
      switch (this) {
        RealtimePreJoinJoinIntent.standard ||
        RealtimePreJoinJoinIntent.screenShare => settings,
        RealtimePreJoinJoinIntent.audioOnly => settings.copyWith(
          microphoneEnabled: true,
          cameraEnabled: false,
        ),
      };
}

/// Host-provided class details for the green-room session card.
///
/// None of these values are derived or invented by the SDK. A host that has no
/// authoritative schedule simply omits the fields it cannot supply.
class RealtimePreJoinSessionInfo {
  const RealtimePreJoinSessionInfo({
    required this.title,
    this.subject,
    this.subjectIcon = Icons.school_outlined,
    this.scheduleLabel,
    this.timeRangeLabel,
    this.startsAt,
    this.enrolledCount,
  });

  final String title;
  final String? subject;
  final IconData subjectIcon;
  final String? scheduleLabel;
  final String? timeRangeLabel;

  /// Authoritative start time used for the countdown. The SDK never runs a
  /// local schedule when this is null.
  final DateTime? startsAt;
  final int? enrolledCount;
}

/// One guest waiting in the host's lobby.
class RealtimePreJoinWaitingGuest {
  const RealtimePreJoinWaitingGuest({
    required this.id,
    required this.name,
    this.note,
    this.admitted = false,
  });

  final String id;
  final String name;
  final String? note;
  final bool admitted;

  RealtimePreJoinWaitingGuest copyWith({bool? admitted}) =>
      RealtimePreJoinWaitingGuest(
        id: id,
        name: name,
        note: note,
        admitted: admitted ?? this.admitted,
      );
}

/// One numbered item in the host's lesson plan.
class RealtimePreJoinAgendaItem {
  const RealtimePreJoinAgendaItem({required this.title, this.durationLabel});

  final String title;
  final String? durationLabel;
}

/// One link the host wants to surface before the session starts.
class RealtimePreJoinMaterial {
  const RealtimePreJoinMaterial({
    required this.id,
    required this.title,
    this.icon = Icons.description_outlined,
  });

  final String id;
  final String title;
  final IconData icon;
}
