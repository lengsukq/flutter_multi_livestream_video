import 'package:flutter/material.dart';
import 'meeting_dock_realtime_classroom_panel_state.dart';

class RealtimeClassroomPanel extends StatefulWidget {
  const RealtimeClassroomPanel({
    super.key,
    this.onClose,
    this.showHeader = true,
    this.initialTab = 0,
  }) : assert(initialTab >= 0 && initialTab < 4);
  final VoidCallback? onClose;
  final bool showHeader;

  /// 0: questions, 1: raised hands, 2: roster, 3: activities.
  final int initialTab;

  @override
  State<RealtimeClassroomPanel> createState() =>
      MeetingDockRealtimeClassroomPanelState();
}
