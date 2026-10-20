import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';
import 'prepare_room_page.dart';
import 'recording_action.dart';
import 'meeting_shared_content.dart';

/// Responsive meeting page built from independently reusable SDK components.
///
/// Desktop (>=1000): persistent header, vertical tool rail, stage + stage bar
/// and a trailing 340 pt panel. Phones: header, stage and a floating dock; side
/// panels open as a right-hand drawer.
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
    this.sessionInfo,
    this.brand,
    this.pinnedMessage,
    this.initialSharedContentMode,
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

  /// Host-provided room identity. Falls back to the backend room code.
  final RealtimeMeetingSessionInfo? sessionInfo;

  /// Product mark shown before the room identity on wide headers.
  final Widget? brand;

  /// Host-provided pinned message for the chat panel.
  final String? pinnedMessage;

  /// Shared-content mode applied once after the room is ready.
  final SharedContentMode? initialSharedContentMode;

  @override
  State<RealtimeMeetingPage> createState() => _RealtimeMeetingPageState();
}

class _RealtimeMeetingPageState extends State<RealtimeMeetingPage> {
  late Future<void> _videoEffectsReady;
  int _preparationRevision = 0;
  RealtimeMeetingPanel _panel = RealtimeMeetingPanel.closed;
  int _classroomTab = 0;
  int _classroomPanelVisit = 0;
  bool _recordingBusy = false;
  bool _useGrid = false;
  bool _showFilmstrip = true;
  bool _openedInitialPanel = false;
  final _stageKey = GlobalKey();
  late DateTime _enteredAt;

  @override
  void initState() {
    super.initState();
    _enteredAt = DateTime.now();
    _videoEffectsReady = _prepare();
  }

  void _showActionError(RealtimeException error) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(RealtimeStrings.of(context).displayRealtimeError(error)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _prepare() async {
    final revision = ++_preparationRevision;
    final room = widget.room;
    final settings = widget.initialSettings;
    bool isCurrent() =>
        mounted &&
        revision == _preparationRevision &&
        identical(widget.room, room) &&
        identical(widget.initialSettings, settings);
    await prepareRoomPageWithDeadline(
      room,
      settings,
      isCurrent: isCurrent,
      startSharedContent: true,
    );
    if (!mounted || !isCurrent()) return;
    final initialMode = widget.initialSharedContentMode;
    if (initialMode != null && initialMode != SharedContentMode.members) {
      try {
        await room.sharedContent?.selectMode(initialMode);
      } catch (error) {
        room.reportLifecycleFailure(
          normalizeRealtimeException(
            error,
            domain: 'roomPage',
            operation: 'initialSharedContent',
            providerId: room.providerId,
            stackTrace: StackTrace.current,
          ),
        );
      }
    }
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
      _openedInitialPanel = false;
      _enteredAt = DateTime.now();
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    if (!widget.confirmBeforeLeave) return true;
    final strings = RealtimeStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => RealtimeGlassDialog(
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

  /// Opens the real publish dialog for a classroom tool kind.
  Future<void> _openClassroomTool(BuildContext context, String kind) async {
    final classroom = widget.room.classroom;
    if (classroom == null) return;
    final strings = ClassroomStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => ClassroomPublishToolDialog(
        kind: ClassroomToolKind.values.firstWhere(
          (value) => value.name == kind,
        ),
        classroom: classroom,
        strings: strings,
        onActionError: (RealtimeException error) =>
            RealtimeRoomUiScope.of(context).reportActionError(error),
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
        onActionError: _showActionError,
        child: Scaffold(
          backgroundColor: RealtimeUiTokens.background,
          body: RealtimeAmbientBackground(
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) => ListenableBuilder(
                  listenable: RealtimeRoomUiScope.of(context),
                  builder: (context, _) {
                    final width = constraints.maxWidth;
                    final wide = RealtimeBreakpoints.isWide(context, width);
                    final compact = width < RealtimeBreakpoints.compactMaxWidth;
                    final tablet =
                        !wide && width >= RealtimeBreakpoints.tabletMinWidth;
                    final controller = RealtimeRoomUiScope.of(context);
                    if (wide &&
                        !_openedInitialPanel &&
                        _panel == RealtimeMeetingPanel.closed) {
                      _openedInitialPanel = true;
                      final initialPanel =
                          widget.showChat && widget.room.chat != null
                          ? RealtimeMeetingPanel.chat
                          : widget.showClassroom &&
                                widget.room.classroom != null
                          ? RealtimeMeetingPanel.participants
                          : RealtimeMeetingPanel.closed;
                      if (initialPanel != RealtimeMeetingPanel.closed) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              _panel == RealtimeMeetingPanel.closed) {
                            setState(() => _panel = initialPanel);
                          }
                        });
                      }
                    }
                    final participants = controller.snapshot.participants;
                    final sharedContent = MeetingSharedContent(
                      room: widget.room,
                      snapshot: controller.snapshot,
                      showClassroom: widget.showClassroom,
                    );
                    final sharing = sharedContent.active;
                    // Classroom rooms use the reference teaching workspace:
                    // the whiteboard owns its own tool rail, panels live in
                    // Chat/People/Q&A, and the timer reads as a live class.
                    final classroomWorkspace =
                        widget.showClassroom && widget.room.classroom != null;
                    final whiteboardWorkspace =
                        classroomWorkspace &&
                        sharedContent.mode == SharedContentMode.whiteboard;
                    final dockLabels = RealtimeStrings.of(context);
                    final dockShowsLabels =
                        wide && width >= RealtimeBreakpoints.largeMinWidth;

                    final stage = RealtimeMeetingStage(
                      key: _stageKey,
                      // The dock owns its own row below the stage (reference
                      // classroom layout), so the stage does not reserve a
                      // floating overlay area.
                      bottomControlsInset: 0,
                      useGrid: _useGrid,
                      showFilmstrip: _showFilmstrip,
                      showClassroom: widget.showClassroom,
                      showAnnotations: widget.showAnnotations,
                      showSelfView: true,
                      participantBuilder: widget.participantBuilder,
                      overlayBuilder: widget.stageOverlayBuilder,
                      topOverlayInset: 0,
                    );

                    final dock = Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 8 : 12,
                        0,
                        compact ? 8 : 12,
                        compact ? 8 : 10,
                      ),
                      child: RealtimeMeetingDock(
                        showLabels: dockShowsLabels,
                        // Panels live in the rail on tablets/desktop; phones
                        // keep them in the dock so no action needs a second
                        // surface to discover.
                        mediaGroup: [
                          RealtimeDockMicrophoneButton(
                            showLabel: dockShowsLabels,
                          ),
                          RealtimeDockCameraButton(showLabel: dockShowsLabels),
                          // Tablets and desktop keep the background action in
                          // the dock; phones reach it from More. The header,
                          // rail and More never repeat it.
                          if (!compact)
                            Builder(
                              builder: (context) => ListenableBuilder(
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
                                        showLabel: false,
                                        isActive: controller
                                            .room
                                            .backgroundEffect
                                            .enabled,
                                        onPressed: () =>
                                            unawaited(_openEffects(context)),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          RealtimeDockSharedContentButton(
                            showLabel: dockShowsLabels,
                          ),
                          StreamBuilder<RecordingStatus>(
                            stream: widget.room.recordingStatuses,
                            initialData: widget.room.recordingStatus,
                            builder: (context, snapshot) {
                              final recording =
                                  snapshot.data == RecordingStatus.recording;
                              return RealtimeDockItem(
                                icon: recording
                                    ? Icons.stop_circle_outlined
                                    : Icons.fiber_manual_record_rounded,
                                label: recording
                                    ? (RealtimeStrings.of(context).isZh
                                          ? '停止录制'
                                          : 'Stop rec')
                                    : (RealtimeStrings.of(context).isZh
                                          ? '录制'
                                          : 'Record'),
                                isDanger: recording,
                                showBadgeDot: recording,
                                showLabel: dockShowsLabels,
                                onPressed: () =>
                                    unawaited(_handleRecording(context)),
                              );
                            },
                          ),
                        ],
                        collaborationGroup: [
                          RealtimeDockReactionsButton(
                            showLabel: false,
                            onWave: widget.onCustomReaction != null
                                ? () => unawaited(_sendWave(context))
                                : null,
                          ),
                          if (widget.showClassroom) ...[
                            if (classroomWorkspace &&
                                controller
                                        .classroomState
                                        ?.capabilities
                                        .canPublishTools ==
                                    true) ...[
                              RealtimeDockItem(
                                icon: Icons.poll_outlined,
                                label: dockLabels.isZh ? '投票' : 'Poll',
                                showLabel: dockShowsLabels,
                                onPressed: () =>
                                    _openClassroomTool(context, 'poll'),
                              ),
                              RealtimeDockItem(
                                icon: Icons.timer_outlined,
                                label: dockLabels.isZh ? '计时' : 'Timer',
                                showLabel: dockShowsLabels,
                                onPressed: () =>
                                    _openClassroomTool(context, 'timer'),
                              ),
                            ],
                            RealtimeDockRaiseHandButton(showLabel: false),
                            RealtimeDockHandQueueButton(
                              showLabel: false,
                              onPressed: () =>
                                  _openClassroomHands(isWide: wide),
                            ),
                          ],
                        ],
                        panelsGroup: !compact
                            ? const []
                            : [
                                if (widget.showChat && widget.room.chat != null)
                                  RealtimeDockItem(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: RealtimeStrings.of(context).chat,
                                    onPressed: () => _toggle(
                                      RealtimeMeetingPanel.chat,
                                      isWide: false,
                                    ),
                                    showLabel: false,
                                  ),
                                RealtimeDockItem(
                                  icon: Icons.people_outline_rounded,
                                  label: RealtimeStrings.of(
                                    context,
                                  ).participants,
                                  onPressed: () => _toggle(
                                    RealtimeMeetingPanel.participants,
                                    isWide: false,
                                  ),
                                  showLabel: false,
                                ),
                                if (widget.showClassroom &&
                                    widget.room.classroom != null)
                                  RealtimeDockItem(
                                    icon: Icons.school_outlined,
                                    label: RealtimeStrings.of(
                                      context,
                                    ).classroom,
                                    onPressed: () => _toggle(
                                      RealtimeMeetingPanel.classroom,
                                      isWide: false,
                                    ),
                                    showLabel: false,
                                  ),
                              ],
                        moreAction: _buildMoreAction(
                          context,
                          controller,
                          wide: wide,
                          compact: compact,
                        ),
                        // Leaving stays in the persistent header so the fading
                        // dock never becomes the only exit.
                      ),
                    );

                    final header = _buildHeader(
                      context,
                      controller,
                      wide: wide,
                      compact: compact,
                      participants: participants,
                    );

                    final stageBar = _buildStageBar(
                      context,
                      wide: wide,
                      sharing: sharing,
                      participantCount: participants.length,
                      classroomWorkspace: classroomWorkspace,
                    );

                    return Column(
                      children: [
                        if (widget.header != null) widget.header!,
                        header,
                        // Keep tablet navigation attached to the header rather
                        // than floating over the media stage.
                        if (tablet)
                          RealtimeMeetingRail(
                            horizontal: true,
                            items: _railItems(context, controller, wide: false),
                          ),
                        if (widget.showRtcDataMessages) _rtcDataPanel(),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (wide && !whiteboardWorkspace)
                                RealtimeMeetingRail(
                                  items: _railItems(
                                    context,
                                    controller,
                                    wide: wide,
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    stageBar,
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
                                              controlsMaxWidth: 1100,
                                              // Dedicated bottom row, like the
                                              // reference dock under the tiles.
                                              reserveControlsSpace: true,
                                              autoHide:
                                                  !MediaQuery.accessibleNavigationOf(
                                                    context,
                                                  ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (wide && _panel != RealtimeMeetingPanel.closed)
                                SizedBox(
                                  width: 340,
                                  child: _sidePanel(
                                    workspaceMode: classroomWorkspace,
                                  ),
                                ),
                            ],
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

  Widget _buildHeader(
    BuildContext context,
    RealtimeRoomUiController controller, {
    required bool wide,
    required bool compact,
    required List<MediaParticipant> participants,
  }) {
    final strings = RealtimeStrings.of(context);
    final name = widget.room.media.roomCode;
    final role = RealtimePresentationRole.forMeeting(widget.room.media);
    final classroomMode = widget.showClassroom && widget.room.classroom != null;
    final classroomState = controller.classroomState;
    final roleLabel = classroomState == null
        ? role.label(isZh: strings.isZh)
        : classroomState.isTeacher
        ? (strings.isZh ? '老师' : 'Teacher')
        : (strings.isZh ? '学生' : 'Student');
    final info = widget.sessionInfo;
    final modeLabel =
        (widget.room.media.meetingMode ??
                (widget.room.classroom != null
                    ? MediaMeetingMode.classroom
                    : MediaMeetingMode.standard))
            .label(isZh: strings.isZh);
    final names = participants
        .map((p) => p.displayName.isEmpty ? p.id : p.displayName)
        .toList(growable: false);
    void invite() {
      final messenger = ScaffoldMessenger.maybeOf(context);
      unawaited(
        Clipboard.setData(ClipboardData(text: name)).then((_) {
          messenger?.showSnackBar(
            SnackBar(content: Text(strings.meetingCodeCopied)),
          );
        }),
      );
    }

    return RealtimeMeetingTopBar(
      brand: widget.brand,
      title: info?.title ?? name,
      subtitle: wide
          ? info?.subtitle ??
                '$roleLabel · ${participants.length} ${strings.isZh ? "人在线" : "online"}${widget.showProvider ? " · ${widget.room.providerId}" : ""}'
          : '$modeLabel · $roleLabel',
      compact: !wide,
      dense: wide,
      inviteAction: invite,
      statusWidgets: [
        if (wide)
          RealtimePill(
            label:
                (widget.room.media.meetingMode ??
                        (widget.room.classroom != null
                            ? MediaMeetingMode.classroom
                            : MediaMeetingMode.standard))
                    .label(isZh: strings.isZh),
          ),
        if (!classroomMode)
          Tooltip(
            message: roleLabel,
            child: Icon(
              widget.room.media.isLogicalOwner
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline_rounded,
              size: 16,
              color: RealtimeUiTokens.textMuted,
            ),
          ),
        RealtimeMeetingTimerBadge(startedAt: _enteredAt, live: classroomMode),
        RealtimeRecordingBadge(room: widget.room, compact: true),
        if (wide) const RealtimeConnectionIndicator(),
      ],
      audienceNames: compact ? const [] : names,
      audienceCount: compact ? null : participants.length,
      trailingActions: [
        // The labelled invite button only renders on wide headers, so phones
        // and tablets get an icon-only equivalent instead of a second copy
        // action.
        if (!wide)
          IconButton.outlined(
            tooltip: strings.isZh ? '邀请' : 'Invite',
            style: IconButton.styleFrom(
              foregroundColor: RealtimeStyle.of(context).textSecondary,
              side: BorderSide(color: RealtimeStyle.of(context).border),
              minimumSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
            onPressed: invite,
          ),
        const SizedBox(width: 4),
        RealtimeLeaveButton(
          iconOnly: compact,
          onConfirm: _confirmLeave,
          onLeft: _onLeft,
        ),
      ],
    );
  }

  Widget _buildStageBar(
    BuildContext context, {
    required bool wide,
    required bool sharing,
    required int participantCount,
    bool classroomWorkspace = false,
  }) {
    final strings = RealtimeStrings.of(context);
    // The whiteboard owns its page tabs; a single "Shared content" tab would
    // duplicate them in classroom rooms, so only keep camera layout tabs.
    if (sharing && classroomWorkspace) return const SizedBox.shrink();
    final tabs = sharing
        ? <String>[strings.isZh ? '共享内容' : 'Shared content']
        : <String>[strings.speakerMode, strings.gridMode];
    final selected = sharing ? 0 : (_useGrid ? 1 : 0);
    return RealtimeMeetingStageBar(
      tabs: tabs,
      selectedTab: selected,
      onTabSelected: sharing
          ? null
          : (int index) => setState(() => _useGrid = index == 1),
      actions: [
        if ((sharing && participantCount > 0) ||
            (!sharing && participantCount > 1 && !_useGrid))
          IconButton(
            tooltip: strings.isZh
                ? (_showFilmstrip ? '隐藏缩略图' : '显示缩略图')
                : (_showFilmstrip ? 'Hide thumbnails' : 'Show thumbnails'),
            icon: Icon(
              _showFilmstrip
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
            ),
            onPressed: () => setState(() => _showFilmstrip = !_showFilmstrip),
          ),
      ],
    );
  }

  Widget? _buildMoreAction(
    BuildContext context,
    RealtimeRoomUiController controller, {
    required bool wide,
    required bool compact,
  }) {
    final isZh = RealtimeStrings.of(context).isZh;
    final strings = RealtimeStrings.of(context);
    return RealtimeDockMoreButton(
      showLabel: false,
      hasActiveBadge: widget.room.recordingStatus == RecordingStatus.recording,
      items: [
        if (compact && widget.onCustomReaction != null)
          RealtimeDockMoreItem(
            icon: Icons.waving_hand_rounded,
            title: strings.wave,
            onTap: () => unawaited(_sendWave(context)),
          ),
        if (compact && widget.showChat && widget.room.chat != null)
          RealtimeDockMoreItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: strings.chat,
            onTap: () => _toggle(RealtimeMeetingPanel.chat, isWide: false),
          ),
        if (compact)
          RealtimeDockMoreItem(
            icon: Icons.people_outline_rounded,
            title: strings.participants,
            onTap: () =>
                _toggle(RealtimeMeetingPanel.participants, isWide: false),
          ),
        if (compact && widget.showClassroom && widget.room.classroom != null)
          RealtimeDockMoreItem(
            icon: Icons.school_outlined,
            title: strings.classroom,
            onTap: () => _toggle(RealtimeMeetingPanel.classroom, isWide: false),
          ),
        RealtimeDockMoreItem(
          icon: Icons.cameraswitch_rounded,
          title: strings.flipCamera,
          subtitle: isZh ? '前后切换' : 'Flip',
          onTap: () {
            final current = RealtimeRoomUiScope.of(context);
            unawaited(current.switchCamera());
          },
        ),
        if (compact && controller.snapshot.capabilities.canPublishVideo)
          RealtimeDockMoreItem(
            icon: Icons.blur_on_rounded,
            title: strings.virtualBackground,
            subtitle: controller.room.backgroundCapabilities.isSupported
                ? (isZh ? '背景特效' : 'Effects')
                : (isZh ? '查看不可用原因' : 'Why unavailable'),
            onTap: () => unawaited(_openEffects(context)),
          ),
        if (controller.room.recording.isConfigured)
          RealtimeDockMoreItem(
            icon: Icons.cloud_download_rounded,
            title: isZh ? '录制结果' : 'Recordings',
            subtitle: isZh ? '查看云录像' : 'Files',
            onTap: () => _showCloudResultDialog(context),
          ),
        if (widget.showClassroom &&
            widget.room.classroom?.state?.capabilities.canUseTools == true)
          RealtimeDockMoreItem(
            icon: Icons.build_outlined,
            title: strings.classroomTools,
            subtitle: isZh ? '互动工具' : 'Tools',
            onTap: () => _openClassroomTools(context),
          ),
      ],
    );
  }

  List<RealtimeMeetingRailItem> _railItems(
    BuildContext context,
    RealtimeRoomUiController controller, {
    required bool wide,
  }) {
    final strings = RealtimeStrings.of(context);
    // Panels and the host reaction live here. Action entry points stay
    // single-sourced: raise hand in the dock, background in the dock/More and
    // layout in the stage bar.
    return [
      if (widget.showChat && widget.room.chat != null)
        RealtimeMeetingRailItem(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: strings.chat,
          active: wide && _panel == RealtimeMeetingPanel.chat,
          onPressed: () => _toggle(RealtimeMeetingPanel.chat, isWide: wide),
        ),
      RealtimeMeetingRailItem(
        icon: Icons.people_outline_rounded,
        tooltip: strings.participants,
        active: wide && _panel == RealtimeMeetingPanel.participants,
        onPressed: () =>
            _toggle(RealtimeMeetingPanel.participants, isWide: wide),
      ),
      if (widget.showClassroom && widget.room.classroom != null)
        RealtimeMeetingRailItem(
          icon: Icons.school_outlined,
          tooltip: strings.classroom,
          active: wide && _panel == RealtimeMeetingPanel.classroom,
          onPressed: () =>
              _toggle(RealtimeMeetingPanel.classroom, isWide: wide),
        ),
      if (widget.onCustomReaction != null) ...[
        const RealtimeMeetingRailItem.divider(),
        RealtimeMeetingRailItem(
          icon: Icons.waving_hand_rounded,
          tooltip: strings.reactions,
          onPressed: () => unawaited(_sendWave(context)),
        ),
      ],
    ];
  }

  void _toggle(RealtimeMeetingPanel panel, {required bool isWide}) {
    if (!isWide) {
      _openDrawer(panel);
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
      _openDrawer(RealtimeMeetingPanel.classroom, classroomTab: 1);
      return;
    }
    setState(() {
      _classroomTab = 1;
      // Reopen on the queue even when the panel already shows another tab.
      _classroomPanelVisit++;
      _panel = RealtimeMeetingPanel.classroom;
    });
  }

  void _openDrawer(RealtimeMeetingPanel panel, {int classroomTab = 0}) {
    final strings = RealtimeStrings.of(context);
    unawaited(
      showRealtimeRoomDrawer<void>(
        context,
        title: switch (panel) {
          RealtimeMeetingPanel.chat => strings.chat,
          RealtimeMeetingPanel.classroom => strings.classroom,
          _ => strings.participants,
        },
        icon: switch (panel) {
          RealtimeMeetingPanel.chat => Icons.chat_bubble_outline_rounded,
          RealtimeMeetingPanel.classroom => Icons.school_outlined,
          _ => Icons.people_outline_rounded,
        },
        child: RealtimeRoomUiScope(
          room: widget.room,
          child: switch (panel) {
            RealtimeMeetingPanel.chat => const RealtimeChatPanel(),
            RealtimeMeetingPanel.classroom => RealtimeClassroomPanel(
              showHeader: false,
              initialTab: classroomTab,
              onClose: () => Navigator.maybePop(context),
            ),
            _ => const RealtimeManagedParticipantList(),
          },
        ),
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

  Widget _sidePanel({bool workspaceMode = false}) => RealtimeMeetingSidePanel(
    panel: _panel,
    classroomTab: _classroomTab,
    classroomPanelVisit: _classroomPanelVisit,
    workspaceMode: workspaceMode,
    pinnedMessage: widget.pinnedMessage,
    recordingPanel:
        workspaceMode &&
            widget.room.recording.isConfigured &&
            widget.room.media.isLogicalOwner
        ? RealtimeRecordingPanel(
            room: widget.room,
            busy: _recordingBusy,
            onToggleRecording: () => unawaited(_handleRecording(context)),
            onOpenResult: () => _showCloudResultDialog(context),
          )
        : null,
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
