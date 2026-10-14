import 'demo_custom_interaction.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_background.dart';
import 'demo_meeting_side_panel.dart';
import 'widgets/demo_cloud_recording_result_dialog.dart';
import 'widgets/demo_recording_layout_picker.dart';
import 'widgets/demo_recording_widgets.dart';

/// Demo-owned layout: the SDK supplies only stateful functional widgets.
///
/// This page intentionally does not use MediaRoomView or RealtimeRoomView.
/// Apps can replace any Row/Column/Stack here without touching the SDK.
class DemoComposableMeetingPage extends StatefulWidget {
  const DemoComposableMeetingPage({
    super.key,
    required this.room,
    required this.initialSettings,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  State<DemoComposableMeetingPage> createState() =>
      _DemoComposableMeetingPageState();
}

class _DemoComposableMeetingPageState extends State<DemoComposableMeetingPage> {
  late Future<void> _videoEffectsReady;
  DemoMeetingPanel _panel = DemoMeetingPanel.closed;
  int _classroomTab = 0;
  int _classroomPanelVisit = 0;
  bool _recordingBusy = false;
  bool _useGrid = false;

  @override
  void initState() {
    super.initState();
    _videoEffectsReady = _prepare();
  }

  Future<void> _prepare() async {
    await widget.room.prepareVideoEffects(widget.initialSettings);
    await widget.room.sharedContent?.start();
  }

  @override
  void didUpdateWidget(covariant DemoComposableMeetingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.initialSettings != widget.initialSettings) {
      _videoEffectsReady = _prepare();
      _panel = DemoMeetingPanel.closed;
      _classroomTab = 0;
      _classroomPanelVisit = 0;
      _useGrid = false;
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final strings = RealtimeStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.leaveRoomTitle),
            content: Text(strings.leaveRoomConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.leave),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _onLeft() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _openEffects(BuildContext context) async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final presets = await DemoBackground.loadPresets(isZh: zh);
    if (!context.mounted) return;
    final controller = RealtimeRoomUiScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BackgroundEffectSelector(
              capabilities: controller.room.backgroundCapabilities,
              effect: controller.room.backgroundEffect,
              imagePresets: presets,
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
  }

  /// Compact More-menu equivalent of [RealtimeDockRaiseHandButton].
  Future<void> _toggleRaiseHand(BuildContext context) async {
    final controller = RealtimeRoomUiScope.of(context);
    final state = controller.classroomState;
    if (state == null) return;
    final raised = state.students.any(
      (student) => student.userId == state.selfUserId && student.handRaised,
    );
    try {
      await controller.setHandRaised(!raised);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _sendWave(BuildContext context) async {
    try {
      await widget.room.interactions.publish(DemoWaveInteraction.topic, {
        'sentAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _openClassroomTools(BuildContext context) {
    final classroom = widget.room.classroom;
    if (classroom == null) return;
    unawaited(
      showRealtimeGlassBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: ClassroomToolsPanel(
            classroom: classroom,
            showHeader: true,
            onClose: () => Navigator.maybeOf(sheetContext)?.pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _videoEffectsReady,
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
                  onPressed: () => setState(() {
                    _videoEffectsReady = _prepare();
                  }),
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
          backgroundColor: RealtimeUiTokens.background,
          body: RealtimeAmbientBackground(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 1000 &&
                      MediaQuery.textScalerOf(context).scale(17) < 28;
                  // Compact (<600pt, e.g. phones): dock collapses to core
                  // actions + More so nothing overflows; timer moves up.
                  final compact = constraints.maxWidth < 600;
                  final dock = Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: RealtimeMeetingDock(
                      showLabels: wide,
                      leadingStatus: compact
                          ? null
                          : const DemoMeetingTimerBadge(),
                      mediaGroup: [
                        RealtimeDockMicrophoneButton(showLabel: wide),
                        RealtimeDockCameraButton(showLabel: wide),
                        if (compact)
                          RealtimeDockSharedContentButton(showLabel: wide)
                        else ...[
                          RealtimeDockRaiseHandButton(showLabel: wide),
                          RealtimeDockHandQueueButton(
                            showLabel: wide,
                            onPressed: () => _openClassroomHands(isWide: wide),
                          ),
                        ],
                      ],
                      collaborationGroup: compact
                          ? const []
                          : [
                              RealtimeDockSharedContentButton(showLabel: wide),
                              RealtimeDockReactionsButton(
                                showLabel: wide,
                                onWave:
                                    widget
                                        .room
                                        .interactions
                                        .capabilities
                                        .canPublish
                                    ? () => unawaited(_sendWave(context))
                                    : null,
                              ),
                            ],
                      panelsGroup: compact
                          ? const []
                          : [
                              if (widget.room.chat != null)
                                RealtimeDockItem(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: RealtimeStrings.of(context).chat,
                                  isActive:
                                      wide && _panel == DemoMeetingPanel.chat,
                                  onPressed: () => _toggle(
                                    DemoMeetingPanel.chat,
                                    isWide: wide,
                                  ),
                                  showLabel: wide,
                                ),
                              RealtimeDockItem(
                                icon: Icons.people_outline_rounded,
                                label: RealtimeStrings.of(context).participants,
                                isActive:
                                    wide &&
                                    _panel == DemoMeetingPanel.participants,
                                onPressed: () => _toggle(
                                  DemoMeetingPanel.participants,
                                  isWide: wide,
                                ),
                                showLabel: wide,
                              ),
                              if (widget.room.classroom != null)
                                RealtimeDockItem(
                                  icon: Icons.school_outlined,
                                  label: RealtimeStrings.of(context).classroom,
                                  isActive:
                                      wide &&
                                      _panel == DemoMeetingPanel.classroom,
                                  onPressed: () => _toggle(
                                    DemoMeetingPanel.classroom,
                                    isWide: wide,
                                  ),
                                  showLabel: wide,
                                ),
                            ],
                      moreAction: StreamBuilder<RecordingStatus>(
                        stream: widget.room.recordingStatuses,
                        initialData: widget.room.recordingStatus,
                        builder: (context, snapshot) {
                          final recStatus =
                              snapshot.data ?? RecordingStatus.idle;
                          final isRecording =
                              recStatus == RecordingStatus.recording;
                          final isZh =
                              Localizations.localeOf(context).languageCode ==
                              'zh';
                          final isCloud =
                              const {
                                'livekit',
                                'trtc',
                                'agora',
                                'artc',
                                'chime',
                                'ivs',
                              }.contains(widget.room.engineProviderId) &&
                              widget.room.featureBackendUrl != null;

                          final roomController = RealtimeRoomUiScope.of(
                            context,
                          );
                          final canRaise =
                              roomController.canRaiseHand &&
                              roomController.classroomState != null;
                          return ListenableBuilder(
                            listenable: roomController,
                            builder: (context, _) => RealtimeDockMoreButton(
                              showLabel: wide,
                              hasActiveBadge: isRecording,
                              items: [
                                // Compact overflow: actions hidden from the
                                // dock stay one tap away in More.
                                if (compact && canRaise)
                                  RealtimeDockMoreItem(
                                    icon: Icons.pan_tool_outlined,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).raiseHand,
                                    onTap: () =>
                                        unawaited(_toggleRaiseHand(context)),
                                  ),
                                if (compact)
                                  RealtimeDockMoreItem(
                                    icon: Icons.group_outlined,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).classroomHands,
                                    onTap: () =>
                                        _openClassroomHands(isWide: false),
                                  ),
                                if (compact &&
                                    widget
                                        .room
                                        .interactions
                                        .capabilities
                                        .canPublish)
                                  RealtimeDockMoreItem(
                                    icon: Icons.waving_hand_rounded,
                                    title: RealtimeStrings.of(context).wave,
                                    onTap: () => unawaited(_sendWave(context)),
                                  ),
                                if (compact && widget.room.chat != null)
                                  RealtimeDockMoreItem(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    title: RealtimeStrings.of(context).chat,
                                    onTap: () => _toggle(
                                      DemoMeetingPanel.chat,
                                      isWide: false,
                                    ),
                                  ),
                                if (compact)
                                  RealtimeDockMoreItem(
                                    icon: Icons.people_outline_rounded,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).participants,
                                    onTap: () => _toggle(
                                      DemoMeetingPanel.participants,
                                      isWide: false,
                                    ),
                                  ),
                                if (compact && widget.room.classroom != null)
                                  RealtimeDockMoreItem(
                                    icon: Icons.school_outlined,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).classroom,
                                    onTap: () => _toggle(
                                      DemoMeetingPanel.classroom,
                                      isWide: false,
                                    ),
                                  ),
                                RealtimeDockMoreItem(
                                  icon: Icons.cameraswitch_rounded,
                                  title: RealtimeStrings.of(context).flipCamera,
                                  subtitle: isZh ? '前后切换' : 'Flip',
                                  onTap: () {
                                    final controller = RealtimeRoomUiScope.of(
                                      context,
                                    );
                                    unawaited(controller.switchCamera());
                                  },
                                ),
                                RealtimeDockMoreItem(
                                  icon: Icons.blur_on_rounded,
                                  title: RealtimeStrings.of(
                                    context,
                                  ).backgroundEffects,
                                  subtitle: isZh ? '背景特效' : 'Effects',
                                  onTap: () => unawaited(_openEffects(context)),
                                ),
                                RealtimeDockMoreItem(
                                  icon: isRecording
                                      ? Icons.stop_circle_rounded
                                      : Icons.fiber_manual_record_rounded,
                                  title: isRecording
                                      ? (isZh ? '停止录制' : 'Stop Rec')
                                      : (isZh ? '会议录制' : 'Record'),
                                  subtitle: isRecording
                                      ? (isZh ? '录制中' : 'Recording')
                                      : (isCloud
                                            ? (isZh ? '云端录制' : 'Cloud')
                                            : (isZh ? '录制不可用' : 'Unavailable')),
                                  isDanger: isRecording,
                                  showBadgeDot: isRecording,
                                  onTap: () =>
                                      unawaited(_handleRecording(context)),
                                ),
                                if (isCloud)
                                  RealtimeDockMoreItem(
                                    icon: Icons.cloud_download_rounded,
                                    title: isZh ? '录制结果' : 'Recordings',
                                    subtitle: isZh ? '查看云录像' : 'Files',
                                    onTap: () =>
                                        _showCloudResultDialog(context),
                                  ),
                                if (widget
                                        .room
                                        .classroom
                                        ?.state
                                        ?.capabilities
                                        .canUseTools ==
                                    true)
                                  RealtimeDockMoreItem(
                                    icon: Icons.build_outlined,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).classroomTools,
                                    subtitle: isZh ? '互动工具' : 'Tools',
                                    onTap: () => _openClassroomTools(context),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      exitAction: RealtimeDockItem(
                        icon: Icons.call_end_rounded,
                        label: RealtimeStrings.of(context).leave,
                        isDanger: true,
                        onPressed: () async {
                          final confirmed = await _confirmLeave(context);
                          if (confirmed == true && context.mounted) {
                            final controller = RealtimeRoomUiScope.of(context);
                            await controller.leave();
                            if (context.mounted) {
                              _onLeft();
                            }
                          }
                        },
                        showLabel: wide,
                      ),
                    ),
                  );
                  final stage = Row(
                    children: [
                      Expanded(
                        child: _DemoMeetingStage(
                          bottomControlsInset: compact ? 0 : 90,
                          useGrid: _useGrid,
                          topOverlayInset: wide ? 96 : 0,
                        ),
                      ),
                      if (wide && _panel != DemoMeetingPanel.closed)
                        SizedBox(width: 330, child: _sidePanel()),
                    ],
                  );
                  final roomController = RealtimeRoomUiScope.of(context);
                  final header = ListenableBuilder(
                    listenable: roomController,
                    builder: (context, _) => RealtimeMeetingTopBar(
                      compact: !wide,
                      title: widget.room.media.roomCode,
                      subtitle: widget.room.media.participantId,
                      statusWidgets: [
                        DemoRecordingBadge(room: widget.room, compact: compact),
                        if (compact) const DemoMeetingTimerBadge(),
                      ],
                      trailingActions: [
                        if (wide) const RealtimeConnectionIndicator(),
                        if (roomController.snapshot.contentShareTrack == null &&
                            roomController.snapshot.participants.length > 1)
                          IconButton(
                            tooltip: _useGrid
                                ? (RealtimeStrings.of(context).isZh
                                      ? '聚焦布局'
                                      : 'Focus layout')
                                : (RealtimeStrings.of(context).isZh
                                      ? '网格布局'
                                      : 'Grid layout'),
                            icon: Icon(
                              _useGrid
                                  ? Icons.view_carousel_outlined
                                  : Icons.grid_view_rounded,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _useGrid = !_useGrid),
                          ),
                        IconButton(
                          icon: const Icon(Icons.blur_on_rounded, size: 20),
                          tooltip: RealtimeStrings.of(
                            context,
                          ).backgroundEffects,
                          onPressed: () => unawaited(_openEffects(context)),
                        ),
                        RealtimeLeaveButton(
                          iconOnly:
                              constraints.maxWidth < 380 ||
                              MediaQuery.textScalerOf(context).scale(17) >= 28,
                          onConfirm: _confirmLeave,
                          onLeft: _onLeft,
                        ),
                      ],
                    ),
                  );
                  return Column(
                    children: [
                      if (!wide) header,
                      Expanded(
                        child: compact
                            ? Column(
                                children: [
                                  Expanded(child: stage),
                                  dock,
                                ],
                              )
                            : RealtimeIdleControls(
                                child: stage,
                                controls: dock,
                                topControls: wide ? header : null,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );

  void _toggle(DemoMeetingPanel panel, {required bool isWide}) {
    if (!isWide) {
      _openMobileSheet(panel);
      return;
    }
    setState(() {
      if (panel == DemoMeetingPanel.classroom) {
        _classroomTab = 0;
        _classroomPanelVisit++;
      }
      _panel = _panel == panel ? DemoMeetingPanel.closed : panel;
    });
  }

  void _openClassroomHands({required bool isWide}) {
    if (!isWide) {
      _openMobileSheet(DemoMeetingPanel.classroom, classroomTab: 1);
      return;
    }
    setState(() {
      _classroomTab = 1;
      // Reopen on the queue even when the panel already shows another tab.
      _classroomPanelVisit++;
      _panel = DemoMeetingPanel.classroom;
    });
  }

  void _openMobileSheet(DemoMeetingPanel panel, {int classroomTab = 0}) {
    final strings = RealtimeStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: RealtimeRoomUiScope(
              room: widget.room,
              child: Container(
                height: MediaQuery.of(sheetContext).size.height * 0.72,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
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
                              color: (switch (panel) {
                                DemoMeetingPanel.chat => const Color(
                                  0xFF0284C7,
                                ),
                                DemoMeetingPanel.classroom => const Color(
                                  0xFF8B5CF6,
                                ),
                                _ => const Color(0xFF1D1D1F),
                              }).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              switch (panel) {
                                DemoMeetingPanel.chat =>
                                  Icons.chat_bubble_outline_rounded,
                                DemoMeetingPanel.classroom =>
                                  Icons.school_outlined,
                                _ => Icons.people_outline_rounded,
                              },
                              size: 16,
                              color: switch (panel) {
                                DemoMeetingPanel.chat => const Color(
                                  0xFF0284C7,
                                ),
                                DemoMeetingPanel.classroom => const Color(
                                  0xFF8B5CF6,
                                ),
                                _ => const Color(0xFF1D1D1F),
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            switch (panel) {
                              DemoMeetingPanel.chat => strings.chat,
                              DemoMeetingPanel.classroom => strings.classroom,
                              _ => strings.participants,
                            },
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
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE5E5EA),
                    ),
                    Expanded(
                      child: switch (panel) {
                        DemoMeetingPanel.chat => const RealtimeChatPanel(),
                        DemoMeetingPanel.classroom => RealtimeClassroomPanel(
                          showHeader: false,
                          initialTab: classroomTab,
                          onClose: () => Navigator.pop(sheetContext),
                        ),
                        _ => const RealtimeManagedParticipantList(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sidePanel() => DemoMeetingSidePanel(
    panel: _panel,
    classroomTab: _classroomTab,
    classroomPanelVisit: _classroomPanelVisit,
    onClose: () => setState(() => _panel = DemoMeetingPanel.closed),
  );

  Future<void> _handleRecording(BuildContext context) async {
    if (_recordingBusy || !mounted) return;
    final isCloud =
        const {
          'livekit',
          'trtc',
          'agora',
          'artc',
          'chime',
          'ivs',
        }.contains(widget.room.engineProviderId) &&
        widget.room.featureBackendUrl != null;

    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    if (!isCloud || !widget.room.media.isLogicalOwner) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            !isCloud
                ? (isZh
                      ? '当前没有可用的云录制后端；本地录制已移除。'
                      : 'Cloud recording is unavailable; local recording was removed.')
                : (isZh
                      ? '只有房主可以操作云录制。'
                      : 'Only the room owner can control cloud recording.'),
          ),
        ),
      );
      return;
    }
    setState(() => _recordingBusy = true);
    try {
      if (widget.room.recordingStatus == RecordingStatus.recording) {
        await widget.room.stopRecording();
        if (!mounted || !context.mounted) return;
        unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
          ),
        );
      } else {
        final chosen = await chooseCloudRecordingLayout(context, widget.room);
        if (chosen == null || !mounted) return;
        await widget.room.startRecording(
          RecordingOptions.cloud(layout: chosen),
        );
        if (mounted && context.mounted) {
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              isZh ? '云录制操作失败：$error' : 'Cloud recording failed: $error',
            ),
            duration: const Duration(seconds: 8),
            showCloseIcon: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recordingBusy = false);
    }
  }

  void _showCloudResultDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
      ),
    );
  }
}

class _DemoMeetingStage extends StatefulWidget {
  const _DemoMeetingStage({
    this.bottomControlsInset = 0,
    this.topOverlayInset = 0,
    required this.useGrid,
  });

  final double bottomControlsInset;
  final double topOverlayInset;
  final bool useGrid;

  @override
  State<_DemoMeetingStage> createState() => _DemoMeetingStageState();
}

class _DemoMeetingStageState extends State<_DemoMeetingStage> {
  String? _pinnedParticipantId;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final hasShare = snapshot.contentShareTrack != null;
        if (hasShare) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const RealtimeSharedContentStage(
                members: RealtimeScreenShareStage(),
              ),
              if (controller.room.classroom != null)
                Positioned(
                  top: widget.topOverlayInset + 8,
                  left: 12,
                  right: 12,
                  child: RealtimeClassroomEventOverlay(
                    classroom: controller.room.classroom!,
                  ),
                ),
              DemoWaveOverlay(room: controller.room),
            ],
          );
        }

        final participants = snapshot.participants;
        if (widget.useGrid || participants.length <= 1) {
          return Stack(
            fit: StackFit.expand,
            children: [
              RealtimeVideoGrid(
                padding: EdgeInsets.fromLTRB(
                  8,
                  widget.topOverlayInset + 8,
                  8,
                  widget.bottomControlsInset + 8,
                ),
              ),
              if (controller.room.classroom != null)
                Positioned(
                  top: widget.topOverlayInset + 8,
                  left: 12,
                  right: 12,
                  child: RealtimeClassroomEventOverlay(
                    classroom: controller.room.classroom!,
                  ),
                ),
              DemoWaveOverlay(room: controller.room),
            ],
          );
        }

        final primaryMember = participants.firstWhere(
          (p) => p.id == _pinnedParticipantId,
          orElse: () => participants.firstWhere(
            (p) => p.isSpeaking && !p.isLocal,
            orElse: () => participants.firstWhere(
              (p) => !p.isLocal && (p.isVideoEnabled || p.videoTrack != null),
              orElse: () => participants.first,
            ),
          ),
        );

        final otherMembers = participants
            .where((p) => p.id != primaryMember.id)
            .toList();

        Widget buildTile(MediaParticipant p) {
          return RealtimeVideoTile(
            key: ValueKey(p.id),
            participant: p,
            showNameTag: false,
          );
        }

        final primaryTile = RealtimeMeetingTileData(
          id: primaryMember.id,
          displayName: _name(primaryMember),
          avatarUrl: primaryMember.avatarUrl,
          isMuted: primaryMember.isMuted,
          isSpeaking: primaryMember.isSpeaking,
          videoWidget: buildTile(primaryMember),
        );

        final otherTiles = otherMembers
            .map(
              (p) => RealtimeMeetingTileData(
                id: p.id,
                displayName: _name(p),
                avatarUrl: p.avatarUrl,
                isMuted: p.isMuted,
                isSpeaking: p.isSpeaking,
                videoWidget: buildTile(p),
              ),
            )
            .toList();

        return Stack(
          fit: StackFit.expand,
          children: [
            RealtimeMeetingFilmstripStage(
              primaryParticipant: primaryTile,
              participants: otherTiles,
              bottomControlsInset: widget.bottomControlsInset,
              onSelectParticipant: (tile) {
                setState(() => _pinnedParticipantId = tile.id);
              },
              // The layout switch lives in the shared header so it cannot be
              // obscured by that same header's floating surface.
              onToggleLayout: null,
            ),
            if (controller.room.classroom != null)
              Positioned(
                top: widget.topOverlayInset + 8,
                left: 12,
                right: 12,
                child: RealtimeClassroomEventOverlay(
                  classroom: controller.room.classroom!,
                ),
              ),
            DemoWaveOverlay(room: controller.room),
          ],
        );
      },
    );
  }

  String _name(MediaParticipant p) {
    if (p.isLocal) {
      return '${p.displayName.isNotEmpty ? p.displayName : p.id} (You)';
    }
    return p.displayName.isNotEmpty ? p.displayName : p.id;
  }
}
