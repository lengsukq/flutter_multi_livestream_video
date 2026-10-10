import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Top-bar badge showing the current recording status and duration ticker.
class DemoRecordingBadge extends StatefulWidget {
  const DemoRecordingBadge({super.key, required this.room});

  final RealtimeRoom room;

  @override
  State<DemoRecordingBadge> createState() => _DemoRecordingBadgeState();
}

class _DemoRecordingBadgeState extends State<DemoRecordingBadge> {
  RecordingStatus _status = RecordingStatus.idle;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _status = widget.room.recordingStatus;
    _duration = widget.room.recording.duration;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RecordingStatus>(
      stream: widget.room.recordingStatuses,
      initialData: _status,
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data ?? RecordingStatus.idle;
        if (status != RecordingStatus.recording &&
            status != RecordingStatus.starting) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<Duration>(
          stream: widget.room.recordingDurations,
          initialData: _duration,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final m = duration.inMinutes
                .remainder(60)
                .toString()
                .padLeft(2, '0');
            final s = duration.inSeconds
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'REC $m:$s',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Bottom action bar button for toggling recording and inspecting results.
class DemoRecordingButton extends StatefulWidget {
  const DemoRecordingButton({super.key, required this.room});

  final RealtimeRoom room;

  @override
  State<DemoRecordingButton> createState() => _DemoRecordingButtonState();
}

class _DemoRecordingButtonState extends State<DemoRecordingButton> {
  bool _operating = false;

  Future<void> _toggleRecording() async {
    if (_operating) return;
    setState(() => _operating = true);

    try {
      if (widget.room.recordingStatus == RecordingStatus.recording) {
        final result = await widget.room.stopRecording();
        if (mounted && result != null) {
          _showResultDialog(result);
        }
      } else {
        await widget.room.startRecording(RecordingOptions.local());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已启动本地录制，音视频流正在写入本地沙盒'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('录制操作失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _operating = false);
      }
    }
  }

  void _showResultDialog(RecordingResult result) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          DemoRecordingResultDialog(room: widget.room, result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RecordingStatus>(
      stream: widget.room.recordingStatuses,
      initialData: widget.room.recordingStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? RecordingStatus.idle;
        final isRecording = status == RecordingStatus.recording;

        return StreamBuilder<Duration>(
          stream: widget.room.recordingDurations,
          initialData: widget.room.recording.duration,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final m = duration.inMinutes
                .remainder(60)
                .toString()
                .padLeft(2, '0');
            final s = duration.inSeconds
                .remainder(60)
                .toString()
                .padLeft(2, '0');

            if (isRecording) {
              return FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(50),
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: Text('停止 ($m:$s)'),
                onPressed: _operating ? null : _toggleRecording,
              );
            }

            return IconButton(
              tooltip: '本地录制 (保存到本地 MP4)',
              icon: const Icon(Icons.fiber_manual_record_outlined),
              onPressed: _operating ? null : _toggleRecording,
            );
          },
        );
      },
    );
  }
}

/// Dialog displaying the saved local file summary alongside the cloud recording API blueprint.
class DemoRecordingResultDialog extends StatelessWidget {
  const DemoRecordingResultDialog({
    super.key,
    required this.room,
    required this.result,
  });

  final RealtimeRoom room;
  final RecordingResult result;

  @override
  Widget build(BuildContext context) {
    final cloudDescriptor = room.describeCloudRecording(
      RecordingOptions.cloud(layout: RecordingLayout.grid),
    );
    final encoder = const JsonEncoder.withIndent('  ');
    final formattedPayload = encoder.convert(cloudDescriptor.payload);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 8),
          Text('录制已保存至本地沙盒'),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('录制模式', '客户端本地录制 (Local Recording)'),
                      _buildInfoRow('文件路径', result.localFilePath ?? '未知路径'),
                      _buildInfoRow('录制时长', '${result.duration.inSeconds} 秒'),
                      _buildInfoRow('文件大小', '${result.fileSizeBytes} 字节'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '云端 API 调度蓝图 (${cloudDescriptor.providerId.toUpperCase()})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('复制蓝图 JSON'),
                    onPressed: () {
                      final jsonString = encoder.convert(
                        cloudDescriptor.toJson(),
                      );
                      Clipboard.setData(ClipboardData(text: jsonString));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制云端录制 API 调度蓝图到剪贴板'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '当切换至云端录制时，SDK 支持自由传参并将下列官方 REST API 契约发送给业务后端处理：',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cloudDescriptor.httpMethod} ${cloudDescriptor.endpoint}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Payload:\n$formattedPayload',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
