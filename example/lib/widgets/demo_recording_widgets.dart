import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import '../demo_strings.dart';
import 'demo_cloud_recording_result_dialog.dart';

/// Shows a badge while the backend is recording.
class DemoRecordingBadge extends StatelessWidget {
  const DemoRecordingBadge({super.key, required this.room});

  final RealtimeRoom room;

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

/// Cloud recording action, independent of the provider's native UI.
class DemoRecordingButton extends StatefulWidget {
  const DemoRecordingButton({
    super.key,
    required this.room,
    this.showLabel = true,
  });

  final RealtimeRoom room;
  final bool showLabel;

  @override
  State<DemoRecordingButton> createState() => _DemoRecordingButtonState();
}

class _DemoRecordingButtonState extends State<DemoRecordingButton> {
  bool _operating = false;

  bool get _cloudConfigured =>
      widget.room.featureBackendUrl != null &&
      const {
        'livekit',
        'trtc',
        'agora',
        'artc',
        'chime',
        'ivs',
      }.contains(widget.room.engineProviderId);

  void _showCloudResult() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
      ),
    );
  }

  Future<void> _toggle() async {
    if (_operating || !_cloudConfigured || !widget.room.media.isLogicalOwner) {
      return;
    }
    final recording = widget.room.recordingStatus == RecordingStatus.recording;
    RecordingLayout? layout;
    if (!recording) {
      layout = await showDialog<RecordingLayout>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(DemoStrings.of(context).chooseCloudRecordingLayout),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.grid),
              child: Text(DemoStrings.of(context).gridModePreferred),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.speaker),
              child: Text(DemoStrings.of(context).speakerMode),
            ),
          ],
        ),
      );
      if (layout == null || !mounted) return;
    }
    setState(() => _operating = true);
    try {
      if (recording) {
        await widget.room.stopRecording();
      } else {
        await widget.room.startRecording(
          RecordingOptions.cloud(layout: layout!),
        );
      }
      if (mounted) _showCloudResult();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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
      final strings = DemoStrings.of(context);
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

/// Compact cloud-only entry for host-tool sheets.
class DemoRecordingListTile extends StatelessWidget {
  const DemoRecordingListTile({super.key, required this.room});

  final RealtimeRoom room;

  @override
  Widget build(BuildContext context) {
    return DemoRecordingButton(room: room);
  }
}
