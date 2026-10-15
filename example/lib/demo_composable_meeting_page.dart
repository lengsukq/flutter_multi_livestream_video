import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'demo_background.dart';
import 'demo_custom_interaction.dart';

/// The SDK owns the complete UI; the Demo injects sample content and events.
class DemoComposableMeetingPage extends StatelessWidget {
  const DemoComposableMeetingPage({
    super.key,
    required this.room,
    required this.initialSettings,
  });
  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  Widget build(BuildContext context) => RealtimeRoomView(
    room: room,
    config: RealtimeRoomViewConfig(initialMediaSettings: initialSettings),
    loadImagePresets: () =>
        DemoBackground.loadPresets(isZh: RealtimeStrings.of(context).isZh),
    onCustomReaction: room.interactions.capabilities.canPublish
        ? (_) => room.interactions.publish(DemoWaveInteraction.topic, {
            'sentAtMs': DateTime.now().millisecondsSinceEpoch,
          })
        : null,
    stageOverlayBuilder: (_) => DemoWaveOverlay(room: room),
  );
}
