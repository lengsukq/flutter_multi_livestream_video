part of '../flutter_realtime_design_ui.dart';

/// Participant model for the meeting filmstrip view.
class RealtimeMeetingTileData {
  const RealtimeMeetingTileData({
    required this.id,
    required this.displayName,
    this.videoWidget,
    this.isMuted = true,
    this.isSpeaking = false,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final Widget? videoWidget;
  final bool isMuted;
  final bool isSpeaking;
  final String? avatarUrl;
}
