import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Ready-to-use Pre-Join page shared by applications and the Demo.
/// All checks, preview lifecycle and device operations live in the SDK.
class RealtimePreJoinPage extends StatefulWidget {
  const RealtimePreJoinPage({
    super.key,
    required this.runCheck,
    required this.openPreview,
    required this.onEnter,
    required this.roomLabel,
    required this.displayName,
    this.onBack,
    this.avatarUrl,
    this.title,
    this.imagePresets = const [],
    this.permissionRequester = const DefaultMediaPermissionProbe(),
  });

  final RealtimePreJoinCheck runCheck;
  final RealtimePreJoinOpenPreview openPreview;
  final RealtimePreJoinEnter onEnter;
  final MediaPermissionRequester permissionRequester;
  final VoidCallback? onBack;
  final String displayName;
  final String? avatarUrl;
  final String roomLabel;
  final String? title;
  final List<MediaBackgroundImagePreset> imagePresets;

  @override
  State<RealtimePreJoinPage> createState() => _RealtimePreJoinPageState();
}

class _RealtimePreJoinPageState extends State<RealtimePreJoinPage>
    with WidgetsBindingObserver {
  late final RealtimePreJoinController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = RealtimePreJoinController(
      runCheck: widget.runCheck,
      openPreview: widget.openPreview,
      permissionRequester: widget.permissionRequester,
    );
    unawaited(controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.refreshPermissions());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> _enter(MediaLocalPreviewSettings settings) =>
      widget.onEnter(context, settings);

  Widget _preview(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final theme = Theme.of(context);
    return RealtimeCardSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videocam_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  strings.cameraPreview,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
              child: ColoredBox(
                color: const Color(0xFF151E2D),
                child: controller.result?.role == MediaRole.viewer
                    ? _PreviewExplanation(
                        avatarName: widget.displayName,
                        avatarUrl: widget.avatarUrl,
                        icon: Icons.visibility_outlined,
                        label: RealtimeStrings.of(context).viewerPreviewHelp,
                      )
                    : RealtimePreJoinPreview(
                        placeholder: _PreviewExplanation(
                          avatarName: widget.displayName,
                          avatarUrl: widget.avatarUrl,
                          icon: Icons.videocam_off_outlined,
                          label: RealtimeStrings.of(
                            context,
                          ).previewDisabledHelp,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const RealtimePreJoinReadinessCard(),
        ],
      ),
    );
  }

  Widget _settings(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final theme = Theme.of(context);
    return RealtimeCardSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  strings.audioAndVideo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.deviceSettingsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          RealtimeInsetGroup(children: const [RealtimePreJoinMediaControls()]),
          const SizedBox(height: 12),
          RealtimeInsetGroup(
            children: const [
              RealtimePreJoinDevicePicker(kind: MediaDeviceKind.microphone),
              RealtimePreJoinDevicePicker(kind: MediaDeviceKind.camera),
              RealtimePreJoinDevicePicker(kind: MediaDeviceKind.audioOutput),
            ],
          ),
          const SizedBox(height: 14),
          RealtimePreJoinBackgroundSelector(imagePresets: widget.imagePresets),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return RealtimePreJoinScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PopScope(
          canPop: !controller.joining,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: RealtimeAmbientBackground(
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: RealtimeGlassSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: strings.back,
                                  icon: const Icon(Icons.arrow_back),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  onPressed: controller.joining
                                      ? null
                                      : widget.onBack ??
                                            () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strings.preJoinTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(
                                        '${widget.title ?? strings.meeting} · ${widget.roomLabel} · ${widget.displayName}',
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide =
                                  constraints.maxWidth >= 1000 &&
                                  MediaQuery.textScalerOf(context).scale(17) <
                                      28 &&
                                  constraints.maxHeight >= 420;
                              final padding = EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth < 420
                                    ? 10
                                    : 18,
                                vertical: 8,
                              );
                              return Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1220,
                                  ),
                                  child: Padding(
                                    padding: padding,
                                    child: wide
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: SingleChildScrollView(
                                                  child: _preview(context),
                                                ),
                                              ),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                flex: 6,
                                                child: SingleChildScrollView(
                                                  child: _settings(context),
                                                ),
                                              ),
                                            ],
                                          )
                                        : ListView(
                                            children: [
                                              _preview(context),
                                              const SizedBox(height: 12),
                                              _settings(context),
                                            ],
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (controller.joinError != null ||
                            controller.previewError != null ||
                            controller.error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Text(
                              strings.displayRealtimeError(
                                controller.joinError ??
                                    controller.error ??
                                    controller.previewError!,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: RealtimeGlassSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: controller.busy
                                      ? null
                                      : () =>
                                            unawaited(controller.initialize()),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(
                                    RealtimeStrings.of(context).runAgain,
                                  ),
                                ),
                                RealtimePreJoinJoinButton(
                                  onEnter: _enter,
                                  label: controller.joining
                                      ? RealtimeStrings.of(context).enteringRoom
                                      : controller.result?.role ==
                                            MediaRole.viewer
                                      ? RealtimeStrings.of(
                                          context,
                                        ).enterLiveRoom
                                      : RealtimeStrings.of(context).joinMeeting,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (controller.joining)
                      Positioned.fill(
                        child: AbsorbPointer(
                          child: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.83),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  Text(
                                    RealtimeStrings.of(context).enteringRoom,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Camera-off explanation, independent of capture or preview lifecycle.
class _PreviewExplanation extends StatelessWidget {
  const _PreviewExplanation({
    required this.icon,
    required this.label,
    this.avatarName,
    this.avatarUrl,
  });
  final String? avatarName;
  final String? avatarUrl;

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxHeight < 200 ||
          MediaQuery.textScalerOf(context).scale(17) >= 28;
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (avatarName != null)
                  RealtimeAvatar(
                    name: avatarName!,
                    avatarUrl: avatarUrl,
                    size: compact ? 40 : 80,
                  )
                else
                  Icon(icon, size: compact ? 22 : 38, color: Colors.white70),
                SizedBox(height: compact ? 4 : 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
