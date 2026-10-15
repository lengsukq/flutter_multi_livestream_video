import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:url_launcher/url_launcher.dart';

/// Backend-authoritative cloud recording status and download presentation.
class RealtimeRecordingResultDialog extends StatefulWidget {
  const RealtimeRecordingResultDialog({super.key, required this.room});
  final RealtimeRoom room;

  @override
  State<RealtimeRecordingResultDialog> createState() =>
      _RealtimeRecordingResultDialogState();
}

class _RealtimeRecordingResultDialogState
    extends State<RealtimeRecordingResultDialog> {
  RecordingResult? _result;
  String? _error;
  bool _loading = false;
  Timer? _poll;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant RealtimeRecordingResultDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room)) {
      _generation++;
      _poll?.cancel();
      _result = null;
      _error = null;
      _loading = false;
      _startPolling();
    }
  }

  void _startPolling() {
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      final result = _result;
      if (result?.metadata['recordingAvailable'] == false ||
          result?.taskState == RecordingTaskState.idle ||
          result?.taskState == RecordingTaskState.completed ||
          result?.taskState == RecordingTaskState.failed) {
        _poll?.cancel();
      } else {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final room = widget.room;
    final generation = _generation;
    bool current() => mounted && generation == _generation;
    setState(() => _loading = true);
    try {
      final result = await room.queryCloudRecording();
      if (!current()) return;
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (error) {
      if (current()) {
        setState(
          () =>
              _error = RealtimeStrings.of(context).displayRealtimeError(error),
        );
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_loading) return;
    final room = widget.room;
    final generation = _generation;
    bool current() => mounted && generation == _generation;
    setState(() => _loading = true);
    try {
      final uri = await room.cloudRecordingDownloadUrl();
      if (!current()) return;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'recording.openDownload',
        );
      }
    } catch (error) {
      if (current()) {
        setState(
          () =>
              _error = RealtimeStrings.of(context).displayRealtimeError(error),
        );
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final zh = strings.isZh;
    final result = _result;
    final state = result?.taskState;
    final canDownload =
        state == RecordingTaskState.completed &&
        result?.metadata['canDownload'] == true;
    final unavailable = result?.metadata['recordingAvailable'] == false;
    final label = switch (state) {
      RecordingTaskState.starting =>
        zh ? '云端正在创建录制任务' : 'Starting cloud recording',
      RecordingTaskState.recording => zh ? '正在云端录制' : 'Recording in the cloud',
      RecordingTaskState.processing =>
        zh ? '正在生成 MP4 文件' : 'Preparing the MP4 file',
      RecordingTaskState.completed =>
        zh ? '云端录制已完成' : 'Cloud recording completed',
      RecordingTaskState.failed => zh ? '云端录制失败' : 'Cloud recording failed',
      RecordingTaskState.idle => zh ? '没有找到录制任务' : 'No recording task found',
      _ => zh ? '正在查询云端录制状态' : 'Checking cloud recording status',
    };
    return AlertDialog(
      title: Text(strings.cloudRecording),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_loading && result == null) const LinearProgressIndicator(),
              if (result?.recordingId case final id?)
                SelectableText('${zh ? '任务' : 'Task'}: $id'),
              if (result?.fileName case final file?)
                SelectableText('${zh ? '文件' : 'File'}: $file'),
              if (result != null && result.fileSizeBytes > 0)
                Text('${zh ? '大小' : 'Size'}: ${result.fileSizeBytes} bytes'),
              if (unavailable) Text(strings.cloudRecordingUnsupported),
              if (state == RecordingTaskState.processing)
                Text(
                  zh
                      ? '停止录制后，服务器还需要封装 MP4 文件。准备好后才能下载。'
                      : 'The server is finalizing the MP4. Download becomes available when it is ready.',
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _refresh,
          child: Text(strings.refresh),
        ),
        if (canDownload)
          FilledButton.icon(
            onPressed: _loading ? null : _download,
            icon: const Icon(Icons.download),
            label: Text(zh ? '下载 MP4' : 'Download MP4'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.close),
        ),
      ],
    );
  }
}
