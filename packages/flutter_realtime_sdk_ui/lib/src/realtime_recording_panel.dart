import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

import '../flutter_realtime_sdk_ui.dart';

/// Recording studio panel backed by the room's cloud recording controller.
///
/// Shows only authoritative values: task status, elapsed duration and whether
/// a finished file can be downloaded. It deliberately has no fake toggles for
/// chat/captions/chapters or a fabricated storage quota.
class RealtimeRecordingPanel extends StatelessWidget {
  const RealtimeRecordingPanel({
    super.key,
    required this.room,
    required this.onToggleRecording,
    required this.onOpenResult,
    this.busy = false,
  });

  final RealtimeRoom room;
  final VoidCallback onToggleRecording;
  final VoidCallback onOpenResult;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);
    final zh = strings.isZh;
    return StreamBuilder<RecordingStatus>(
      stream: room.recordingStatuses,
      initialData: room.recordingStatus,
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data ?? RecordingStatus.idle;
        final recording = status == RecordingStatus.recording;
        final starting = status == RecordingStatus.starting;
        final stopping = status == RecordingStatus.stopping;
        final processing = status == RecordingStatus.processing;
        final canManage =
            room.recording.isConfigured && room.media.isLogicalOwner;
        final options = room.recording.currentOptions;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            StreamBuilder<Duration>(
              stream: room.recordingDurations,
              initialData: room.recording.duration,
              builder: (context, durationSnapshot) {
                final elapsed = durationSnapshot.data ?? Duration.zero;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _format(elapsed),
                            style: TextStyle(
                              fontFamily: RealtimeFonts.displayOf(context),
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: style.text,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: recording || starting
                                      ? style.live
                                      : style.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _statusLabel(status, zh: zh),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: recording || starting
                                        ? style.live
                                        : style.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _RoundAction(
                      icon: recording
                          ? Icons.stop_rounded
                          : Icons.fiber_manual_record_rounded,
                      danger: recording,
                      busy: busy || starting || stopping || processing,
                      tooltip: recording
                          ? (zh ? '停止录制' : 'Stop recording')
                          : (zh ? '开始录制' : 'Start recording'),
                      onPressed: !canManage || status == RecordingStatus.unknown
                          ? null
                          : onToggleRecording,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                border: Border.all(color: style.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zh ? '录制内容' : "What's being recorded",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: style.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (options != null) ...[
                    _SettingRow(
                      icon: Icons.dashboard_outlined,
                      label: zh ? '布局' : 'Layout',
                      value: switch (options.layout) {
                        RecordingLayout.grid => zh ? '宫格' : 'Grid',
                        RecordingLayout.screenShare =>
                          zh ? '共享画面' : 'Screen share',
                        RecordingLayout.featuredParticipant =>
                          zh ? '指定成员' : 'Featured participant',
                        RecordingLayout.activeSpeaker =>
                          zh ? '发言人' : 'Active speaker',
                        _ => zh ? '后端模板' : 'Backend template',
                      },
                    ),
                    _SettingRow(
                      icon: Icons.mic_none_rounded,
                      label: zh ? '媒体' : 'Media',
                      value: switch (options.streamType) {
                        RecordingStreamType.audioOnly =>
                          zh ? '仅音频' : 'Audio only',
                        RecordingStreamType.videoOnly =>
                          zh ? '仅视频' : 'Video only',
                        RecordingStreamType.both =>
                          zh ? '音视频' : 'Audio and video',
                      },
                    ),
                    _SettingRow(
                      icon: Icons.cloud_outlined,
                      label: zh ? '输出' : 'Output',
                      value: zh ? '云端录制' : 'Cloud recording',
                    ),
                  ] else
                    Text(
                      zh
                          ? '开始录制时选择布局，实际内容由后端模板决定。'
                          : 'Choose a layout when starting. Captured content depends on the backend template.',
                      style: TextStyle(fontSize: 13, color: style.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: status == RecordingStatus.idle ? null : onOpenResult,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(zh ? '查看录制结果' : 'View recording result'),
            ),
            const SizedBox(height: 8),
            Text(
              zh
                  ? '布局与画质由后端录制模板决定，停止后仍会继续处理一段时间。'
                  : 'Layout and quality come from the backend template; processing continues after stopping.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: style.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(Duration value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.inHours)}:${two(value.inMinutes.remainder(60))}:${two(value.inSeconds.remainder(60))}';
  }

  static String _statusLabel(RecordingStatus status, {required bool zh}) =>
      switch (status) {
        RecordingStatus.idle => zh ? '未开始录制' : 'Not recording',
        RecordingStatus.starting => zh ? '正在启动录制' : 'Starting recording',
        RecordingStatus.recording => zh ? '正在录制到云端' : 'Recording to cloud',
        RecordingStatus.stopping => zh ? '正在停止录制' : 'Stopping recording',
        RecordingStatus.processing => zh ? '云端处理中' : 'Processing in cloud',
        RecordingStatus.completed => zh ? '录制已完成' : 'Recording complete',
        RecordingStatus.failed => zh ? '录制失败' : 'Recording failed',
        RecordingStatus.unknown => zh ? '状态未知' : 'Status unknown',
      };
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: style.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: style.text),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, color: style.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.busy,
    required this.danger,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: danger ? style.live : style.surface,
        shape: CircleBorder(
          side: BorderSide(color: danger ? style.live : style.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: danger ? Colors.white : style.text,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: danger ? Colors.white : style.text,
                  ),
          ),
        ),
      ),
    );
  }
}
