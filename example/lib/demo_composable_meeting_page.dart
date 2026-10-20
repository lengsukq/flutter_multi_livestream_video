import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'demo_background.dart';
import 'demo_custom_interaction.dart';

/// The SDK owns the complete UI; the Demo supplies configuration and events.
/// Room identity comes from the backend rather than the teaching preview.
class DemoComposableMeetingPage extends StatelessWidget {
  const DemoComposableMeetingPage({
    super.key,
    required this.room,
    required this.initialSettings,
    this.initialSharedContentMode,
  });
  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;
  final SharedContentMode? initialSharedContentMode;

  bool get _hasClassroom => room.classroom != null;

  @override
  Widget build(BuildContext context) => RealtimeRoomView(
    room: room,
    config: RealtimeRoomViewConfig(
      initialMediaSettings: initialSettings,
      initialSharedContentMode: initialSharedContentMode,
    ),
    loadImagePresets: () =>
        DemoBackground.loadPresets(isZh: RealtimeStrings.of(context).isZh),
    onCustomReaction: room.interactions.capabilities.canPublish
        ? (_) => room.interactions.publish(DemoWaveInteraction.topic, {
            'sentAtMs': DateTime.now().millisecondsSinceEpoch,
          })
        : null,
    stageOverlayBuilder: (_) => DemoWaveOverlay(room: room),
  );

  /// Kept for callers that need the classroom flag before the page mounts.
  bool get hasClassroom => _hasClassroom;
}
