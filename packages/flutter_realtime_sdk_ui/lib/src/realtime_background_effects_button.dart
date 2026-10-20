import 'dart:async';

import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';

/// A provider-neutral bottom sheet shared by prebuilt and composable room UIs.
///
/// A publisher without video-effect support sees a clear explanation instead
/// of a dead button or an empty sheet. A viewer should not expose this action.
Future<void> showRealtimeBackgroundEffectsSheet(
  BuildContext context, {
  List<MediaBackgroundImagePreset> imagePresets = const [],
  Future<List<MediaBackgroundImagePreset>> Function()? loadImagePresets,
}) async {
  final controller = RealtimeRoomUiScope.of(context);
  final strings = RealtimeStrings.of(context);
  if (!controller.snapshot.capabilities.canPublishVideo) return;
  if (!controller.room.backgroundCapabilities.isSupported) {
    await showRealtimeGlassBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.virtualBackground,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                strings.isZh
                    ? '当前平台、服务或设备暂不支持背景特效。'
                    : 'Background effects are unavailable on this platform, service or device.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(strings.isZh ? '知道了' : 'OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }
  var presets = imagePresets;
  if (loadImagePresets != null) {
    try {
      presets = await loadImagePresets();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
  if (!context.mounted) return;
  await showRealtimeGlassBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ListenableBuilder(
            listenable: controller,
            builder: (sheetContext, _) => BackgroundEffectSelector(
              capabilities: controller.room.backgroundCapabilities,
              effect: controller.room.backgroundEffect,
              imagePresets: presets,
              busy: controller.isPending(RealtimeRoomUiAction.backgroundEffect),
              onChanged: (effect) async {
                try {
                  await controller.setBackgroundEffect(effect);
                } catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.maybeOf(
                      sheetContext,
                    )?.showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class RealtimeBackgroundEffectsButton extends StatelessWidget {
  const RealtimeBackgroundEffectsButton({
    super.key,
    this.imagePresets = const [],
    this.loadImagePresets,
    this.iconOnly = false,
  });

  final List<MediaBackgroundImagePreset> imagePresets;
  final Future<List<MediaBackgroundImagePreset>> Function()? loadImagePresets;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (!controller.snapshot.capabilities.canPublishVideo) {
      return const SizedBox.shrink();
    }
    void openSheet() => unawaited(
      showRealtimeBackgroundEffectsSheet(
        context,
        imagePresets: imagePresets,
        loadImagePresets: loadImagePresets,
      ),
    );

    if (iconOnly) {
      return Tooltip(
        message: RealtimeStrings.of(context).virtualBackground,
        child: IconButton.filledTonal(
          onPressed: openSheet,
          icon: const Icon(Icons.blur_on_outlined),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: openSheet,
      icon: const Icon(Icons.blur_on_outlined),
      label: Text(RealtimeStrings.of(context).virtualBackground),
    );
  }
}
