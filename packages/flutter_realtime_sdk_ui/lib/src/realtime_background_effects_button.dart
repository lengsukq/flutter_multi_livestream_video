import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';

class RealtimeBackgroundEffectsButton extends StatelessWidget {
  const RealtimeBackgroundEffectsButton({
    super.key,
    this.imagePresets = const [],
    this.iconOnly = false,
  });

  final List<MediaBackgroundImagePreset> imagePresets;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (!controller.room.backgroundCapabilities.isSupported) {
      return const SizedBox.shrink();
    }
    void openSheet() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BackgroundEffectSelector(
              capabilities: controller.room.backgroundCapabilities,
              effect: controller.room.backgroundEffect,
              imagePresets: imagePresets,
              busy: controller.isPending(RealtimeRoomUiAction.backgroundEffect),
              onChanged: (effect) async {
                try {
                  await controller.setBackgroundEffect(effect);
                  if (sheetContext.mounted) updateSheet(() {});
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
    );

    if (iconOnly) {
      return Tooltip(
        message: RealtimeStrings.of(context).backgroundEffects,
        child: IconButton.filledTonal(
          onPressed: openSheet,
          icon: const Icon(Icons.blur_on_outlined),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: openSheet,
      icon: const Icon(Icons.blur_on_outlined),
      label: Text(RealtimeStrings.of(context).backgroundEffects),
    );
  }
}
