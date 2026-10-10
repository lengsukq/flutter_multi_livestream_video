import 'dart:async';

import 'package:flutter/material.dart';
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
  });

  final RealtimeRoomUiAction action;
  final RealtimeRoomActionButtonBuilder? builder;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final isZh = Localizations.localeOf(context).languageCode == 'zh';
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

class RealtimeSwitchCameraButton extends StatelessWidget {
  const RealtimeSwitchCameraButton({super.key});
  @override
  Widget build(BuildContext context) =>
      const RealtimeRoomActionButton(action: RealtimeRoomUiAction.switchCamera);
}

/// Audio output picker without owning a screen, route or SDK session.
/// Providers may offer listing but not device selection: those entries stay
/// visible as read-only capabilities instead of silently dispatching commands.
class RealtimeAudioOutputButton extends StatelessWidget {
  const RealtimeAudioOutputButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canListAudioOutputs) {
          return const SizedBox.shrink();
        }
        final zh = Localizations.localeOf(context).languageCode == 'zh';
        return OutlinedButton.icon(
          icon: const Icon(Icons.speaker_outlined),
          label: Text(zh ? '音频输出' : 'Audio output'),
          onPressed: controller.isPending(RealtimeRoomUiAction.audioOutput)
              ? null
              : () async {
                  try {
                    final devices = await controller.listAudioOutputs();
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
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
                                  : Text(
                                      zh
                                          ? '当前设备不支持切换'
                                          : 'Selection unavailable',
                                    ),
                              enabled: controller.canSelectAudioOutput,
                              onTap: () async {
                                try {
                                  await controller.selectAudioOutput(device);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
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
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                },
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
  });

  final List<MediaBackgroundImagePreset> imagePresets;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (!controller.room.backgroundCapabilities.isSupported) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      onPressed: () => showModalBottomSheet<void>(
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
                busy: controller.isPending(
                  RealtimeRoomUiAction.backgroundEffect,
                ),
                onChanged: (effect) async {
                  try {
                    await controller.setBackgroundEffect(effect);
                    if (sheetContext.mounted) updateSheet(() {});
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.maybeOf(sheetContext)?.showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ),
      icon: const Icon(Icons.blur_on_outlined),
      label: Text(
        Localizations.localeOf(context).languageCode == 'zh'
            ? '虚拟背景'
            : 'Background',
      ),
    );
  }
}

class RealtimeMicrophoneButton extends StatelessWidget {
  const RealtimeMicrophoneButton({super.key});
  @override
  Widget build(BuildContext context) =>
      const RealtimeRoomActionButton(action: RealtimeRoomUiAction.microphone);
}

class RealtimeCameraButton extends StatelessWidget {
  const RealtimeCameraButton({super.key});
  @override
  Widget build(BuildContext context) =>
      const RealtimeRoomActionButton(action: RealtimeRoomUiAction.camera);
}

class RealtimeScreenShareButton extends StatelessWidget {
  const RealtimeScreenShareButton({super.key});
  @override
  Widget build(BuildContext context) =>
      const RealtimeRoomActionButton(action: RealtimeRoomUiAction.screenShare);
}

/// Independent leave button; caller decides confirmation and navigation.
class RealtimeLeaveButton extends StatelessWidget {
  const RealtimeLeaveButton({
    super.key,
    this.onConfirm,
    this.onLeft,
    this.closeForEveryone,
  });

  final Future<bool> Function(BuildContext context)? onConfirm;
  final VoidCallback? onLeft;

  /// Null retains the SDK default: a broadcast host with close rights ends it.
  final bool? closeForEveryone;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => FilledButton.icon(
        onPressed: controller.isPending(RealtimeRoomUiAction.leave)
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
              },
        icon: const Icon(Icons.call_end),
        label: Text(
          Localizations.localeOf(context).languageCode == 'zh'
              ? '离开会议'
              : 'Leave meeting',
        ),
      ),
    );
  }
}
