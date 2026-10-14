import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Demo presentation only. The provider-neutral SDK exposes the options and
/// the backend is authoritative about what can actually be recorded.
Future<RecordingLayout?> chooseCloudRecordingLayout(
  BuildContext context,
  RealtimeRoom room,
) async {
  final status = await room.queryCloudRecording();
  if (!context.mounted) return null;
  if (status.metadata['recordingAvailable'] == false) {
    throw StateError(
      status.metadata['recordingUnavailableReason']?.toString() ??
          'Cloud recording is not configured.',
    );
  }
  // A backend without capability negotiation must never be assumed to support
  // a focus layout. Its basic grid mode is the only safe fallback.
  final raw = status.metadata['supportedLayouts'];
  final supported = raw is List
      ? raw.whereType<String>().toSet()
      : <String>{'grid'};
  final choices = [
    RecordingLayout.grid,
    RecordingLayout.featuredParticipant,
    RecordingLayout.activeSpeaker,
  ].where((mode) => supported.contains(mode.name)).toList();
  if (choices.isEmpty) {
    throw StateError('No supported cloud recording layouts were reported.');
  }

  final zh = Localizations.localeOf(context).languageCode == 'zh';
  String title(RecordingLayout mode) => switch (mode) {
    RecordingLayout.grid => zh ? '宫格录制' : 'Grid recording',
    RecordingLayout.featuredParticipant => zh
        ? '固定主画面（不跟随发言）'
        : 'Featured participant (does not follow speech)',
    RecordingLayout.activeSpeaker => zh
        ? '动态发言人（自动切换）'
        : 'Active speaker (switches automatically)',
    _ => mode.name,
  };
  String subtitle(RecordingLayout mode) => switch (mode) {
    RecordingLayout.grid => zh ? '所有视频均匀排列' : 'Equal-sized participant tiles',
    RecordingLayout.featuredParticipant => zh
        ? '由云服务端选择主要画面，其他画面悬浮或缩略显示'
        : 'Cloud backend picks the featured tile; other tiles remain smaller',
    RecordingLayout.activeSpeaker => zh
        ? '使用支持语音聚焦的供应商录制模板'
        : 'Requires a provider recording template with speaker tracking',
    _ => '',
  };
  return showDialog<RecordingLayout>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(zh ? '选择云端录制布局' : 'Cloud recording layout'),
      children: choices.map((mode) => SimpleDialogOption(
        onPressed: () => Navigator.pop(dialogContext, mode),
        child: ListTile(
          leading: Icon(switch (mode) {
            RecordingLayout.grid => Icons.grid_view,
            RecordingLayout.featuredParticipant => Icons.person_pin,
            _ => Icons.record_voice_over,
          }),
          title: Text(title(mode)),
          subtitle: Text(subtitle(mode)),
        ),
      )).toList(),
    ),
  );
}
