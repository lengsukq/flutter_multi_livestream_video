import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart' show RealtimeRoomUiAction;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';

class RealtimeAudioOutputButton extends StatelessWidget {
  const RealtimeAudioOutputButton({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canListAudioOutputs) {
          return const SizedBox.shrink();
        }
        final zh = RealtimeStrings.of(context).isZh;
        final title = zh ? '音频输出' : 'Audio output';
        Future<void> openDialog() async {
          try {
            final devices = await controller.listAudioOutputs();
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              useRootNavigator: true,
              builder: (dialogContext) => SimpleDialog(
                title: Text(zh ? '音频输出设备' : 'Audio output devices'),
                children: [
                  if (devices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(zh ? '没有可用设备' : 'No devices'),
                    ),
                  for (final device in devices)
                    ListTile(
                      title: Text(device.label),
                      subtitle: controller.canSelectAudioOutput
                          ? null
                          : Text(zh ? '当前设备不支持切换' : 'Selection unavailable'),
                      enabled: controller.canSelectAudioOutput,
                      onTap: () async {
                        try {
                          await controller.selectAudioOutput(device);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.maybeOf(
                              dialogContext,
                            )?.showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            );
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        }

        if (iconOnly) {
          return Tooltip(
            message: title,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.speaker_outlined),
              onPressed: controller.isPending(RealtimeRoomUiAction.audioOutput)
                  ? null
                  : openDialog,
            ),
          );
        }

        return OutlinedButton.icon(
          icon: const Icon(Icons.speaker_outlined),
          label: Text(title),
          onPressed: controller.isPending(RealtimeRoomUiAction.audioOutput)
              ? null
              : openDialog,
        );
      },
    );
  }
}

/// Optional background controls; the host decides the button's location and
/// supplies its own image presets. SDK controls video-effect processing.
