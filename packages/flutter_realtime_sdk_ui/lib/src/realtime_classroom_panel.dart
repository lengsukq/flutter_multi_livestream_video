import 'package:flutter/material.dart';
import 'meeting_dock_realtime_classroom_panel_state.dart';

class RealtimeClassroomPanel extends StatefulWidget {
  const RealtimeClassroomPanel({
    super.key,
    this.onClose,
    this.showHeader = true,
  });
  final VoidCallback? onClose;
  final bool showHeader;

  @override
  State<RealtimeClassroomPanel> createState() =>
      MeetingDockRealtimeClassroomPanelState();
}
