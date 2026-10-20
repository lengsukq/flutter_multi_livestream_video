import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';

class RealtimeMediaDevicePicker extends StatelessWidget {
  const RealtimeMediaDevicePicker({super.key, required this.kind});

  final MediaDeviceKind kind;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canListMediaDevices(kind)) {
          return const SizedBox.shrink();
        }
        final zh = RealtimeStrings.of(context).isZh;
        final title = switch (kind) {
          MediaDeviceKind.microphone => zh ? '麦克风设备' : 'Microphone devices',
          MediaDeviceKind.camera => zh ? '摄像头设备' : 'Camera devices',
          MediaDeviceKind.audioOutput => zh ? '音频输出设备' : 'Audio outputs',
        };
        return OutlinedButton.icon(
          icon: Icon(switch (kind) {
            MediaDeviceKind.microphone => Icons.mic_outlined,
            MediaDeviceKind.camera => Icons.videocam_outlined,
            MediaDeviceKind.audioOutput => Icons.speaker_outlined,
          }),
          label: Text(title),
          onPressed: controller.isPending(RealtimeRoomUiAction.device)
              ? null
              : () async {
                  try {
                    final devices = await controller.listMediaDevices(kind);
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      useRootNavigator: true,
                      builder: (dialogContext) => RealtimeGlassDialog(
                        title: Text(title),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (devices.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(zh ? '没有可用设备' : 'No devices'),
                                ),
                              for (final device in devices)
                                ListTile(
                                  title: Text(device.label),
                                  subtitle:
                                      controller.canSelectMediaDevice(kind)
                                      ? null
                                      : Text(
                                          zh
                                              ? '当前不支持切换设备'
                                              : 'Selection unavailable',
                                        ),
                                  enabled: controller.canSelectMediaDevice(
                                    kind,
                                  ),
                                  onTap: () async {
                                    try {
                                      await controller.selectMediaDevice(
                                        device,
                                      );
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.maybeOf(
                                          dialogContext,
                                        )?.showSnackBar(
                                          SnackBar(content: Text('$error')),
                                        );
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(zh ? '关闭' : 'Close'),
                          ),
                        ],
                      ),
                    );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(
                        context,
                      )?.showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
        );
      },
    );
  }
}
