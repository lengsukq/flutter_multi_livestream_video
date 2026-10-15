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
          if (compact) {
            final strings = RealtimeStrings.of(context);
            return Tooltip(
              message: strings.isZh
                  ? '云端录制中 · $minutes:$seconds'
                  : 'Cloud recording · $minutes:$seconds',
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(40),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withAlpha(160)),
                ),
                child: const Icon(
                  Icons.fiber_manual_record_rounded,
                  size: 13,
                  color: Colors.redAccent,
                ),
              ),
            );
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withAlpha(160)),
            ),
            child: Text(
              'CLOUD $minutes:$seconds',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        },
      );
    },
  );
}
