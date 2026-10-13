import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

/// Small Demo-only presentation for SDK cloud recording status and download.
/// The SDK, not this UI, owns all backend calls and provider credentials.
class DemoCloudRecordingResultDialog extends StatefulWidget {
  const DemoCloudRecordingResultDialog({super.key, required this.room});
  final RealtimeRoom room;

  @override
  State<DemoCloudRecordingResultDialog> createState() =>
      _DemoCloudRecordingResultDialogState();
}

class _DemoCloudRecordingResultDialogState
    extends State<DemoCloudRecordingResultDialog> {
  RecordingResult? _result;
  String? _error;
  bool _loading = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_result?.taskState != RecordingTaskState.completed &&
          _result?.taskState != RecordingTaskState.failed) {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await widget.room.queryCloudRecording();
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final uri = await widget.room.cloudRecordingDownloadUrl();
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('系统未能打开录制文件的下载地址。');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _result?.taskState.name ?? 'loading';
    final canDownload = _result?.metadata['canDownload'] == true;
    final unavailableReason = _result?.metadata['recordingAvailable'] == false
        ? _result?.metadata['recordingUnavailableReason']?.toString()
        : null;
    final label = switch (state) {
      'starting' => '云端正在创建录制任务',
      'recording' => '正在云端录制',
      'processing' => '正在生成 MP4 文件',
      'completed' => '云端录制已完成',
      'failed' => '云端录制失败',
      'idle' => '没有找到录制任务',
      _ => '正在查询云端录制状态',
    };
    return AlertDialog(
      title: const Text('云端录制'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_loading && _result == null) const LinearProgressIndicator(),
            if (_result?.recordingId != null)
              SelectableText('任务：${_result!.recordingId}'),
            if (_result?.fileName != null)
              SelectableText('文件：${_result!.fileName}'),
            if (_result != null && _result!.fileSizeBytes > 0)
              Text('大小：${_result!.fileSizeBytes} 字节'),
            if (unavailableReason != null) ...[
              const SizedBox(height: 8),
              Text(unavailableReason,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (state == 'processing')
              const Text('停止录制后，服务器还需要封装 MP4 文件。准备好后才能下载。'),
            if (_result?.metadata['error'] != null)
              Text(
                '${_result!.metadata['error']}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _refresh,
          child: const Text('刷新状态'),
        ),
        if (canDownload)
          FilledButton.icon(
            onPressed: _loading ? null : _download,
            icon: const Icon(Icons.download),
            label: const Text('下载 MP4'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
