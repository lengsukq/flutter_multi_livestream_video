/// Host-provided room identity shown in the meeting header.
///
/// The SDK has no authoritative class title, subject or session number, so a
/// host that has one supplies it here. When omitted the header falls back to
/// the backend room code.
class RealtimeMeetingSessionInfo {
  const RealtimeMeetingSessionInfo({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}
