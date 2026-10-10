import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'background_effect_selector.dart';
import 'composable_pre_join_controller.dart';
import 'media_background_image_preset.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

/// Shares one Pre-Join controller across freely arranged child widgets.
class RealtimePreJoinScope extends InheritedWidget {
  const RealtimePreJoinScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final RealtimePreJoinController controller;

  static RealtimePreJoinController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RealtimePreJoinScope>();
    assert(
      scope != null,
      'A RealtimePreJoinScope is required above this component',
    );
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(RealtimePreJoinScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

/// Displays only the SDK local preview, no fixed page or device panel.
class RealtimePreJoinPreview extends StatelessWidget {
  const RealtimePreJoinPreview({super.key, this.placeholder});
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preview = controller.preview;
        if (preview == null) {
          return placeholder ??
              const Center(child: Icon(Icons.videocam_off_outlined, size: 56));
        }
        return MediaTrackView(
          renderer: preview.renderer,
          track: preview.cameraTrack,
          fit: BoxFit.contain,
          placeholder:
              placeholder ??
              const Center(child: Icon(Icons.videocam_off_outlined, size: 56)),
        );
      },
    );
  }
}

/// Provider-agnostic backend, permission and device readiness checks.
class RealtimePreJoinCheckList extends StatelessWidget {
  const RealtimePreJoinCheckList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final checks = controller.result?.checks ?? const <MediaPreJoinCheck>[];
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return Text(
            controller.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final check in checks)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(
                      check.passed
                          ? Icons.check_circle_rounded
                          : check.isBlocking
                          ? Icons.error_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: check.passed
                          ? Theme.of(context).colorScheme.tertiary
                          : check.isBlocking
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.preJoinCheckDescription(check),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (check.isBlocking)
                      Text(
                        strings.requiredLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// iOS-style expandable Readiness Card summarizing pre-join checks.
class RealtimePreJoinReadinessCard extends StatefulWidget {
  const RealtimePreJoinReadinessCard({
    super.key,
    this.initiallyExpanded = false,
  });

  final bool initiallyExpanded;

  @override
  State<RealtimePreJoinReadinessCard> createState() =>
      _RealtimePreJoinReadinessCardState();
}

class _RealtimePreJoinReadinessCardState
    extends State<RealtimePreJoinReadinessCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final strings = RealtimeStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final result = controller.result;
        final checks = result?.checks ?? const <MediaPreJoinCheck>[];
        final isReady = result?.isReady ?? false;
        final hasBlocking = checks.any((c) => !c.passed && c.isBlocking);

        final statusColor = isReady
            ? RealtimeUiTokens.iosGreen
            : hasBlocking
            ? RealtimeUiTokens.danger
            : RealtimeUiTokens.warning;

        return RealtimeCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isReady
                            ? Icons.check_circle_rounded
                            : hasBlocking
                            ? Icons.error_rounded
                            : Icons.info_rounded,
                        size: 17,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isReady
                            ? strings.systemReady
                            : hasBlocking
                            ? strings.resolveBlockingIssues
                            : strings.checkAttention,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      '${checks.where((c) => c.passed).length}/${checks.length}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: RealtimeUiTokens.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: RealtimeUiTokens.textMuted,
                    ),
                  ],
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 10),
                const RealtimePreJoinCheckList(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Mic/camera capture switches independent of any toolbar or route.
class RealtimePreJoinMediaControls extends StatelessWidget {
  const RealtimePreJoinMediaControls({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preview = controller.preview;
        if (preview == null || controller.result?.role == MediaRole.viewer) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RealtimeCupertinoSwitchRow(
              title: Text(strings.microphone),
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.iosBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 16,
                  color: RealtimeUiTokens.iosBlue,
                ),
              ),
              value: preview.settings.microphoneEnabled,
              enabled: !controller.busy,
              onChanged: (enabled) =>
                  unawaited(controller.setMicrophoneEnabled(enabled)),
            ),
            Divider(
              height: 1,
              indent: 54,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            RealtimeCupertinoSwitchRow(
              title: Text(strings.camera),
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.iosTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  size: 16,
                  color: RealtimeUiTokens.iosTeal,
                ),
              ),
              value: preview.settings.cameraEnabled,
              enabled: !controller.busy,
              onChanged: (enabled) =>
                  unawaited(controller.setCameraEnabled(enabled)),
            ),
          ],
        );
      },
    );
  }
}

class RealtimePreJoinDevicePicker extends StatelessWidget {
  const RealtimePreJoinDevicePicker({super.key, required this.kind});
  final MediaDeviceKind kind;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preview = controller.preview;
        final devices = controller.devices
            .where((device) => device.kind == kind)
            .toList();
        if (preview == null || devices.isEmpty) return const SizedBox.shrink();
        final selected = switch (kind) {
          MediaDeviceKind.microphone => preview.settings.microphone,
          MediaDeviceKind.camera => preview.settings.camera,
          MediaDeviceKind.audioOutput => preview.settings.audioOutput,
        };
        final initial = devices
            .where((device) => device.id == selected?.id)
            .firstOrNull;

        final label = switch (kind) {
          MediaDeviceKind.microphone => strings.microphone,
          MediaDeviceKind.camera => strings.camera,
          MediaDeviceKind.audioOutput => strings.speaker,
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: DropdownButtonFormField<MediaDevice>(
            key: ValueKey((kind, initial?.id)),
            initialValue: initial,
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              for (final device in devices)
                DropdownMenuItem(value: device, child: Text(device.label)),
            ],
            onChanged: controller.busy
                ? null
                : (device) {
                    if (device != null) {
                      unawaited(controller.selectDevice(device));
                    }
                  },
          ),
        );
      },
    );
  }
}

class RealtimePreJoinBackgroundSelector extends StatelessWidget {
  const RealtimePreJoinBackgroundSelector({
    super.key,
    this.imagePresets = const [],
  });
  final List<MediaBackgroundImagePreset> imagePresets;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final result = controller.result;
        if (result == null ||
            result.role == MediaRole.viewer ||
            !result.backgroundCapabilities.isSupported) {
          return const SizedBox.shrink();
        }
        return BackgroundEffectSelector(
          capabilities: result.backgroundCapabilities,
          effect: controller.backgroundEffect,
          imagePresets: imagePresets,
          busy: controller.busy || controller.updatingBackground,
          onChanged: (effect) =>
              unawaited(controller.setBackgroundEffect(effect)),
        );
      },
    );
  }
}

/// Optional inline permission requests; the application can supply custom UI.
class RealtimePreJoinPermissions extends StatelessWidget {
  const RealtimePreJoinPermissions({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.result?.role == MediaRole.viewer) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in MediaPermissionKind.values)
              if (kind == MediaPermissionKind.microphone ||
                  kind == MediaPermissionKind.camera)
                if (controller.permissions[kind] !=
                        MediaPermissionState.unknown ||
                    (Theme.of(context).platform != TargetPlatform.macOS &&
                        Theme.of(context).platform != TargetPlatform.windows &&
                        Theme.of(context).platform != TargetPlatform.linux))
                  ActionChip(
                    avatar: Icon(
                      controller.permissions[kind] ==
                              MediaPermissionState.granted
                          ? Icons.check
                          : Icons.lock_outline,
                      size: 18,
                    ),
                    label: Text(
                      '${kind == MediaPermissionKind.microphone ? strings.microphone : strings.camera}: '
                      '${strings.permissionStateLabel(controller.permissions[kind] ?? MediaPermissionState.unknown)}',
                    ),
                    onPressed: controller.busy
                        ? null
                        : () {
                            if (controller.permissions[kind] ==
                                MediaPermissionState.permanentlyDenied) {
                              unawaited(controller.openAppSettings());
                            } else {
                              unawaited(controller.requestPermission(kind));
                            }
                          },
                  ),
          ],
        );
      },
    );
  }
}

/// Join button knows the controller state; navigation stays with the host.
class RealtimePreJoinJoinButton extends StatelessWidget {
  const RealtimePreJoinJoinButton({
    super.key,
    required this.onEnter,
    this.label,
  });
  final Future<void> Function(MediaLocalPreviewSettings settings) onEnter;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => FilledButton.icon(
        onPressed: controller.canEnter
            ? () => unawaited(controller.enter(onEnter))
            : null,
        icon: controller.joining
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login_rounded),
        label: Text(
          label ??
              (controller.joining
                  ? RealtimeStrings.of(context).enteringRoom
                  : RealtimeStrings.of(context).join),
        ),
      ),
    );
  }
}
