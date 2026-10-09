import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

typedef PreJoinPermissionAction =
    Future<void> Function(MediaPermissionKind kind);

class MediaPreJoinLoadingView extends StatelessWidget {
  const MediaPreJoinLoadingView({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: RealtimeUiTokens.primarySubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            border: Border.all(color: RealtimeUiTokens.primaryBorder),
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: RealtimeUiTokens.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RealtimeUiTokens.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class MediaPreJoinResultView extends StatelessWidget {
  const MediaPreJoinResultView({
    super.key,
    required this.result,
    this.permissionStates = const {},
    this.requestingPermission,
    this.canOpenAppSettings = false,
    this.onPermissionAction,
  });

  final MediaPreJoinResult result;
  final Map<MediaPermissionKind, MediaPermissionState> permissionStates;
  final MediaPermissionKind? requestingPermission;
  final bool canOpenAppSettings;
  final PreJoinPermissionAction? onPermissionAction;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: result.isReady
                ? RealtimeUiTokens.successSubtle.withValues(alpha: 0.90)
                : RealtimeUiTokens.dangerSubtle.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            border: Border.all(
              color: result.isReady
                  ? RealtimeUiTokens.successBorder
                  : RealtimeUiTokens.dangerBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  result.isReady
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 20,
                  color: result.isReady
                      ? RealtimeUiTokens.success
                      : RealtimeUiTokens.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.isReady
                      ? strings.readyToContinue
                      : strings.resolveBlockingIssues,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: RealtimeUiTokens.text,
                  ),
                ),
              ),
              if (result.providerId case final provider?)
                RealtimePill(
                  label: mediaProviderDisplayName(provider),
                  foreground: RealtimeUiTokens.primary,
                  background: Colors.white,
                  borderColor: RealtimeUiTokens.primaryBorder,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < result.checks.length; i++)
                  _CheckRow(
                    check: result.checks[i],
                    index: i,
                    permissionStates: permissionStates,
                    requestingPermission: requestingPermission,
                    canOpenAppSettings: canOpenAppSettings,
                    onPermissionAction: onPermissionAction,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.check,
    required this.index,
    required this.permissionStates,
    required this.requestingPermission,
    required this.canOpenAppSettings,
    required this.onPermissionAction,
  });

  final MediaPreJoinCheck check;
  final int index;
  final Map<MediaPermissionKind, MediaPermissionState> permissionStates;
  final MediaPermissionKind? requestingPermission;
  final bool canOpenAppSettings;
  final PreJoinPermissionAction? onPermissionAction;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(check.status);
    final strings = RealtimeStrings.of(context);
    final permissionKind = _permissionKindFor(check.type);
    final permissionState = permissionKind == null
        ? null
        : permissionStates[permissionKind];
    final canAct =
        onPermissionAction != null &&
        permissionKind != null &&
        permissionState != null &&
        permissionState != MediaPermissionState.granted &&
        permissionState != MediaPermissionState.unsupported &&
        permissionState != MediaPermissionState.restricted;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 180 + (index * 35).clamp(0, 160)),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 8),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .76),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          border: Border.all(color: RealtimeUiTokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: Icon(visual.icon, size: 18, color: visual.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelFor(strings, check.type),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: RealtimeUiTokens.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    check.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RealtimeUiTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RealtimePill(
                  label: strings.preJoinStatus(check.status.name),
                  foreground: visual.color,
                  background: visual.background,
                  borderColor: visual.color.withValues(alpha: 0.24),
                ),
                if (canAct) ...[
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: requestingPermission == permissionKind
                        ? null
                        : () => onPermissionAction!(permissionKind),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: requestingPermission == permissionKind
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            permissionState ==
                                    MediaPermissionState.permanentlyDenied
                                ? canOpenAppSettings
                                      ? strings.openAppSettings
                                      : strings.browserPermissionSettings
                                : strings.requestPermission,
                            textAlign: TextAlign.right,
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CheckVisual _visualFor(MediaPreJoinStatus status) => switch (status) {
    MediaPreJoinStatus.passed => const _CheckVisual(
      Icons.check_circle_outline_rounded,
      RealtimeUiTokens.success,
      RealtimeUiTokens.successSubtle,
    ),
    MediaPreJoinStatus.failed => const _CheckVisual(
      Icons.cancel_outlined,
      RealtimeUiTokens.danger,
      RealtimeUiTokens.dangerSubtle,
    ),
    MediaPreJoinStatus.unsupported => const _CheckVisual(
      Icons.remove_circle_outline_rounded,
      RealtimeUiTokens.textMuted,
      RealtimeUiTokens.surfaceSubtle,
    ),
    MediaPreJoinStatus.unknown => const _CheckVisual(
      Icons.help_outline_rounded,
      RealtimeUiTokens.warning,
      RealtimeUiTokens.warningSubtle,
    ),
  };

  String _labelFor(RealtimeStrings strings, MediaPreJoinCheckType type) =>
      switch (type) {
        MediaPreJoinCheckType.backend => strings.backend,
        MediaPreJoinCheckType.provider => strings.provider,
        MediaPreJoinCheckType.microphonePermission =>
          strings.microphonePermission,
        MediaPreJoinCheckType.cameraPermission => strings.cameraPermission,
        MediaPreJoinCheckType.microphoneDevice => strings.microphoneDevice,
        MediaPreJoinCheckType.cameraDevice => strings.cameraDevice,
        MediaPreJoinCheckType.network => strings.network,
        MediaPreJoinCheckType.providerNetwork => strings.providerNetwork,
      };
}

class _CheckVisual {
  const _CheckVisual(this.icon, this.color, this.background);

  final IconData icon;
  final Color color;
  final Color background;
}

MediaPermissionKind? _permissionKindFor(MediaPreJoinCheckType type) =>
    switch (type) {
      MediaPreJoinCheckType.microphonePermission =>
        MediaPermissionKind.microphone,
      MediaPreJoinCheckType.cameraPermission => MediaPermissionKind.camera,
      _ => null,
    };
