import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

extension RealtimeMeetingModeLabel on MediaMeetingMode {
  String label({required bool isZh}) => switch (this) {
    MediaMeetingMode.standard => isZh ? '普通会议' : 'Standard meeting',
    MediaMeetingMode.classroom => isZh ? '课堂模式' : 'Classroom',
  };
}

/// Optional meeting policy picker for host applications' creation forms.
class RealtimeMeetingModeSelector extends StatelessWidget {
  const RealtimeMeetingModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final MediaMeetingMode value;
  final ValueChanged<MediaMeetingMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final isZh = RealtimeStrings.of(context).isZh;
    return RealtimeCupertinoSegmentedBar<MediaMeetingMode>(
      groupValue: value,
      onValueChanged: onChanged,
      children: {
        for (final mode in MediaMeetingMode.values)
          mode: Text(mode.label(isZh: isZh)),
      },
    );
  }
}
