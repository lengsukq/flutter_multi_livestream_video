/// Unified recovery lifecycle reported by [MediaRoomSession].
enum MediaRecoveryPhase { reconnecting, recovered, failed }

class MediaRecoveryStatus {
  const MediaRecoveryStatus({
    required this.phase,
    required this.attempt,
    required this.startedAtMs,
    required this.updatedAtMs,
    this.reason,
  });

  final MediaRecoveryPhase phase;
  final int attempt;
  final int startedAtMs;
  final int updatedAtMs;
  final String? reason;

  Duration get elapsed => Duration(milliseconds: updatedAtMs - startedAtMs);
}
