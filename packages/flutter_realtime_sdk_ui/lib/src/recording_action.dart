import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'realtime_recording_layout_picker.dart';
import 'realtime_recording_result_dialog.dart';

/// Shared flow for meeting overflow actions and live host-tool controls.
Future<void> toggleRoomRecording(
  BuildContext context,
  RealtimeRoom room, {
  required bool Function() isCurrent,
}) async {
  if (!room.recording.isConfigured) {
    throw const RealtimeException(
      code: RealtimeErrorCode.unsupportedFeature,
      message: 'recording.unconfigured',
    );
  }
  if (!room.media.isLogicalOwner) {
    throw const RealtimeException(
      code: RealtimeErrorCode.permissionDenied,
      message: 'recording.permission',
    );
  }
  if (room.recordingStatus == RecordingStatus.recording) {
    await room.stopRecording();
  } else {
    final chosen = await showRealtimeRecordingLayoutPicker(context, room);
    if (chosen == null || !context.mounted || !isCurrent()) return;
    await room.startRecording(RecordingOptions.cloud(layout: chosen));
  }
  if (!context.mounted || !isCurrent()) return;
  unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => RealtimeRecordingResultDialog(room: room),
    ),
  );
}
