import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';
import 'prepare_room_page.dart';
import 'recording_action.dart';
import 'meeting_shared_content.dart';

/// Responsive meeting page built from independently reusable SDK components.
class RealtimeMeetingPage extends StatefulWidget {
  const RealtimeMeetingPage({
    super.key,
    required this.room,
    this.initialSettings,
    this.imagePresets = const [],
    this.loadImagePresets,
    this.onLeft,
    this.confirmBeforeLeave = true,
    this.header,
    this.showChat = true,
    this.showClassroom = true,
    this.showAnnotations = true,
    this.showProvider = false,
    this.showRtcDataMessages = false,
    this.participantBuilder,
    this.onCustomReaction,
    this.stageOverlayBuilder,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings? initialSettings;
  final List<MediaBackgroundImagePreset> imagePresets;
  final Future<List<MediaBackgroundImagePreset>> Function()? loadImagePresets;
  final VoidCallback? onLeft;
  final bool confirmBeforeLeave;
  final Widget? header;
  final bool showChat;
  final bool showClassroom;
  final bool showAnnotations;
  final bool showProvider;
  final bool showRtcDataMessages;
  final MediaParticipantBuilder? participantBuilder;
  final Future<void> Function(BuildContext context)? onCustomReaction;
  final WidgetBuilder? stageOverlayBuilder;

  @override
  State<RealtimeMeetingPage> createState() => _RealtimeMeetingPageState();
}

class _RealtimeMeetingPageState extends State<RealtimeMeetingPage> {
  late Future<void> _videoEffectsReady;
  RealtimeMeetingPanel _panel = RealtimeMeetingPanel.closed;
  int _classroomTab = 0;
  int _classroomPanelVisit = 0;
  bool _recordingBusy = false;
  bool _useGrid = false;
  bool _showFilmstrip = true;
  final _stageKey = GlobalKey();
  late DateTime _enteredAt;

  @override
  void initState() {
    super.initState();
    _enteredAt = DateTime.now();
    _videoEffectsReady = _prepare();
  }

  Future<void> _prepare() async {
    final room = widget.room;
    final settings = widget.initialSettings;
    bool isCurrent() =>
        mounted &&
        identical(widget.room, room) &&
        identical(widget.initialSettings, settings);
    await prepareRoomPage(room, settings, isCurrent: isCurrent);
    if (isCurrent()) await room.sharedContent?.start();
  }

  @override
  void didUpdateWidget(covariant RealtimeMeetingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room)) _showFilmstrip = true;
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.initialSettings != widget.initialSettings) {
      _videoEffectsReady = _prepare();
      _panel = RealtimeMeetingPanel.closed;
      _classroomTab = 0;
      _classroomPanelVisit = 0;
      _useGrid = false;
      _enteredAt = DateTime.now();
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!widget.confirmBeforeLeave) return true;
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
    if (widget.onLeft != null) {
      widget.onLeft!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _openEffects(BuildContext context) async {
    await showRealtimeBackgroundEffectsSheet(
      context,
      loadImagePresets: widget.loadImagePresets,
      imagePresets: widget.imagePresets,
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
      controller.reportActionError(error);
    }
  }

  Future<void> _sendWave(BuildContext context) async {
    try {
      await widget.onCustomReaction?.call(context);
    } catch (error) {
      if (context.mounted) {
        RealtimeRoomUiScope.of(context).reportActionError(error);
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
                Text(
                  RealtimeStrings.of(
                    context,
                  ).displayRealtimeError(snapshot.error!),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _videoEffectsReady = _prepare();
                  }),
                  child: Text(RealtimeStrings.of(context).runAgain),
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
                builder: (context, constraints) => ListenableBuilder(
                  listenable: RealtimeRoomUiScope.of(context),
                  builder: (context, _) {
                    final wide =
                        constraints.maxWidth >= 1000 &&
                        MediaQuery.textScalerOf(context).scale(17) < 28;
                    // Compact (<600pt, e.g. phones): dock collapses to core
                    // actions + More so nothing overflows; timer moves up.
                    final compact = constraints.maxWidth < 600;
                    // When a wide desktop sidebar opens, the available *video*
                    // pane is narrower by 330pt. Collapse secondary dock
                    // actions into More rather than leaving buttons visually
                    // behind the sidebar or outside the hit-testable scroll.
                    final collapseDock =
                        compact ||
                        (wide && _panel != RealtimeMeetingPanel.closed);
                    // At 1024px the existing meeting actions already use the
                    // available dock width. Keep virtual background in More
                    // until there is room for a dedicated, hit-testable action.
                    final showBackgroundInDock =
                        !collapseDock && constraints.maxWidth >= 1280;
                    final dock = Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: RealtimeMeetingDock(
                        showLabels:
                            wide &&
                            !collapseDock &&
                            constraints.maxWidth >= 1150,
                        leadingStatus: collapseDock
                            ? null
                            : RealtimeMeetingTimerBadge(startedAt: _enteredAt),
                        mediaGroup: [
                          RealtimeDockMicrophoneButton(showLabel: wide),
                          RealtimeDockCameraButton(showLabel: wide),
                          if (showBackgroundInDock)
                            Builder(
                              builder: (context) {
                                final controller = RealtimeRoomUiScope.of(
                                  context,
                                );
                                return ListenableBuilder(
                                  listenable: controller,
                                  builder: (context, _) =>
                                      controller
                                          .snapshot
                                          .capabilities
                                          .canPublishVideo
                                      ? RealtimeDockItem(
                                          icon: Icons.blur_on_outlined,
                                          label: RealtimeStrings.of(
                                            context,
                                          ).virtualBackground,
                                          showLabel: wide,
                                          isActive: controller
                                              .room
                                              .backgroundEffect
                                              .enabled,
                                          tooltip:
                                              controller
                                                  .room
                                                  .backgroundCapabilities
                                                  .isSupported
                                              ? null
                                              : (RealtimeStrings.of(
                                                      context,
                                                    ).isZh
                                                    ? '当前不可用，点击查看原因'
                                                    : 'Unavailable — tap for details'),
                                          onPressed: () =>
                                              unawaited(_openEffects(context)),
                                        )
                                      : const SizedBox.shrink(),
                                );
                              },
                            ),
                          if (collapseDock)
                            (widget.showClassroom
                                ? RealtimeDockSharedContentButton(
                                    showLabel: wide,
                                  )
                                : const RealtimeScreenShareButton())
                          else ...[
                            if (widget.showClassroom)
                              RealtimeDockRaiseHandButton(showLabel: wide),
                            if (widget.showClassroom)
                              RealtimeDockHandQueueButton(
                                showLabel: wide,
                                onPressed: () =>
                                    _openClassroomHands(isWide: wide),
                              ),
                          ],
                        ],
                        collaborationGroup: collapseDock
                            ? const []
                            : [
                                (widget.showClassroom
                                    ? RealtimeDockSharedContentButton(
                                        showLabel: wide,
                                      )
                                    : const RealtimeScreenShareButton()),
                                RealtimeDockReactionsButton(
                                  showLabel: wide,
                                  onWave: widget.onCustomReaction != null
                                      ? () => unawaited(_sendWave(context))
                                      : null,
                                ),
                              ],
                        panelsGroup: collapseDock
                            ? const []
                            : [
                                if (widget.showChat && widget.room.chat != null)
                                  RealtimeDockItem(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: RealtimeStrings.of(context).chat,
                                    isActive:
                                        wide &&
                                        _panel == RealtimeMeetingPanel.chat,
                                    onPressed: () => _toggle(
                                      RealtimeMeetingPanel.chat,
                                      isWide: wide,
                                    ),
                                    showLabel: wide,
                                  ),
                                RealtimeDockItem(
                                  icon: Icons.people_outline_rounded,
                                  label: RealtimeStrings.of(
                                    context,
                                  ).participants,
                                  isActive:
                                      wide &&
                                      _panel ==
                                          RealtimeMeetingPanel.participants,
                                  onPressed: () => _toggle(
                                    RealtimeMeetingPanel.participants,
                                    isWide: wide,
                                  ),
                                  showLabel: wide,
                                ),
                                if (widget.showClassroom &&
                                    widget.room.classroom != null)
                                  RealtimeDockItem(
                                    icon: Icons.school_outlined,
                                    label: RealtimeStrings.of(
                                      context,
                                    ).classroom,
                                    isActive:
                                        wide &&
                                        _panel ==
                                            RealtimeMeetingPanel.classroom,
                                    onPressed: () => _toggle(
                                      RealtimeMeetingPanel.classroom,
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
                            final isCloud = widget.room.recording.isConfigured;

                            final roomController = RealtimeRoomUiScope.of(
                              context,
                            );
                            return ListenableBuilder(
                              listenable: roomController,
                              builder: (context, _) => RealtimeDockMoreButton(
                                showLabel: wide,
                                hasActiveBadge: isRecording,
                                items: [
                                  // Compact overflow: actions hidden from the
                                  // dock stay one tap away in More.
                                  if (widget.showClassroom &&
                                      collapseDock &&
                                      roomController.canRaiseHand &&
                                      roomController.classroomState != null)
                                    RealtimeDockMoreItem(
                                      icon: Icons.pan_tool_outlined,
                                      title: RealtimeStrings.of(
                                        context,
                                      ).raiseHand,
                                      onTap: () =>
                                          unawaited(_toggleRaiseHand(context)),
                                    ),
                                  if (widget.showClassroom && collapseDock)
                                    RealtimeDockMoreItem(
                                      icon: Icons.group_outlined,
                                      title: RealtimeStrings.of(
                                        context,
                                      ).classroomHands,
                                      onTap: () =>
                                          _openClassroomHands(isWide: false),
                                    ),
                                  if (collapseDock &&
                                      widget.onCustomReaction != null)
                                    RealtimeDockMoreItem(
                                      icon: Icons.waving_hand_rounded,
                                      title: RealtimeStrings.of(context).wave,
                                      onTap: () =>
                                          unawaited(_sendWave(context)),
                                    ),
                                  if (collapseDock &&
                                      widget.showChat &&
                                      widget.room.chat != null)
                                    RealtimeDockMoreItem(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      title: RealtimeStrings.of(context).chat,
                                      onTap: () => _toggle(
                                        RealtimeMeetingPanel.chat,
                                        isWide: wide,
                                      ),
                                    ),
                                  if (collapseDock)
                                    RealtimeDockMoreItem(
                                      icon: Icons.people_outline_rounded,
                                      title: RealtimeStrings.of(
                                        context,
                                      ).participants,
                                      onTap: () => _toggle(
                                        RealtimeMeetingPanel.participants,
                                        isWide: wide,
                                      ),
                                    ),
                                  if (collapseDock &&
                                      widget.showClassroom &&
                                      widget.room.classroom != null)
                                    RealtimeDockMoreItem(
                                      icon: Icons.school_outlined,
                                      title: RealtimeStrings.of(
                                        context,
                                      ).classroom,
                                      onTap: () => _toggle(
                                        RealtimeMeetingPanel.classroom,
                                        isWide: wide,
                                      ),
                                    ),
                                  RealtimeDockMoreItem(
                                    icon: Icons.cameraswitch_rounded,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).flipCamera,
                                    subtitle: isZh ? '前后切换' : 'Flip',
                                    onTap: () {
                                      final controller = RealtimeRoomUiScope.of(
                                        context,
                                      );
                                      unawaited(controller.switchCamera());
                                    },
                                  ),
                                  if (!showBackgroundInDock &&
                                      roomController
                                          .snapshot
                                          .capabilities
                                          .canPublishVideo)
                                    RealtimeDockMoreItem(
                                      icon: Icons.blur_on_rounded,
                                      title: RealtimeStrings.of(
                                        context,
                                      ).virtualBackground,
                                      subtitle:
                                          roomController
                                              .room
                                              .backgroundCapabilities
                                              .isSupported
                                          ? (isZh ? '背景特效' : 'Effects')
                                          : (isZh
                                                ? '查看不可用原因'
                                                : 'Why unavailable'),
                                      onTap: () =>
                                          unawaited(_openEffects(context)),
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
                                              : (isZh
                                                    ? '录制不可用'
                                                    : 'Unavailable')),
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
                                  if (widget.showClassroom &&
                                      widget
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
                              final controller = RealtimeRoomUiScope.of(
                                context,
                              );
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
                    final roomController = RealtimeRoomUiScope.of(context);
                    final sharing = MeetingSharedContent(
                      room: widget.room,
                      snapshot: roomController.snapshot,
                      showClassroom: widget.showClassroom,
                    ).active;
                    final stage = RealtimeMeetingStage(
                      key: _stageKey,
                      bottomControlsInset: compact || sharing ? 0 : 90,
                      useGrid: _useGrid,
                      showFilmstrip: _showFilmstrip,
                      showClassroom: widget.showClassroom,
                      showAnnotations: widget.showAnnotations,
                      participantBuilder: widget.participantBuilder,
                      overlayBuilder: widget.stageOverlayBuilder,
                      topOverlayInset: wide ? 58 : 0,
                    );
                    final header = ListenableBuilder(
                      listenable: roomController,
                      builder: (context, _) => RealtimeMeetingTopBar(
                        compact: !wide,
                        dense: wide,
                        title: widget.room.media.roomCode,
                        // The UUID is available in the members panel. It made
                        // the floating header three lines tall over the video.
                        subtitle: wide ? null : widget.room.media.participantId,
                        statusWidgets: [
                          if (widget.showProvider) Text(widget.room.providerId),
                          Tooltip(
                            message: RealtimePresentationRole.forMeeting(
                              widget.room.media,
                            ).label(isZh: RealtimeStrings.of(context).isZh),
                            child: Icon(
                              widget.room.media.isLogicalOwner
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.person_outline_rounded,
                              size: 16,
                              color: RealtimeUiTokens.textMuted,
                            ),
                          ),
                          RealtimeRecordingBadge(
                            room: widget.room,
                            compact: true,
                          ),
                          if (compact)
                            RealtimeMeetingTimerBadge(startedAt: _enteredAt),
                        ],
                        trailingActions: [
                          if (wide) const RealtimeConnectionIndicator(),
                          if (!sharing &&
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
                          if ((sharing &&
                                  roomController
                                      .snapshot
                                      .participants
                                      .isNotEmpty) ||
                              (!_useGrid &&
                                  roomController.snapshot.participants.length >
                                      1))
                            IconButton(
                              key: const ValueKey('meeting-toggle-filmstrip'),
                              tooltip: RealtimeStrings.of(context).isZh
                                  ? (_showFilmstrip ? '隐藏缩略图' : '显示缩略图')
                                  : (_showFilmstrip
                                        ? 'Hide thumbnails'
                                        : 'Show thumbnails'),
                              icon: Icon(
                                _showFilmstrip
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _showFilmstrip = !_showFilmstrip,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.blur_on_rounded, size: 20),
                            tooltip: RealtimeStrings.of(
                              context,
                            ).virtualBackground,
                            onPressed: () => unawaited(_openEffects(context)),
                          ),
                          RealtimeLeaveButton(
                            iconOnly:
                                constraints.maxWidth < 380 ||
                                MediaQuery.textScalerOf(context).scale(17) >=
                                    28,
                            onConfirm: _confirmLeave,
                            onLeft: _onLeft,
                          ),
                        ],
                      ),
                    );
                    return Column(
                      children: [
                        if (widget.header != null) widget.header!,
                        if (!wide) header,
                        if (widget.showRtcDataMessages) _rtcDataPanel(),
                        Expanded(
                          child: compact
                              ? Column(
                                  children: [
                                    Expanded(child: stage),
                                    dock,
                                  ],
                                )
                              : wide
                              // Header and dock belong to the *video pane*
                              // only. When a right sidebar is open, it must
                              // remain a sibling rather than sit behind the
                              // full-width header's Stack/hit testing.
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: RealtimeIdleControls(
                                        child: stage,
                                        controls: dock,
                                        topControls: header,
                                        reserveControlsSpace: sharing,
                                        controlsMaxWidth: 1100,
                                      ),
                                    ),
                                    if (_panel != RealtimeMeetingPanel.closed)
                                      SizedBox(width: 330, child: _sidePanel()),
                                  ],
                                )
                              : RealtimeIdleControls(
                                  child: stage,
                                  controls: dock,
                                  reserveControlsSpace: sharing,
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  void _toggle(RealtimeMeetingPanel panel, {required bool isWide}) {
    if (!isWide) {
      _openMobileSheet(panel);
      return;
    }
    setState(() {
      if (panel == RealtimeMeetingPanel.classroom) {
        _classroomTab = 0;
        _classroomPanelVisit++;
      }
      _panel = _panel == panel ? RealtimeMeetingPanel.closed : panel;
    });
  }

  void _openClassroomHands({required bool isWide}) {
    if (!isWide) {
      _openMobileSheet(RealtimeMeetingPanel.classroom, classroomTab: 1);
      return;
    }
    setState(() {
      _classroomTab = 1;
      // Reopen on the queue even when the panel already shows another tab.
      _classroomPanelVisit++;
      _panel = RealtimeMeetingPanel.classroom;
    });
  }

  void _openMobileSheet(RealtimeMeetingPanel panel, {int classroomTab = 0}) {
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
                                RealtimeMeetingPanel.chat => const Color(
                                  0xFF0284C7,
                                ),
                                RealtimeMeetingPanel.classroom => const Color(
                                  0xFF8B5CF6,
                                ),
                                _ => const Color(0xFF1D1D1F),
                              }).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              switch (panel) {
                                RealtimeMeetingPanel.chat =>
                                  Icons.chat_bubble_outline_rounded,
                                RealtimeMeetingPanel.classroom =>
                                  Icons.school_outlined,
                                _ => Icons.people_outline_rounded,
                              },
                              size: 16,
                              color: switch (panel) {
                                RealtimeMeetingPanel.chat => const Color(
                                  0xFF0284C7,
                                ),
                                RealtimeMeetingPanel.classroom => const Color(
                                  0xFF8B5CF6,
                                ),
                                _ => const Color(0xFF1D1D1F),
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            switch (panel) {
                              RealtimeMeetingPanel.chat => strings.chat,
                              RealtimeMeetingPanel.classroom =>
                                strings.classroom,
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
                        RealtimeMeetingPanel.chat => const RealtimeChatPanel(),
                        RealtimeMeetingPanel.classroom =>
                          RealtimeClassroomPanel(
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

  Widget _rtcDataPanel() => RoomRtcDataPanel(
    session: widget.room.media.session,
    onError: (message) {
      if (message != null) {
        RealtimeRoomUiScope.of(context).reportActionError(
          RealtimeException(
            code: RealtimeErrorCode.unknown,
            message: 'room.data.send',
          ),
        );
      }
    },
  );

  Widget _sidePanel() => RealtimeMeetingSidePanel(
    panel: _panel,
    classroomTab: _classroomTab,
    classroomPanelVisit: _classroomPanelVisit,
    onClose: () => setState(() => _panel = RealtimeMeetingPanel.closed),
  );

  Future<void> _handleRecording(BuildContext context) async {
    if (_recordingBusy || !mounted) return;
    final room = widget.room;
    setState(() => _recordingBusy = true);
    try {
      await toggleRoomRecording(
        context,
        room,
        isCurrent: () => mounted && identical(room, widget.room),
      );
    } catch (error) {
      if (mounted && context.mounted && identical(room, widget.room)) {
        RealtimeRoomUiScope.of(context).reportActionError(error);
      }
    } finally {
      if (mounted) setState(() => _recordingBusy = false);
    }
  }

  void _showCloudResultDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => RealtimeRecordingResultDialog(room: widget.room),
      ),
    );
  }
}
