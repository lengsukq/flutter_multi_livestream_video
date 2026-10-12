import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'composable_pre_join_controller.dart';
import 'composable_pre_join_components.dart';
import 'media_background_image_preset.dart';

/// Optional quick-start Pre-Join layout built from public independent widgets.
///
/// The caller owns [controller] and must initialize/dispose it. Neither this
/// template nor individual controls release the room on widget unmount.
class RealtimeComposablePreJoinTemplate extends StatelessWidget {
  const RealtimeComposablePreJoinTemplate({
    super.key,
    required this.controller,
    required this.onEnter,
    this.onBack,
    this.imagePresets = const [],
    this.title = 'Pre-Join',
  });

  final RealtimePreJoinController controller;
  final Future<void> Function(MediaLocalPreviewSettings) onEnter;
  final VoidCallback? onBack;
  final List<MediaBackgroundImagePreset> imagePresets;
  final String title;

  @override
  Widget build(BuildContext context) => RealtimePreJoinScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: onBack == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: controller.joining ? null : onBack,
                ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final preview = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: RealtimePreJoinPreview(),
                  ),
                  RealtimePreJoinCheckList(),
                ],
              );
              final settings = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RealtimePreJoinMediaControls(),
                  const RealtimePreJoinDevicePicker(
                    kind: MediaDeviceKind.microphone,
                  ),
                  const RealtimePreJoinDevicePicker(
                    kind: MediaDeviceKind.camera,
                  ),
                  const RealtimePreJoinDevicePicker(
                    kind: MediaDeviceKind.audioOutput,
                  ),
                  RealtimePreJoinBackgroundSelector(imagePresets: imagePresets),
                ],
              );
              return Column(
                children: [
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: preview,
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: settings,
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [preview, settings],
                          ),
                  ),
                  if (controller.joinError != null ||
                      controller.error != null ||
                      controller.previewError != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${controller.joinError ?? controller.error ?? controller.previewError}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: controller.busy
                              ? null
                              : controller.initialize,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check again'),
                        ),
                        RealtimePreJoinJoinButton(onEnter: onEnter),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
