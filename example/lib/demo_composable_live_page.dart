import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'demo_background.dart';

/// Supplies Demo content to the SDK's standard live page.
class DemoComposableLivePage extends StatelessWidget {
  const DemoComposableLivePage({
    super.key,
    required this.room,
    required this.initialSettings,
  });
  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  Widget build(BuildContext context) => RealtimeLivePage(
    room: room,
    initialSettings: initialSettings,
    loadImagePresets: () =>
        DemoBackground.loadPresets(isZh: RealtimeStrings.of(context).isZh),
  );
}
