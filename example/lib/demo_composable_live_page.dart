import 'dart:async';
import 'dart:math' as math;

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
  bool _chatInputActive = false;

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
      _chatInputActive = false;
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
                ? const Color(0xFF0F172A).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE2E8F0),
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
                                    ? const Color(0xFF0284C7)
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
                            ? const Color(0xFF0284C7)
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
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: panel == _LiveSidePanel.chat
                    ? const RealtimeChatPanel()
                    : const RealtimeManagedParticipantList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHostToolsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZh = RealtimeStrings.of(context).isZh;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RealtimeRoomUiScope(
        room: widget.room,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isZh ? '主播工具' : 'Host Tools',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FutureBuilder<List<MediaBackgroundImagePreset>>(
                      future: _presets,
                      builder: (context, snapshot) =>
                          RealtimeBackgroundEffectsButton(
                            imagePresets: snapshot.data ?? const [],
                          ),
                    ),
                    const RealtimeScreenShareButton(),
                    const RealtimeAudioOutputButton(),
                    DemoRecordingButton(room: widget.room),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    final strings = RealtimeStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        (_sidePanel == _LiveSidePanel.chat
                                ? const Color(0xFF0284C7)
                                : const Color(0xFFE11D48))
                            .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _sidePanel == _LiveSidePanel.chat
                        ? Icons.chat_bubble_rounded
                        : Icons.people_alt_rounded,
                    size: 16,
                    color: _sidePanel == _LiveSidePanel.chat
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE11D48),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sidePanel == _LiveSidePanel.chat
                        ? strings.chat
                        : strings.participants,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.closePanel,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _sidePanel = _LiveSidePanel.none),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: _sidePanel == _LiveSidePanel.chat
                ? const RealtimeChatPanel()
                : const RealtimeManagedParticipantList(),
          ),
        ],
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
                final wide = constraints.maxWidth >= 760;
                final isHost = widget.room.media.role != MediaRole.viewer;
                final strings = RealtimeStrings.of(context);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final controller = RealtimeRoomUiScope.of(context);
                final videoStageWidth =
                    wide && _sidePanel != _LiveSidePanel.none
                    ? constraints.maxWidth - 330
                    : constraints.maxWidth;
                final isCompactDock = videoStageWidth < 660;

                if (_cleanScreen) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _cleanScreen = false),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const RealtimeLiveVideoStage(),
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

                return Row(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Live Video Canvas with Tap-to-Like
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => unawaited(
                              controller.sendLiveLike().catchError((_) {}),
                            ),
                            onDoubleTap: () {
                              unawaited(
                                controller.sendLiveLike().catchError((_) {}),
                              );
                              unawaited(
                                controller.sendLiveLike().catchError((_) {}),
                              );
                            },
                            child: const RealtimeLiveVideoStage(),
                          ),

                          // 2. Top Scrim Gradient
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 140,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            Colors.black.withValues(
                                              alpha: 0.70,
                                            ),
                                            Colors.transparent,
                                          ]
                                        : [
                                            Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                            Colors.transparent,
                                          ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. Bottom Scrim Gradient
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 260,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            Colors.transparent,
                                            Colors.black.withValues(
                                              alpha: 0.85,
                                            ),
                                          ]
                                        : [
                                            Colors.transparent,
                                            Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                          ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 4. Floating Hearts Particle Layer
                          Positioned(
                            right: 16,
                            bottom:
                                (isCompactDock ? 104.0 : 64.0) +
                                MediaQuery.viewInsetsOf(context).bottom,
                            child: const IgnorePointer(
                              child: RealtimeLiveHeartsOverlay(),
                            ),
                          ),

                          // 5. Floating Gift Banner
                          const Positioned(
                            right: 16,
                            top: 80,
                            child: RealtimeLiveGiftBanner(),
                          ),

                          // 6. Floating Danmaku Chat Feed
                          Positioned(
                            left: 14,
                            bottom:
                                (isCompactDock ? 104.0 : 64.0) +
                                MediaQuery.viewInsetsOf(context).bottom,
                            width: math.min(320.0, videoStageWidth * 0.72),
                            child: const IgnorePointer(
                              child: RealtimeLiveChatFeed(),
                            ),
                          ),

                          // 7. Top HUD (Anchor capsule + Audience pill + Leave button)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // Anchor capsule
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: wide ? 220 : 130,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        4,
                                        12,
                                        4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(
                                                alpha: 0.65,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.92,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          RealtimeUiTokens.pillRadius,
                                        ),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.20,
                                                )
                                              : RealtimeUiTokens.border,
                                          width: 1,
                                        ),
                                        boxShadow: isDark
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                width: 34,
                                                height: 34,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFFF43F5E),
                                                      Color(0xFFFB923C),
                                                    ],
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.person_rounded,
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: -2,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFE11D48,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    strings.liveStatus,
                                                    style: const TextStyle(
                                                      fontSize: 7.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  strings.liveStream,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark
                                                        ? Colors.white
                                                        : RealtimeUiTokens.text,
                                                  ),
                                                ),
                                                Text(
                                                  widget.room.roomCode,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : RealtimeUiTokens
                                                              .textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Viewers online count pill
                                    RealtimePill(
                                      label: strings.viewingCount(
                                        controller.snapshot.participants.length,
                                      ),
                                      icon: Icons.visibility_rounded,
                                      foreground: isDark
                                          ? Colors.white
                                          : RealtimeUiTokens.text,
                                      background: isDark
                                          ? Colors.black.withValues(alpha: 0.55)
                                          : Colors.white.withValues(
                                              alpha: 0.92,
                                            ),
                                      borderColor: isDark
                                          ? Colors.white.withValues(alpha: 0.20)
                                          : RealtimeUiTokens.border,
                                    ),

                                    const Spacer(),

                                    DemoRecordingBadge(room: widget.room),

                                    // Clean Screen button (wide screens)
                                    if (wide) ...[
                                      RealtimeGlassIconButton(
                                        tooltip: strings.cleanScreen,
                                        icon: Icons.fullscreen_rounded,
                                        size: 36,
                                        radius: RealtimeUiTokens.pillRadius,
                                        onPressed: () =>
                                            setState(() => _cleanScreen = true),
                                      ),
                                      const SizedBox(width: 8),
                                    ],

                                    // Leave button
                                    RealtimeLeaveButton(
                                      iconOnly: true,
                                      onConfirm: (ctx) => _confirmLeave(ctx),
                                      onLeft: () {
                                        if (context.mounted &&
                                            Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 8. Bottom Interaction Dock (Pure icon buttons + in-place comment)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.viewInsetsOf(context).bottom +
                                      8,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, dockConstraints) {
                                    final compact =
                                        dockConstraints.maxWidth < 640;
                                    final actionButtons = SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      reverse: true,
                                      physics: const BouncingScrollPhysics(),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isHost) ...[
                                            const RealtimeMicrophoneButton(
                                              iconOnly: true,
                                            ),
                                            const SizedBox(width: 6),
                                            const RealtimeCameraButton(
                                              iconOnly: true,
                                            ),
                                            const SizedBox(width: 6),
                                            const RealtimeSwitchCameraButton(
                                              iconOnly: true,
                                            ),
                                            const SizedBox(width: 6),
                                            RealtimeGlassIconButton(
                                              tooltip: strings.isZh
                                                  ? '主播工具'
                                                  : 'Host Tools',
                                              icon: Icons.tune_rounded,
                                              size: 40,
                                              radius:
                                                  RealtimeUiTokens.pillRadius,
                                              onPressed: () =>
                                                  _openHostToolsSheet(context),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          const RealtimeLiveGiftButton(
                                            showLabel: false,
                                          ),
                                          const SizedBox(width: 6),
                                          const RealtimeLiveLikeButton(
                                            iconOnly: true,
                                          ),
                                          const SizedBox(width: 6),
                                          RealtimeGlassIconButton(
                                            tooltip: strings.participants,
                                            icon: Icons.people_outline_rounded,
                                            size: 40,
                                            radius: RealtimeUiTokens.pillRadius,
                                            onPressed: () => _toggle(
                                              _LiveSidePanel.members,
                                              isWide: wide,
                                            ),
                                          ),
                                          if (widget.room.chat != null) ...[
                                            const SizedBox(width: 6),
                                            RealtimeGlassIconButton(
                                              tooltip: strings.chat,
                                              icon: Icons
                                                  .chat_bubble_outline_rounded,
                                              size: 40,
                                              radius:
                                                  RealtimeUiTokens.pillRadius,
                                              onPressed: () => _toggle(
                                                _LiveSidePanel.chat,
                                                isWide: wide,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );

                                    if (compact) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (widget.room.chat != null) ...[
                                            _LiveInPlaceChatInput(
                                              room: widget.room,
                                              isActive: _chatInputActive,
                                              onActivate: () => setState(
                                                () => _chatInputActive = true,
                                              ),
                                              onDeactivate: () => setState(
                                                () => _chatInputActive = false,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: actionButtons,
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        if (widget.room.chat != null)
                                          Expanded(
                                            child: _LiveInPlaceChatInput(
                                              room: widget.room,
                                              isActive: _chatInputActive,
                                              onActivate: () => setState(
                                                () => _chatInputActive = true,
                                              ),
                                              onDeactivate: () => setState(
                                                () => _chatInputActive = false,
                                              ),
                                            ),
                                          ),
                                        if (widget.room.chat != null)
                                          const SizedBox(width: 8),
                                        actionButtons,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Wide screen side panel
                    if (wide && _sidePanel != _LiveSidePanel.none)
                      SizedBox(width: 330, child: _panel()),
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

/// In-place live chat comment capsule directly embedded in the bottom dock.
class _LiveInPlaceChatInput extends StatefulWidget {
  const _LiveInPlaceChatInput({
    required this.room,
    required this.isActive,
    required this.onActivate,
    required this.onDeactivate,
  });

  final RealtimeRoom room;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  @override
  State<_LiveInPlaceChatInput> createState() => _LiveInPlaceChatInputState();
}

class _LiveInPlaceChatInputState extends State<_LiveInPlaceChatInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;

  @override
  void didUpdateWidget(covariant _LiveInPlaceChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.isActive && oldWidget.isActive) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.room.chat?.sendMessage(text);
      if (mounted) {
        _textController.clear();
        widget.onDeactivate();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;

    if (!widget.isActive) {
      return InkWell(
        onTap: widget.onActivate,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.52)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : RealtimeUiTokens.border,
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: isDark ? Colors.white70 : RealtimeUiTokens.textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  strings.sendComment,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : RealtimeUiTokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.76)
            : style.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(
          color: isDark
              ? style.primary.withValues(alpha: 0.8)
              : style.primaryBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: style.primary.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_rounded, size: 16, color: style.primary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: TextStyle(
                color: isDark ? Colors.white : style.text,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                hintText: strings.sendComment,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white60 : style.textMuted,
                  fontSize: 13,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            color: style.primary,
            onPressed: _sending ? null : _send,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: style.textMuted,
            onPressed: widget.onDeactivate,
          ),
        ],
      ),
    );
  }
}
