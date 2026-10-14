import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_background.dart';
import 'widgets/demo_recording_widgets.dart';

/// A broadcast UI assembled entirely by the consuming app.
/// Designed with an immersive livestream layout (similar to Douyin/TikTok/Twitch Live).
class DemoComposableLivePage extends StatefulWidget {
  const DemoComposableLivePage({
    super.key,
    required this.room,
    required this.initialSettings,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  State<DemoComposableLivePage> createState() => _DemoComposableLivePageState();
}

enum _LiveSidePanel { none, chat, members }

class _DemoComposableLivePageState extends State<DemoComposableLivePage> {
  late Future<void> _preparing;
  late final Future<List<MediaBackgroundImagePreset>> _presets;
  _LiveSidePanel _sidePanel = _LiveSidePanel.none;
  bool _cleanScreen = false;
  BoxFit? _liveVideoFitOverride;

  @override
  void initState() {
    super.initState();
    _preparing = _prepare();
    _presets = DemoBackground.presets;
  }

  @override
  void didUpdateWidget(covariant DemoComposableLivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.initialSettings != widget.initialSettings) {
      _preparing = _prepare();
      _sidePanel = _LiveSidePanel.none;
    }
  }

  Future<void> _prepare() async {
    await widget.room.prepareVideoEffects(widget.initialSettings);
  }

  void _toggle(_LiveSidePanel panel, {required bool isWide}) {
    if (!isWide) {
      _openMobileSheet(panel);
      return;
    }
    setState(() {
      _sidePanel = _sidePanel == panel ? _LiveSidePanel.none : panel;
    });
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final strings = RealtimeStrings.of(context);
    final host =
        widget.room.media.role == MediaRole.host &&
        widget.room.media.managementCapabilities.closeRoom.supported;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(host ? strings.endLive : strings.leaveRoomTitle),
            content: Text(
              host
                  ? strings.endLiveConfirmation
                  : strings.leaveRoomConfirmation,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(host ? strings.endLive : strings.leave),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openMobileSheet(_LiveSidePanel panel) {
    final strings = RealtimeStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => RealtimeRoomUiScope(
          room: widget.room,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.68,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1D1D1F).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFE5E5EA),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              (panel == _LiveSidePanel.chat
                                      ? const Color(0xFF1D1D1F)
                                      : const Color(0xFFE11D48))
                                  .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          panel == _LiveSidePanel.chat
                              ? Icons.chat_bubble_rounded
                              : Icons.people_alt_rounded,
                          size: 16,
                          color: panel == _LiveSidePanel.chat
                              ? const Color(0xFF1D1D1F)
                              : const Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        panel == _LiveSidePanel.chat
                            ? strings.chat
                            : strings.participants,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1D1D1F),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFE5E5EA),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: panel == _LiveSidePanel.chat
                        ? const RealtimeChatPanel()
                        : const RealtimeManagedParticipantList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openHostToolsSheet(BuildContext context) {
    unawaited(
      showRealtimeHostToolsBottomSheet(
        context,
        room: widget.room,
        imagePresetsFuture: _presets,
        extraTools: [DemoRecordingButton(room: widget.room)],
      ),
    );
  }

  Widget _fitControl() {
    final strings = RealtimeStrings.of(context);
    final full = _liveVideoFitOverride == BoxFit.contain;
    return RealtimeGlassIconButton(
      icon: full ? Icons.crop_free_rounded : Icons.fit_screen_rounded,
      tooltip: full ? strings.fillLiveScreen : strings.showFullVideo,
      onPressed: () => setState(
        () => _liveVideoFitOverride = full ? BoxFit.cover : BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _preparing,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: () => setState(() => _preparing = _prepare()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return RealtimeRoomUiScope(
        room: widget.room,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: RealtimeAmbientBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 1000 &&
                    MediaQuery.textScalerOf(context).scale(17) < 28;
                final isHost = widget.room.media.role != MediaRole.viewer;
                final strings = RealtimeStrings.of(context);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final controller = RealtimeRoomUiScope.of(context);

                if (_cleanScreen) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _cleanScreen = false),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RealtimeLiveVideoStage(fit: _liveVideoFitOverride),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: SafeArea(
                            child: RealtimePill(
                              label: strings.exitCleanScreen,
                              icon: Icons.fullscreen_exit_rounded,
                              foreground: isDark
                                  ? Colors.white
                                  : RealtimeUiTokens.text,
                              background: isDark
                                  ? Colors.black.withValues(alpha: 0.65)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderColor: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : RealtimeUiTokens.border,
                              onTap: () => setState(() => _cleanScreen = false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (wide) {
                  return Row(
                    children: [
                      Expanded(
                        child: RealtimeLiveDesktopStage(
                          videoFit: _liveVideoFitOverride,
                          exitAction: RealtimeLeaveButton(
                            iconOnly: true,
                            onConfirm: (ctx) => _confirmLeave(ctx),
                            onLeft: () {
                              if (context.mounted &&
                                  Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          onToggleCleanScreen: () =>
                              setState(() => _cleanScreen = true),
                          onViewAudience: () =>
                              _toggle(_LiveSidePanel.members, isWide: true),
                          customChatPanel: _sidePanel == _LiveSidePanel.members
                              ? const RealtimeManagedParticipantList()
                              : null,
                          topTrailingActions: [
                            _fitControl(),
                            if (isHost) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                tooltip: strings.isZh ? '主播工具' : 'Host Tools',
                                onPressed: () => _openHostToolsSheet(context),
                              ),
                              const SizedBox(width: 4),
                            ],
                            DemoRecordingBadge(
                              room: widget.room,
                              compact: true,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(
                        controller.sendLiveLike().catchError(
                          controller.reportActionError,
                        ),
                      ),
                      onDoubleTap: () {
                        unawaited(
                          controller.sendLiveLike().catchError(
                            controller.reportActionError,
                          ),
                        );
                        unawaited(
                          controller.sendLiveLike().catchError(
                            controller.reportActionError,
                          ),
                        );
                      },
                      child: RealtimeLiveVideoStage(fit: _liveVideoFitOverride),
                    ),
                    RealtimeLiveMobileOverlay(
                      exitAction: RealtimeLeaveButton(
                        iconOnly: true,
                        onConfirm: (ctx) => _confirmLeave(ctx),
                        onLeft: () {
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      onViewAudience: () =>
                          _openMobileSheet(_LiveSidePanel.members),
                      onOpenHostTools: isHost
                          ? () => _openHostToolsSheet(context)
                          : null,
                      videoFit: _liveVideoFitOverride,
                      onToggleVideoFit: () => setState(
                        () => _liveVideoFitOverride =
                            _liveVideoFitOverride == BoxFit.contain
                            ? BoxFit.cover
                            : BoxFit.contain,
                      ),
                      onToggleCleanScreen: () =>
                          setState(() => _cleanScreen = true),
                      extraBottomActions: [
                        DemoRecordingBadge(room: widget.room, compact: true),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
