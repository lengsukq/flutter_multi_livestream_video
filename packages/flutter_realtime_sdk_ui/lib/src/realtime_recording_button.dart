import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';
import 'recording_action.dart';

/// Cloud recording action, independent of the provider's native UI.
class RealtimeRecordingButton extends StatefulWidget {
  const RealtimeRecordingButton({
    super.key,
    required this.room,
    this.showLabel = true,
  });

  final RealtimeRoom room;
  final bool showLabel;

  @override
  State<RealtimeRecordingButton> createState() =>
      _RealtimeRecordingButtonState();
}

class _RealtimeRecordingButtonState extends State<RealtimeRecordingButton> {
  bool _operating = false;

  bool get _cloudConfigured => widget.room.recording.isConfigured;

  void _showCloudResult() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => RealtimeRecordingResultDialog(room: widget.room),
      ),
    );
  }

  Future<void> _toggle() async {
    if (_operating || !_cloudConfigured || !widget.room.media.isLogicalOwner) {
      return;
    }
    final room = widget.room;
    setState(() => _operating = true);
    try {
      await toggleRoomRecording(
        context,
        room,
        isCurrent: () => mounted && identical(room, widget.room),
      );
    } catch (error) {
      if (mounted && identical(room, widget.room)) {
        final controller = RealtimeRoomUiScope.maybeOf(context);
        if (controller != null) {
          controller.reportActionError(error);
        } else {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                RealtimeStrings.of(context).displayRealtimeError(error),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<RecordingStatus>(
    stream: widget.room.recordingStatuses,
    initialData: widget.room.recordingStatus,
    builder: (context, snapshot) {
      final active = snapshot.data == RecordingStatus.recording;
      final enabled =
          _cloudConfigured && widget.room.media.isLogicalOwner && !_operating;
      final strings = RealtimeStrings.of(context);
      if (!_cloudConfigured) {
        return RealtimeDockItem(
          icon: Icons.cloud_off_outlined,
          label: strings.cloudRecording,
          tooltip: strings.cloudRecordingUnsupported,
          showLabel: widget.showLabel,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active)
            RealtimeDockItem(
              icon: Icons.cloud_download_outlined,
              label: strings.viewRecordingResult,
              showLabel: widget.showLabel,
              onPressed: enabled ? _showCloudResult : null,
            ),
          RealtimeDockItem(
            icon: active
                ? Icons.stop_circle_outlined
                : Icons.cloud_circle_outlined,
            label: active ? strings.stopCloudRecording : strings.cloudRecording,
            isDanger: active,
            isLoading: _operating,
            showLabel: widget.showLabel,
            onPressed: enabled ? _toggle : null,
          ),
        ],
      );
    },
  );
}
