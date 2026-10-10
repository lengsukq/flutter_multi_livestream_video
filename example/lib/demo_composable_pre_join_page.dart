import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'demo_strings.dart';

/// The Demo owns the entire Pre-Join layout and navigation.
/// All checks, preview lifecycle and device operations live in the SDK.
class DemoComposablePreJoinPage extends StatefulWidget {
  const DemoComposablePreJoinPage({
    super.key,
    required this.runCheck,
    required this.openPreview,
    required this.onEnter,
    required this.roomLabel,
    required this.displayName,
    this.title,
    this.imagePresets = const [],
    this.permissionRequester = const DefaultMediaPermissionProbe(),
  });

  final RealtimePreJoinCheck runCheck;
  final RealtimePreJoinOpenPreview openPreview;
  final MediaPreJoinEnter onEnter;
  final MediaPermissionRequester permissionRequester;
  final String displayName;
  final String roomLabel;
  final String? title;
  final List<MediaBackgroundImagePreset> imagePresets;

  @override
  State<DemoComposablePreJoinPage> createState() =>
      _DemoComposablePreJoinPageState();
}

class _DemoComposablePreJoinPageState extends State<DemoComposablePreJoinPage>
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
    final strings = DemoStrings.of(context);
    final theme = Theme.of(context);
    return RealtimeGlassSurface(
      radius: 24,
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
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: const Color(0xFF151E2D),
                child: controller.result?.role == MediaRole.viewer
                    ? _PreviewExplanation(
                        icon: Icons.visibility_outlined,
                        label: strings.viewerPreviewHelp,
                      )
                    : RealtimePreJoinPreview(
                        placeholder: _PreviewExplanation(
                          icon: Icons.videocam_off_outlined,
                          label: strings.previewDisabledHelp,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: controller.result?.isReady == true
                  ? const Color(0xFFECFDF5)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  controller.result?.isReady == true
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: controller.result?.isReady == true
                      ? const Color(0xFF059669)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.loading
                        ? strings.checking
                        : controller.result?.isReady == true
                        ? strings.readyToJoin
                        : strings.checkAttention,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              dense: true,
              title: Text(
                strings.diagnosticDetails,
                style: theme.textTheme.bodyMedium,
              ),
              children: const [RealtimePreJoinCheckList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settings(BuildContext context) {
    final strings = DemoStrings.of(context);
    final theme = Theme.of(context);
    return RealtimeGlassSurface(
      radius: 24,
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
                  strings.deviceSettings,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.deviceSettingsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          const RealtimePreJoinPermissions(),
          const RealtimePreJoinMediaControls(),
          const SizedBox(height: 8),
          const RealtimePreJoinDevicePicker(kind: MediaDeviceKind.microphone),
          const SizedBox(height: 8),
          const RealtimePreJoinDevicePicker(kind: MediaDeviceKind.camera),
          const SizedBox(height: 8),
          const RealtimePreJoinDevicePicker(kind: MediaDeviceKind.audioOutput),
          const SizedBox(height: 12),
          RealtimePreJoinBackgroundSelector(imagePresets: widget.imagePresets),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final strings = DemoStrings.of(context);
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
                                  onPressed: controller.joining
                                      ? null
                                      : () => Navigator.pop(context),
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
                                  constraints.maxWidth >= 820 &&
                                  constraints.maxHeight >= 420;
                              final padding = EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth < 420
                                    ? 10
                                    : 18,
                                vertical: 8,
                              );
                              return Center(
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
                                                flex: 6,
                                                child: SingleChildScrollView(
                                                  child: _preview(context),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                flex: 5,
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
                                  label: Text(zh ? '重新检测' : 'Check again'),
                                ),
                                RealtimePreJoinJoinButton(
                                  onEnter: _enter,
                                  label: controller.joining
                                      ? (zh ? '加入中…' : 'Joining…')
                                      : controller.result?.role ==
                                            MediaRole.viewer
                                      ? (zh ? '观看直播' : 'Enter live room')
                                      : (zh ? '加入会议' : 'Join meeting'),
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
                                  Text(zh ? '正在进入房间…' : 'Entering room…'),
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

/// Demo-only explanation, independent of SDK camera capture or lifecycle.
class _PreviewExplanation extends StatelessWidget {
  const _PreviewExplanation({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
