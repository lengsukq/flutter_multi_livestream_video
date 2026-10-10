import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';

typedef RealtimeRoomActionButtonBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      bool active,
      bool pending,
    );

/// A single standalone media action; can be moved anywhere in the app layout.
class RealtimeRoomActionButton extends StatelessWidget {
  const RealtimeRoomActionButton({
    super.key,
    required this.action,
    this.builder,
    this.label,
    this.iconOnly = false,
  });

  final RealtimeRoomUiAction action;
  final RealtimeRoomActionButtonBuilder? builder;
  final String? label;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final isZh = RealtimeStrings.of(context).isZh;
        final active = switch (action) {
          RealtimeRoomUiAction.microphone => !snapshot.localMuted,
          RealtimeRoomUiAction.camera => snapshot.localVideoEnabled,
          RealtimeRoomUiAction.screenShare => snapshot.localScreenShareEnabled,
          _ => false,
        };
        final supported = switch (action) {
          RealtimeRoomUiAction.microphone => controller.canUseMicrophone,
          RealtimeRoomUiAction.camera => controller.canUseCamera,
          RealtimeRoomUiAction.screenShare => controller.canShareScreen,
          RealtimeRoomUiAction.switchCamera => controller.canSwitchCamera,
          RealtimeRoomUiAction.audioOutput => false,
          RealtimeRoomUiAction.device => false,
          RealtimeRoomUiAction.leave => true,
          RealtimeRoomUiAction.sendMessage => controller.room.chat != null,
          RealtimeRoomUiAction.participantManagement => false,
          RealtimeRoomUiAction.classroom => false,
          RealtimeRoomUiAction.backgroundEffect => false,
          RealtimeRoomUiAction.liveLike =>
            controller.room.liveInteractions != null,
        };
        final pending = controller.isPending(action);
        final buttonLabel =
            label ??
            switch (action) {
              RealtimeRoomUiAction.microphone => isZh ? '麦克风' : 'Microphone',
              RealtimeRoomUiAction.camera => isZh ? '摄像头' : 'Camera',
              RealtimeRoomUiAction.screenShare =>
                isZh ? '共享屏幕' : 'Share screen',
              RealtimeRoomUiAction.switchCamera =>
                isZh ? '切换摄像头' : 'Switch camera',
              RealtimeRoomUiAction.audioOutput =>
                isZh ? '音频输出' : 'Audio output',
              RealtimeRoomUiAction.device => isZh ? '设备' : 'Devices',
              RealtimeRoomUiAction.leave => isZh ? '离开会议' : 'Leave meeting',
              RealtimeRoomUiAction.sendMessage => isZh ? '发送' : 'Send',
              RealtimeRoomUiAction.participantManagement =>
                isZh ? '成员管理' : 'Manage members',
              RealtimeRoomUiAction.classroom => isZh ? '课堂' : 'Classroom',
              RealtimeRoomUiAction.backgroundEffect =>
                isZh ? '虚拟背景' : 'Background effects',
              RealtimeRoomUiAction.liveLike => isZh ? '点赞' : 'Like',
            };
        final icon = switch (action) {
          RealtimeRoomUiAction.microphone => active ? Icons.mic : Icons.mic_off,
          RealtimeRoomUiAction.camera =>
            active ? Icons.videocam : Icons.videocam_off,
          RealtimeRoomUiAction.screenShare =>
            active ? Icons.stop_screen_share : Icons.screen_share,
          RealtimeRoomUiAction.switchCamera => Icons.cameraswitch,
          RealtimeRoomUiAction.audioOutput => Icons.speaker_outlined,
          RealtimeRoomUiAction.device => Icons.devices_outlined,
          RealtimeRoomUiAction.leave => Icons.call_end,
          RealtimeRoomUiAction.sendMessage => Icons.send,
          RealtimeRoomUiAction.participantManagement =>
            Icons.manage_accounts_outlined,
          RealtimeRoomUiAction.classroom => Icons.school_outlined,
          RealtimeRoomUiAction.backgroundEffect => Icons.blur_on_outlined,
          RealtimeRoomUiAction.liveLike => Icons.favorite_rounded,
        };
        void invoke() {
          Future<void> task() => switch (action) {
            RealtimeRoomUiAction.microphone => controller.toggleMicrophone(),
            RealtimeRoomUiAction.camera => controller.toggleCamera(),
            RealtimeRoomUiAction.screenShare => controller.toggleScreenShare(),
            RealtimeRoomUiAction.switchCamera => controller.switchCamera(),
            RealtimeRoomUiAction.audioOutput => Future.value(),
            RealtimeRoomUiAction.device => Future.value(),
            RealtimeRoomUiAction.leave => controller.leave(),
            RealtimeRoomUiAction.sendMessage => Future.value(),
            RealtimeRoomUiAction.participantManagement => Future.value(),
            RealtimeRoomUiAction.classroom => Future.value(),
            RealtimeRoomUiAction.backgroundEffect => Future.value(),
            RealtimeRoomUiAction.liveLike => controller.sendLiveLike(),
          };
          unawaited(
            task().catchError((Object error) {
              if (context.mounted) {
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }),
          );
        }

        final callback = supported && !pending ? invoke : null;
        if (builder != null) {
          return builder!(context, callback, active, pending);
        }
        if (iconOnly) {
          final isDanger =
              (action == RealtimeRoomUiAction.microphone && !active) ||
              (action == RealtimeRoomUiAction.camera && !active) ||
              action == RealtimeRoomUiAction.leave;
          return Tooltip(
            message: buttonLabel,
            child: IconButton.filledTonal(
              style: isDanger
                  ? IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.18),
                      foregroundColor: Colors.redAccent,
                    )
                  : (active
                        ? IconButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          )
                        : null),
              onPressed: callback,
              icon: pending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon),
            ),
          );
        }
        return Tooltip(
          message: buttonLabel,
          child: FilledButton.tonalIcon(
            onPressed: callback,
            icon: pending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            label: Text(buttonLabel),
          ),
        );
      },
    );
  }
}

/// One standalone device picker for microphone/camera/output. Providers that
/// cannot enumerate devices show no control; selection remains read-only when
/// an adapter can enumerate but cannot change the selected device.
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
                      builder: (dialogContext) => SimpleDialog(
                        title: Text(title),
                        children: [
                          if (devices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(zh ? '没有可用设备' : 'No devices'),
                            ),
                          for (final device in devices)
                            ListTile(
                              title: Text(device.label),
                              subtitle: controller.canSelectMediaDevice(kind)
                                  ? null
                                  : Text(
                                      zh
                                          ? '当前不支持切换设备'
                                          : 'Selection unavailable',
                                    ),
                              enabled: controller.canSelectMediaDevice(kind),
                              onTap: () async {
                                try {
                                  await controller.selectMediaDevice(device);
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

class RealtimeSwitchCameraButton extends StatelessWidget {
  const RealtimeSwitchCameraButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.switchCamera,
    iconOnly: iconOnly,
  );
}

/// Audio output picker without owning a screen, route or SDK session.
/// Providers may offer listing but not device selection: those entries stay
/// visible as read-only capabilities instead of silently dispatching commands.
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

class RealtimeMicrophoneButton extends StatelessWidget {
  const RealtimeMicrophoneButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.microphone,
    iconOnly: iconOnly,
  );
}

class RealtimeCameraButton extends StatelessWidget {
  const RealtimeCameraButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.camera,
    iconOnly: iconOnly,
  );
}

class RealtimeScreenShareButton extends StatelessWidget {
  const RealtimeScreenShareButton({super.key, this.iconOnly = false});
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => RealtimeRoomActionButton(
    action: RealtimeRoomUiAction.screenShare,
    iconOnly: iconOnly,
  );
}

/// Independent leave button; caller decides confirmation and navigation.
class RealtimeLeaveButton extends StatelessWidget {
  const RealtimeLeaveButton({
    super.key,
    this.onConfirm,
    this.onLeft,
    this.closeForEveryone,
    this.iconOnly = false,
  });

  final Future<bool> Function(BuildContext context)? onConfirm;
  final VoidCallback? onLeft;

  /// Null retains the SDK default: a broadcast host with close rights ends it.
  final bool? closeForEveryone;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final leaveAction = controller.isPending(RealtimeRoomUiAction.leave)
            ? null
            : () async {
                if (onConfirm != null && !await onConfirm!(context)) return;
                try {
                  await controller.leave(closeForEveryone: closeForEveryone);
                  if (context.mounted) onLeft?.call();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(
                      context,
                    )?.showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              };
        final label = RealtimeStrings.of(context).leave;
        if (iconOnly) {
          return Tooltip(
            message: label,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.88),
                foregroundColor: Colors.white,
              ),
              onPressed: leaveAction,
              icon: const Icon(Icons.call_end),
            ),
          );
        }
        return FilledButton.icon(
          onPressed: leaveAction,
          icon: const Icon(Icons.call_end),
          label: Text(label),
        );
      },
    );
  }
}
