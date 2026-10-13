import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_live_components_realtime_host_tools_panel_state.dart';

class RealtimeHostToolsPanel extends StatefulWidget {
  const RealtimeHostToolsPanel({
    super.key,
    this.showHeader = false,
    this.onClose,
    this.imagePresets = const [],
    this.imagePresetsFuture,
    this.extraTools = const [],
  });

  final bool showHeader;
  final VoidCallback? onClose;
  final List<MediaBackgroundImagePreset> imagePresets;
  final Future<List<MediaBackgroundImagePreset>>? imagePresetsFuture;
  final List<Widget> extraTools;

  @override
  State<RealtimeHostToolsPanel> createState() =>
      RoomLiveComponentsRealtimeHostToolsPanelState();
}
