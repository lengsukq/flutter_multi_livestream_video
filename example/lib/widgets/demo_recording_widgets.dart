import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import '../demo_strings.dart';
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
                    widget.room.recording.currentOptions?.mode ==
                            RecordingMode.cloud
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
///
/// Renders as [RealtimeDockItem]s so it matches the meeting dock.
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
  RecordingResult? _lastCloudResult;
  bool? _cloudRecordingAvailable;
  String? _cloudUnavailableReason;
  bool get _isCloudRoom =>
      const {
        'livekit',
        'trtc',
        'agora',
        'artc',
        'chime',
        'ivs',
      }.contains(widget.room.engineProviderId) &&
      widget.room.featureBackendUrl != null;

  @override
  void initState() {
    super.initState();
    if (_isCloudRoom && widget.room.media.isLogicalOwner) {
      _checkCloudRecordingAvailability();
    }
  }

  Future<void> _checkCloudRecordingAvailability() async {
    try {
      final result = await widget.room.queryCloudRecording();
      if (!mounted) return;
      setState(() {
        _cloudRecordingAvailable =
            result.metadata['recordingAvailable'] as bool?;
        _cloudUnavailableReason =
            result.metadata['recordingUnavailableReason'] as String?;
      });
    } catch (_) {
      // Keep the actual recording action available when preflight fails due to
      // a transient network/auth issue. The SDK still returns the real error.
    }
  }

  Future<void> _toggleRecording() async {
    if (_operating) return;
    final strings = DemoStrings.of(context);
    if (_isCloudRoom &&
        widget.room.recordingStatus != RecordingStatus.recording &&
        _cloudRecordingAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.recordingUnavailableReason(
              _cloudUnavailableReason ?? strings.recordingUnavailable,
            ),
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    var layout = RecordingLayout.grid;
    if (_isCloudRoom &&
        widget.room.recordingStatus != RecordingStatus.recording) {
      final chosen = await showDialog<RecordingLayout>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(strings.chooseCloudRecordingLayout),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.grid),
              child: ListTile(
                leading: const Icon(Icons.grid_view),
                title: Text(strings.gridModePreferred),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.speaker),
              child: ListTile(
                leading: const Icon(Icons.person_pin),
                title: Text(strings.speakerMode),
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
                _isCloudRoom
                    ? strings.recordingCloudPending
                    : strings.recordingLocalPending,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.recordingActionFailed(e)),
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
        final strings = DemoStrings.of(context);
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
              return RealtimeDockItem(
                icon: Icons.stop_circle_outlined,
                label: _isCloudRoom
                    ? '${strings.stopCloudRecording} ($m:$s)'
                    : '${strings.record} ($m:$s)',
                isDanger: true,
                isLoading: _operating,
                showLabel: widget.showLabel,
                onPressed: _operating ? null : _toggleRecording,
              );
            }

            if (_isCloudRoom) {
              // Meeting creators use participant media role but hold the
              // room-owner credential. They must not be treated as viewers.
              final canRecord = widget.room.media.isLogicalOwner;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RealtimeDockItem(
                    icon: Icons.cloud_download_outlined,
                    label: strings.viewRecordingResult,
                    showBadgeDot: _lastCloudResult != null,
                    showLabel: widget.showLabel,
                    onPressed: _operating || !canRecord
                        ? null
                        : _showCloudResultDialog,
                  ),
                  RealtimeDockItem(
                    icon: Icons.cloud_circle_outlined,
                    label: _cloudRecordingAvailable == false
                        ? strings.recordingUnavailable
                        : strings.cloudRecording,
                    isLoading: _operating,
                    showLabel: widget.showLabel,
                    onPressed: _operating || !canRecord
                        ? null
                        : _toggleRecording,
                  ),
                ],
              );
            }

            return Opacity(
              opacity: 0.5,
              child: RealtimeDockItem(
                icon: Icons.cloud_off_outlined,
                label: strings.cloudRecording,
                tooltip: widget.room.capabilities.media.canRecordLocal
                    ? strings.recordingLocalPending
                    : strings.cloudRecordingUnsupported,
                showLabel: widget.showLabel,
              ),
            );
          },
        );
      },
    );
  }
}

/// A menu-ready ListTile item for cloud/local recording inside [RealtimeDockMoreButton].
class DemoRecordingListTile extends StatefulWidget {
  const DemoRecordingListTile({super.key, required this.room});

  final RealtimeRoom room;

  @override
  State<DemoRecordingListTile> createState() => _DemoRecordingListTileState();
}

class _DemoRecordingListTileState extends State<DemoRecordingListTile> {
  bool _operating = false;
  RecordingResult? _lastCloudResult;
  bool? _cloudRecordingAvailable;
  String? _cloudUnavailableReason;
  bool get _isCloudRoom =>
      const {
        'livekit',
        'trtc',
        'agora',
        'artc',
        'chime',
        'ivs',
      }.contains(widget.room.engineProviderId) &&
      widget.room.featureBackendUrl != null;

  @override
  void initState() {
    super.initState();
    if (_isCloudRoom && widget.room.media.isLogicalOwner) {
      _checkCloudRecordingAvailability();
    }
  }

  Future<void> _checkCloudRecordingAvailability() async {
    try {
      final result = await widget.room.queryCloudRecording();
      if (!mounted) return;
      setState(() {
        _cloudRecordingAvailable =
            result.metadata['recordingAvailable'] as bool?;
        _cloudUnavailableReason =
            result.metadata['recordingUnavailableReason'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_operating) return;
    final strings = DemoStrings.of(context);
    if (_isCloudRoom &&
        widget.room.recordingStatus != RecordingStatus.recording &&
        _cloudRecordingAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.recordingUnavailableReason(
              _cloudUnavailableReason ?? strings.recordingUnavailable,
            ),
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    var layout = RecordingLayout.grid;
    if (_isCloudRoom &&
        widget.room.recordingStatus != RecordingStatus.recording) {
      final chosen = await showDialog<RecordingLayout>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(strings.chooseCloudRecordingLayout),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.grid),
              child: ListTile(
                leading: const Icon(Icons.grid_view),
                title: Text(strings.gridModePreferred),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, RecordingLayout.speaker),
              child: ListTile(
                leading: const Icon(Icons.person_pin),
                title: Text(strings.speakerMode),
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
          final result = await widget.room.startRecording(
            RecordingOptions.local(),
          );
          if (mounted) {
            _showResultDialog(result);
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  void _showResultDialog(RecordingResult result) {
    showDialog<void>(
      context: context,
      builder: (_) =>
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
        final strings = DemoStrings.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final status = snapshot.data ?? RecordingStatus.idle;
        final isRecording = status == RecordingStatus.recording;
        final canRecord = widget.room.media.isLogicalOwner;

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
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.stop_circle_outlined,
                    color: Color(0xFFFF3B30),
                    size: 22,
                  ),
                ),
                title: Text(
                  _isCloudRoom
                      ? '${strings.stopCloudRecording} ($m:$s)'
                      : '${strings.record} ($m:$s)',
                  style: const TextStyle(
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  strings.isZh ? '点击停止本次录制' : 'Tap to stop recording',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: _operating
                    ? null
                    : () {
                        Navigator.maybePop(context);
                        unawaited(_toggleRecording());
                      },
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  enabled: canRecord && !_operating,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.cloud_circle_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    _cloudRecordingAvailable == false
                        ? strings.recordingUnavailable
                        : strings.cloudRecording,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    strings.isZh ? '启动音视频录制' : 'Start audio/video recording',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.maybePop(context);
                    unawaited(_toggleRecording());
                  },
                ),
                if (_lastCloudResult != null) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.iosBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_download_outlined,
                        color: RealtimeUiTokens.iosBlue,
                        size: 22,
                      ),
                    ),
                    title: Text(strings.viewRecordingResult),
                    subtitle: Text(
                      strings.isZh ? '查看云录制文件与回放' : 'Inspect cloud recordings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      Navigator.maybePop(context);
                      _showCloudResultDialog();
                    },
                  ),
                ],
              ],
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
