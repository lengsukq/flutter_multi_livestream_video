import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'demo_cloud_recording_result_dialog.dart';

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
                    widget.room.engineProviderId == 'livekit'
                        ? 'CLOUD $m:$s'
                        : 'REC $m:$s',
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
  const DemoRecordingButton({
    super.key,
    required this.room,
    this.iconOnly = false,
  });

  final RealtimeRoom room;
  final bool iconOnly;

  @override
  State<DemoRecordingButton> createState() => _DemoRecordingButtonState();
}

class _DemoRecordingButtonState extends State<DemoRecordingButton> {
  bool _operating = false;
  RecordingResult? _lastCloudResult;
  bool get _isCloudRoom =>
      widget.room.engineProviderId == 'livekit' &&
      widget.room.featureBackendUrl != null;

  Future<void> _toggleRecording() async {
    if (_operating) return;
    var layout = RecordingLayout.grid;
    if (_isCloudRoom &&
        widget.room.recordingStatus != RecordingStatus.recording) {
      final chosen = await showDialog<RecordingLayout>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择云端录制布局'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.grid),
              child: const ListTile(
                leading: Icon(Icons.grid_view),
                title: Text('宫格模式（推荐）'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.speaker),
              child: const ListTile(
                leading: Icon(Icons.person_pin),
                title: Text('演讲者模式'),
              ),
            ),
          ],
        ),
      );
      if (chosen == null || !mounted) return;
      layout = chosen;
    }
    setState(() => _operating = true);

    try {
      if (widget.room.recordingStatus == RecordingStatus.recording) {
        final result = await widget.room.stopRecording();
        if (mounted && result != null) {
          if (result.mode == RecordingMode.cloud) {
            _lastCloudResult = result;
            _showCloudResultDialog();
          } else {
            _showResultDialog(result);
          }
        }
      } else {
        if (_isCloudRoom) {
          _lastCloudResult = await widget.room.startRecording(
            RecordingOptions.cloud(layout: layout),
          );
          if (mounted) _showCloudResultDialog();
        } else {
          await widget.room.startRecording(RecordingOptions.local());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isCloudRoom ? '云端录制任务已创建，停止后需要等待云端文件处理完成。' : '已请求本地录制，请确认授权。',
              ),
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

  void _showCloudResultDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
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
              if (widget.iconOnly) {
                return Tooltip(
                  message: _isCloudRoom ? '停止云录制 ($m:$s)' : '停止录制 ($m:$s)',
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    onPressed: _operating ? null : _toggleRecording,
                  ),
                );
              }
              return FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(50),
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: Text(_isCloudRoom ? '停止云录制 ($m:$s)' : '停止 ($m:$s)'),
                onPressed: _operating ? null : _toggleRecording,
              );
            }

            if (_isCloudRoom) {
              final canRecord =
                  widget.room.media.session.role == MediaRole.host;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lastCloudResult != null)
                    IconButton(
                      tooltip: '查看云录制结果',
                      icon: const Icon(Icons.cloud_download_outlined),
                      onPressed: _operating || !canRecord
                          ? null
                          : _showCloudResultDialog,
                    ),
                  IconButton(
                    tooltip: '云端录制（宫格 / 演讲者）',
                    icon: const Icon(Icons.cloud_circle_outlined),
                    onPressed: _operating || !canRecord
                        ? null
                        : _toggleRecording,
                  ),
                ],
              );
            }

            return IconButton(
              tooltip: widget.room.capabilities.media.canRecordLocal
                  ? '本地录制尚待真实设备验收，Demo 暂优先展示 LiveKit 云端录制'
                  : '云端录制 V1 目前仅支持 LiveKit',
              icon: const Icon(Icons.cloud_off_outlined),
              onPressed: null,
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
          Text('录制已完成'),
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
                      _buildInfoRow(
                        result.downloadId != null ? '文件名' : '文件路径',
                        result.fileName ?? result.localFilePath ?? '未知',
                      ),
                      _buildInfoRow('录制时长', '${result.duration.inSeconds} 秒'),
                      _buildInfoRow('文件大小', '${result.fileSizeBytes} 字节'),
                      if (result.mimeType != null)
                        _buildInfoRow('格式', result.mimeType!),
                    ],
                  ),
                ),
              ),
              if (result.metadata['hasAudio'] == false)
                Text(
                  result.downloadId != null
                      ? '本次浏览器没有提供共享音频，录制文件只有画面。若浏览器支持，请选择会议标签页并开启共享音频。'
                      : '本次只录制了画面，没有采集到音频。Android 第一版暂不支持会议音频混流。',
                  style: const TextStyle(color: Colors.orange),
                ),
              if (result.downloadId == null) ...[
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
            ],
          ),
        ),
      ),
      actions: [
        if (result.downloadId != null)
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('下载录制文件'),
            onPressed: () {
              try {
                room.downloadRecording(result);
              } catch (error) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('下载失败: $error')));
              }
            },
          ),
        if (result.localFilePath != null && result.fileSizeBytes > 0)
          FilledButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text('导出录制文件'),
            onPressed: () async {
              try {
                final destination = await room.exportRecording(result);
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('录制文件已导出：$destination')));
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('导出未完成：$error')));
              }
            },
          ),
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
