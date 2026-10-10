/// Optional source for recorder interruptions caused by OS permissions or
/// capture sessions ending outside the SDK's start/stop calls.
///
/// Events are reasons for an unrecoverable, unsolicited interruption.
/// Ordinary user-initiated stop must not emit this event.
abstract interface class MediaRecordingInterruptionSource {
  Stream<String> get recordingInterruptions;
}
