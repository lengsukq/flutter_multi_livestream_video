import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Shows a badge while the backend is recording.
class RealtimeRecordingBadge extends StatelessWidget {
  const RealtimeRecordingBadge({
    super.key,
    required this.room,
    this.compact = false,
  });

  final RealtimeRoom room;
  final bool compact;

  @override
  Widget build(BuildContext context) => StreamBuilder<RecordingStatus>(
    stream: room.recordingStatuses,
    initialData: room.recordingStatus,
    builder: (context, snapshot) {
      final status = snapshot.data ?? room.recordingStatus;
      if (status != RecordingStatus.recording &&
          status != RecordingStatus.starting) {
        return const SizedBox.shrink();
      }
      return StreamBuilder<Duration>(
        stream: room.recordingDurations,
        initialData: room.recording.duration,
        builder: (context, durationSnapshot) {
          final elapsed = durationSnapshot.data ?? Duration.zero;
          final minutes = elapsed.inMinutes
              .remainder(60)
              .toString()
              .padLeft(2, '0');
          final seconds = elapsed.inSeconds
              .remainder(60)
              .toString()
              .padLeft(2, '0');
          final strings = RealtimeStrings.of(context);
          if (compact) {
            // The header already shows a separate elapsed-time pill. Keep the
            // recording capsule to its state and move the duration into the
            // tooltip, matching the reference "Recording" chip.
            return Tooltip(
              message: strings.isZh
                  ? '云端录制中 · $minutes:$seconds'
                  : 'Cloud recording · $minutes:$seconds',
              child: RealtimeStatusPill(
                label: strings.isZh ? '录制中' : 'Recording',
                tone: RealtimeStatusTone.recording,
                showDot: true,
                blink: true,
              ),
            );
          }
          return RealtimeStatusPill(
            label: strings.isZh
                ? '录制中 $minutes:$seconds'
                : 'Recording $minutes:$seconds',
            tone: RealtimeStatusTone.recording,
            showDot: true,
            blink: true,
          );
        },
      );
    },
  );
}
