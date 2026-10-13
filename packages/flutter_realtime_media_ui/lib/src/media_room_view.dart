import 'live_room_danmaku.dart';
import 'live_room_dock.dart';
import 'live_room_header.dart';
import 'meeting_room_dock.dart';
import 'meeting_room_header.dart';
import 'media_room_waiting_view.dart';
import 'media_meeting_video_stage.dart';
import 'media_live_video_stage.dart';
import 'media_room_view_config.dart';
import 'media_room_layout_mode.dart';
import 'media_participant_builder.dart';
import 'room_members_panel.dart';
import 'room_members_presentation_controller.dart';
import 'room_chat_panel.dart';
import 'room_chat_presentation_controller.dart';
export 'media_participant_tile.dart' show MediaParticipantTile;
import 'room_chat_events_controller.dart';
import 'room_auxiliary_subscriptions.dart';
import 'room_rtc_data_panel.dart';
import 'initial_media_settings_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'live_likes_controller.dart';
import 'live_reactions_controller.dart';
import 'live_reaction_particle.dart';
import 'meeting_room_layout.dart';
import 'live_room_layout.dart';
import 'room_regions.dart';
import 'background_effect_selector.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

class MediaRoomView extends StatefulWidget {
  const MediaRoomView({
    super.key,
    required this.room,
    required this.renderer,
    this.chatSession,
    this.chatModeration,
    this.liveLikes,
    this.config = const MediaRoomViewConfig(),
    this.header,
    this.participantBuilder,
    this.onLeave,
    this.onActionError,
    this.backgroundEffects,
    this.canEnableMicrophone,
    this.microphonePermissionUpdates,
    this.screenShareOverlayBuilder,
    this.contentStageBuilder,
    this.contentStageUpdates,
    this.contentControlsBuilder,
    this.extraControlsBuilder,
    this.liveGiftPanelOpener,
  });
  final MediaRoomSession room;
  final MediaTrackRenderer renderer;
  final ChatSession? chatSession;
  final ChatModeration? chatModeration;

  /// Optional synchronized live likes supplied by the SDK composition layer.
  final LiveLikesController? liveLikes;
  final MediaRoomViewConfig config;
  final Widget? header;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;
  final ValueChanged<RealtimeException>? onActionError;
  final MediaBackgroundEffectsController? backgroundEffects;

  /// Optional SDK-layer advisory classroom microphone gate.
  /// Backend/provider enforcement must be implemented separately.
  final bool Function()? canEnableMicrophone;
  final Stream<Object?>? microphonePermissionUpdates;

  /// Occupies the same contained content rectangle as the shared video.
  /// Hosts may add provider-neutral annotations without replacing rendering.
  final Widget Function(BuildContext context, MediaVideoTrack track)?
  screenShareOverlayBuilder;

  /// Null stage uses member view while retaining camera renderers.
  final Widget? Function(BuildContext, MediaSnapshot)? contentStageBuilder;
  final Stream<Object?>? contentStageUpdates;

  /// Null controls preserve the legacy screen-share button.
  final Widget? Function(BuildContext)? contentControlsBuilder;

  /// Optional additional controls placed into the bottom dock controls,
  /// placed after content sharing controls and before room administration.
  final List<Widget> Function(BuildContext)? extraControlsBuilder;

  /// Optional direct opener for the live gift panel.
  /// When provided, the live bottom-bar gift button opens the gift panel
  /// in one tap instead of routing through the extra-controls sheet.
  /// Null keeps the legacy sheet fallback, so plain [MediaRoomView] users
  /// without a gift-panel integration stay unaffected.
  final Future<void> Function(BuildContext context)? liveGiftPanelOpener;
  @override
  State<MediaRoomView> createState() => _MediaRoomViewState();
}

class _MediaRoomViewState extends State<MediaRoomView> {
  final _auxiliarySubscriptions = RoomAuxiliarySubscriptions();
  Widget? _cachedMediaStage;
  List<Object?> _mediaStageKey = [];
  final _controlRevision = ValueNotifier<int>(0);
  final _liveReactions = LiveReactionsController();
  ValueNotifier<int> get _likeRevision => _liveReactions.revision;
  final _chatEvents = RoomChatEventsController();
  late final _chatPresentation = RoomChatPresentationController(
    onSent: () {
      if (mounted) setState(() => _error = null);
    },
    onError: (error) {
      widget.onActionError?.call(error);
      if (mounted) setState(() => _error = error.message);
    },
  );
  final _chatRevision = ValueNotifier<int>(0);
  late final _membersPresentation = RoomMembersPresentationController(
    onError: (error) => widget.onActionError?.call(error),
  );
  final _initialSettings = InitialMediaSettingsController();
  Timer? _copyTimer;
  int get _unreadChatCount => _chatEvents.unread;
  bool _chatOpen = false;
  bool _participantsOpen = false;
  bool _rtcDataOpen = false;
  bool _liveChatInputOpen = false;
  bool _copied = false;
  bool _initialSettingsApplied = false;
  String? _error;
  MediaRoomLayoutMode _layoutMode = MediaRoomLayoutMode.grid;
  bool _cleanScreen = false;
  int get _likeCount => _liveReactions.totalLikes;
  List<LiveReactionHeart> get _floatingHearts => _liveReactions.hearts;
  MediaSession get session => widget.room.session;
  MediaBackgroundEffectsController get _backgroundEffects =>
      widget.backgroundEffects ?? widget.room;

  void _sendLike() {
    if (widget.liveLikes != null) {
      observeDetached(_run(_liveReactions.sendLike));
    }
  }

  void _onLikeTotalChanged() => _controlRevision.value++;

  void _watchLikes() {
    _liveReactions.bind(widget.liveLikes);
  }

  void _toggleCleanScreen() {
    setState(() => _cleanScreen = !_cleanScreen);
  }

  @override
  void initState() {
    super.initState();
    _membersPresentation.bind(
      widget.room,
      widget.chatSession,
      widget.chatModeration,
    );
    _liveReactions.totalsRevision.addListener(_onLikeTotalChanged);
    _watchUnreadChat();
    _watchMicPermission();
    _watchContent();
    _watchLikes();
  }

  @override
  void didUpdateWidget(covariant MediaRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cachedMediaStage = null;
    final rosterSourceChanged =
        !identical(oldWidget.room, widget.room) ||
        !identical(oldWidget.chatSession, widget.chatSession) ||
        !identical(oldWidget.chatModeration, widget.chatModeration);
    if (rosterSourceChanged) {
      _membersPresentation.bind(
        widget.room,
        widget.chatSession,
        widget.chatModeration,
      );
      if (_participantsOpen) unawaited(_membersPresentation.refresh());
    }
    if (oldWidget.room != widget.room) {
      _initialSettingsApplied = false;
      _chatPresentation.reset();
      _liveChatInputOpen = false;
    }
    if (oldWidget.liveLikes != widget.liveLikes ||
        oldWidget.room != widget.room) {
      _watchLikes();
    }
    if (oldWidget.room != widget.room ||
        oldWidget.chatSession != widget.chatSession) {
      _watchUnreadChat();
    }
    if (oldWidget.contentStageUpdates != widget.contentStageUpdates) {
      _watchContent();
    }
    if (oldWidget.microphonePermissionUpdates !=
        widget.microphonePermissionUpdates) {
      _watchMicPermission();
    }
  }

  void _watchContent() {
    _auxiliarySubscriptions.bindContent(
      widget.contentStageUpdates,
      invalidate: () {
        if (mounted) setState(() => _cachedMediaStage = null);
      },
    );
  }

  void _watchMicPermission() {
    _auxiliarySubscriptions.bindMicrophone(
      widget.microphonePermissionUpdates,
      onPermissionChanged: () {
        if (!mounted) return;
        _controlRevision.value++;
        if (widget.canEnableMicrophone?.call() == false &&
            session is InteractiveMediaSession &&
            !session.snapshot.localMuted) {
          unawaited(
            _run(() => (session as InteractiveMediaSession).setMuted(true)),
          );
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedMediaStage = null;
  }

  void _watchUnreadChat() {
    _chatEvents.bind(
      widget.chatSession,
      isChatOpen: () => _chatOpen,
      isOwn: _isOwnChatMessage,
      onUnread: () {
        _controlRevision.value++;
        _chatRevision.value++;
      },
    );
    _chatPresentation.reset();
  }

  void _updateRoom(VoidCallback update) => setState(update);
  Future<void> _applyInitialSettings() async {
    if (_initialSettingsApplied) return;
    _initialSettingsApplied = true;
    final settings = widget.config.initialMediaSettings;
    if (settings == null) return;
    final targetRoom = widget.room;
    await _initialSettings.apply(
      session: session,
      effects: _backgroundEffects,
      settings: settings,
      isCurrent: () => mounted && targetRoom == widget.room,
      canEnableMicrophone: () => widget.canEnableMicrophone?.call() != false,
      onError: (error) {
        if (mounted && targetRoom == widget.room) {
          setState(() => _error = error.toString());
        }
      },
    );
  }

  @override
  void dispose() {
    _liveReactions.totalsRevision.removeListener(_onLikeTotalChanged);
    _auxiliarySubscriptions.dispose();
    _copyTimer?.cancel();
    _membersPresentation.dispose();
    _controlRevision.dispose();
    _liveReactions.dispose();
    _chatEvents.dispose();
    _chatRevision.dispose();
    _chatPresentation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } on Object catch (error, stack) {
      final failure = normalizeRealtimeException(
        error,
        domain: 'room.ui',
        stackTrace: stack,
      );
      widget.onActionError?.call(failure);
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _leave() async {
    var leave = true;
    if (widget.config.confirmBeforeLeave) {
      final strings = RealtimeStrings.of(context);
      leave =
          await showDialog<bool>(
            context: context,
            useRootNavigator: true,
            barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.34),
            builder: (context) => RealtimeGlassDialog(
              icon: Icons.call_end_rounded,
              iconColor: RealtimeUiTokens.danger,
              iconBackground: RealtimeUiTokens.dangerSubtle,
              title: Text(
                widget.room.role == MediaRole.host &&
                        widget.room.managementCapabilities.closeRoom.supported
                    ? strings.endLiveRoom
                    : strings.leaveRoomTitle,
              ),
              content: Text(
                widget.room.role == MediaRole.host &&
                        widget.room.managementCapabilities.closeRoom.supported
                    ? strings.closeLiveRoomConfirmation
                    : strings.leaveRoomConfirmation,
                style: const TextStyle(
                  color: RealtimeUiTokens.textMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings.cancel),
                ),
                RealtimeGlassPressable(
                  borderRadius: RealtimeUiTokens.controlRadius,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: RealtimeUiTokens.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                      ),
                    ),
                    child: Text(strings.leave),
                  ),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!leave) return;
    if (widget.room.role == MediaRole.host &&
        widget.room.managementCapabilities.closeRoom.supported) {
      try {
        await widget.room.closeRoom();
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
        return;
      }
    }
    await widget.chatSession?.dispose();
    await widget.room.dispose();
    widget.onLeave?.call();
    if (widget.onLeave == null && mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _copyCode() {
    observeDetached(
      Clipboard.setData(ClipboardData(text: widget.room.roomCode)),
    );
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  bool get isLive {
    if (widget.config.roomMode != null) {
      return widget.config.roomMode == MediaRoomMode.broadcast;
    }
    // A host can host an ordinary meeting. Only the viewer role implies
    // broadcast when no explicit room mode has been supplied.
    return widget.room.role == MediaRole.viewer;
  }

  void setLayoutMode(MediaRoomLayoutMode mode) {
    setState(() => _layoutMode = mode);
  }

  Future<void> _showMeetingLeaveConfirmation() async {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final canCloseRoom =
        widget.room.role == MediaRole.host &&
        widget.room.managementCapabilities.closeRoom.supported;

    if (!widget.config.confirmBeforeLeave) {
      await _leave();
      return;
    }

    if (canCloseRoom) {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => RealtimeGlassDialog(
          icon: Icons.meeting_room_rounded,
          iconColor: style.danger,
          iconBackground: style.danger.withValues(alpha: 0.14),
          title: Text(strings.leaveMeeting),
          content: Text(strings.endMeetingForAllDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                strings.cancel,
                style: TextStyle(color: style.textMuted),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_leave());
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: style.text,
                side: BorderSide(color: style.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                ),
              ),
              child: Text(strings.leaveMeetingOnly),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_closeRoomForEveryone());
              },
              style: FilledButton.styleFrom(
                backgroundColor: style.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                ),
              ),
              child: Text(strings.endMeetingForAll),
            ),
          ],
        ),
      );
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => RealtimeGlassDialog(
          icon: Icons.meeting_room_rounded,
          iconColor: style.danger,
          iconBackground: style.danger.withValues(alpha: 0.14),
          title: Text(strings.leaveMeeting),
          content: Text(strings.leaveRoomConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                strings.cancel,
                style: TextStyle(color: style.textMuted),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: style.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                ),
              ),
              child: Text(strings.leave),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _leave();
      }
    }
  }

  Future<void> _showLiveHostLeaveConfirmation() async {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => RealtimeGlassDialog(
        icon: Icons.stop_circle_rounded,
        iconColor: style.danger,
        iconBackground: style.danger.withValues(alpha: 0.14),
        title: Text(strings.endBroadcast),
        content: Text(strings.endBroadcastConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              strings.cancel,
              style: TextStyle(color: style.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: style.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.pillRadius,
                ),
              ),
            ),
            child: Text(strings.endBroadcast),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (widget.room.managementCapabilities.closeRoom.supported) {
        await _closeRoomForEveryone();
      } else {
        await _leave();
      }
    }
  }

  /// Legacy entry: the live comment pill now expands the input inline in the
  /// bottom dock instead of opening a second bottom sheet.
  void _showLiveChatInputSheet() {
    if (widget.chatSession == null) return;
    setState(() => _liveChatInputOpen = true);
    _controlRevision.value++;
  }

  void _hideLiveChatInput() {
    if (!_liveChatInputOpen) return;
    setState(() => _liveChatInputOpen = false);
    _controlRevision.value++;
  }

  void _showLiveGiftSheet() {
    final opener = widget.liveGiftPanelOpener;
    if (opener != null) {
      unawaited(opener(context));
      return;
    }
    final extraControls = widget.extraControlsBuilder?.call(context);
    if (extraControls != null && extraControls.isNotEmpty) {
      unawaited(
        showRealtimeGlassBottomSheet<void>(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: extraControls,
            ),
          ),
        ),
      );
    } else {
      final strings = RealtimeStrings.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.giftFeatureEnabled)));
    }
  }

  void _showMeetingMoreSheet(
    MediaSnapshot snapshot,
    InteractiveMediaSession? interactive,
  ) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final caps = snapshot.capabilities;

    unawaited(
      showRealtimeGlassBottomSheet<void>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.more,
                style: TextStyle(
                  color: style.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (interactive != null && caps.canSwitchCamera)
                    _moreTile(
                      icon: Icons.cameraswitch_rounded,
                      label: strings.switchCamera,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(
                          _run(
                            () => interactive.switchCamera(
                              MediaCameraPosition.back,
                            ),
                          ),
                        );
                      },
                    ),
                  if (caps.canPublishVideo &&
                      _backgroundEffects.backgroundCapabilities.isSupported)
                    _moreTile(
                      icon: Icons.blur_on_rounded,
                      label: strings.virtualBackground,
                      isActive: _backgroundEffects.backgroundEffect.enabled,
                      onTap: () {
                        Navigator.pop(ctx);
                        unawaited(_openBackgroundEffects());
                      },
                    ),
                  if (widget.config.showRtcDataMessages && caps.canSendData)
                    _moreTile(
                      icon: Icons.data_object_rounded,
                      label: strings.rtcData,
                      isActive: _rtcDataOpen,
                      onTap: () {
                        Navigator.pop(ctx);
                        _updateRoom(() => _rtcDataOpen = !_rtcDataOpen);
                      },
                    ),
                  _moreTile(
                    icon: Icons.copy_rounded,
                    label: strings.copyMeetingCode,
                    onTap: () {
                      Navigator.pop(ctx);
                      _copyCode();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final style = RealtimeStyle.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? style.primarySubtle : style.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? style.primaryBorder : style.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? style.primary : style.text, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? style.primary : style.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaSnapshot>(
    key: ValueKey(widget.room),
    stream: session.snapshots,
    initialData: session.snapshot,
    builder: (context, snap) {
      final value = snap.data ?? session.snapshot;
      if (value.state == MediaSessionState.connected &&
          widget.config.initialMediaSettings != null &&
          !_initialSettingsApplied) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_applyInitialSettings());
        });
      }

      if (isLive) {
        return LayoutBuilder(
          builder: (context, constraints) => _liveLayout(value, constraints),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) => _meetingLayout(value, constraints),
      );
    },
  );

  Widget _sidePanel(MediaSnapshot value) => RoomRegion(
    revision: _chatRevision,
    builder: (_) => _buildSidePanel(value),
  );

  Widget _buildSidePanel(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    final chatAvailable = widget.config.showChat && widget.chatSession != null;
    return Column(
      children: [
        RealtimeGlassSurface(
          radius: RealtimeUiTokens.controlRadius,
          opacity: .96,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _panelTab(
                  label: strings.participants,
                  active: _participantsOpen,
                  onPressed: _openParticipants,
                  badge: value.participants.length,
                ),
              ),
              if (chatAvailable) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: _panelTab(
                    label: strings.chat,
                    active: _chatOpen,
                    onPressed: _toggleChat,
                    badge: _unreadChatCount,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              RealtimeGlassIconButton(
                tooltip: strings.close,
                icon: Icons.close_rounded,
                size: 40,
                radius: RealtimeUiTokens.compactRadius,
                onPressed: () => setState(() {
                  _chatOpen = false;
                  _participantsOpen = false;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _participantsOpen || !chatAvailable
              ? _participantsList(value)
              : _productChat(widget.chatSession!, showHeader: false),
        ),
      ],
    );
  }

  Widget _panelTab({
    required String label,
    required bool active,
    required VoidCallback onPressed,
    int badge = 0,
  }) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: active ? Colors.white : RealtimeUiTokens.textMuted,
      backgroundColor: active ? RealtimeUiTokens.primary : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (badge > 0) ...[
          const SizedBox(width: 5),
          Text('$badge', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ],
    ),
  );

  Widget _participantsList(MediaSnapshot value) => RoomMembersPanel(
    presentation: _membersPresentation,
    room: widget.room,
    snapshot: value,
    chatSession: widget.chatSession,
    chatModeration: widget.chatModeration,
    onCloseRoom: _closeRoomForEveryone,
  );
  void _openParticipants() {
    final opening = !_participantsOpen;
    _updateRoom(() {
      _participantsOpen = opening;
      _chatOpen = false;
    });
    if (opening) unawaited(_membersPresentation.refresh());
  }

  Future<void> _closeRoomForEveryone() async {
    try {
      await widget.room.closeRoom();
    } catch (error) {
      if (mounted) _updateRoom(() => _error = error.toString());
      return;
    }
    if (!mounted) return;
    await widget.chatSession?.dispose();
    await widget.room.dispose();
    if (!mounted) return;
    widget.onLeave?.call();
    if (widget.onLeave == null && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _floatingHeartsOverlay() => Positioned.fill(
    child: IgnorePointer(
      child: Stack(
        children: _floatingHearts
            .map(
              (heart) =>
                  LiveReactionParticle(key: ValueKey(heart.id), heart: heart),
            )
            .toList(),
      ),
    ),
  );

  Widget _mediaStage(MediaSnapshot value) {
    final key = <Object?>[
      _layoutMode,
      _cleanScreen,
      value.state,
      value.localVideoEnabled,
      value.localMuted,
      value.contentShareTrack,
      value.contentShareTrack?.aspectRatio,
      widget.screenShareOverlayBuilder,
      ...value.participants,
    ];
    // RTC chat and statistics share the media snapshot stream. Reuse the video
    // subtree until its actual inputs change; retain no historical messages.
    if (_cachedMediaStage != null && listEquals(key, _mediaStageKey)) {
      return _cachedMediaStage!;
    }
    _mediaStageKey = key;
    return _cachedMediaStage = _buildMediaStage(value);
  }

  Widget _buildMediaStage(MediaSnapshot value) => ColoredBox(
    color: RealtimeStyle.of(context).background,
    child: isLive
        ? MediaLiveVideoStage(
            snapshot: value,
            role: widget.room.role,
            participantId: widget.room.participantId,
            roomCode: widget.room.roomCode,
            renderer: widget.renderer,
            participantBuilder: widget.participantBuilder,
          )
        : MediaMeetingVideoStage(
            key: ValueKey(widget.room),
            snapshot: value,
            renderer: widget.renderer,
            layoutMode: _layoutMode,
            participantBuilder: widget.participantBuilder,
            screenShareOverlayBuilder: widget.screenShareOverlayBuilder,
            contentStageBuilder: widget.contentStageBuilder,
            hasContentControls:
                widget.contentControlsBuilder?.call(context) != null,
            waiting: MediaRoomWaitingView(
              roomCode: widget.room.roomCode,
              copied: _copied,
              onCopy: _copyCode,
            ),
          ),
  );

  Widget _providerBadge(String id) {
    final presentation = mediaProviderPresentation(id);
    return RealtimePill(
      label: presentation.label,
      icon: Icons.hub_outlined,
      foreground: presentation.foreground,
      background: presentation.background,
      borderColor: presentation.border,
    );
  }

  Widget _errorView() {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: RealtimeUiTokens.controlRadius,
      fillColor: style.dangerSubtle,
      borderColor: style.isDark
          ? const Color(0xFF7F1D1D)
          : const Color(0xFFFECDD3),
      opacity: .92,
      shadow: false,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: style.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 12.5,
                color: style.isDark
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: style.isDark
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFB91C1C),
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _connectionBanner(MediaSessionState state) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final reconnecting = state == MediaSessionState.reconnecting;
    final ended = state == MediaSessionState.ended;
    final color = reconnecting ? style.warning : style.danger;
    final text = reconnecting
        ? strings.reconnectingDetail
        : ended
        ? strings.ended
        : strings.connectionFailed;
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: RealtimeUiTokens.controlRadius,
      fillColor: reconnecting ? style.warningSubtle : style.dangerSubtle,
      borderColor: color.withValues(alpha: .28),
      opacity: .96,
      shadow: false,
      child: Row(
        children: [
          Icon(
            reconnecting ? Icons.sync_rounded : Icons.error_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (!reconnecting)
            TextButton(
              onPressed: _leave,
              child: Text(
                strings.leave,
                style: TextStyle(color: style.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _productChat(ChatSession chat, {bool showHeader = true}) =>
      RoomChatPanel(
        controller: _chatPresentation,
        events: _chatEvents,
        chat: chat,
        participantId: widget.room.participantId,
        onClose: _toggleChat,
        showHeader: showHeader,
      );
  bool _isOwnChatMessage(ChatSession chat, ChatMessage message) =>
      isOwnRoomChatMessage(chat, message, widget.room.participantId);
  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      _participantsOpen = false;
      if (_chatOpen) {
        _chatEvents.markRead();
        _chatPresentation.opened();
      }
    });
  }

  Widget _rtcData() => RoomRtcDataPanel(
    key: ValueKey(widget.room),
    session: session,
    onError: (message) {
      if (mounted) setState(() => _error = message);
    },
  );

  Future<void> _openBackgroundEffects() async {
    var effect = _backgroundEffects.backgroundEffect;
    var busy = false;
    String? errorMessage;
    await showRealtimeGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BackgroundEffectSelector(
                capabilities: _backgroundEffects.backgroundCapabilities,
                effect: effect,
                imageBytes: widget.config.backgroundImageBytes,
                imagePresets: widget.config.backgroundImagePresets,
                busy: busy,
                onChanged: (next) async {
                  updateSheet(() {
                    busy = true;
                    errorMessage = null;
                  });
                  try {
                    await _backgroundEffects.setBackgroundEffect(next);
                    effect = next;
                    if (mounted) setState(() => _error = null);
                  } catch (error) {
                    errorMessage = error.toString();
                  } finally {
                    if (sheetContext.mounted) {
                      updateSheet(() => busy = false);
                    }
                  }
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InteractiveMediaSession? get _interactive =>
      session is InteractiveMediaSession
      ? session as InteractiveMediaSession
      : null;
  Widget? _banner(MediaSnapshot snapshot) => switch (snapshot.state) {
    MediaSessionState.reconnecting ||
    MediaSessionState.failed ||
    MediaSessionState.ended => _connectionBanner(snapshot.state),
    _ => null,
  };
  Widget _meetingLayout(
    MediaSnapshot value,
    BoxConstraints constraints,
  ) => MeetingRoomViewLayout(
    constraints: constraints,
    panelOpen: _chatOpen || _participantsOpen,
    participantsOpen: _participantsOpen,
    topBar: MeetingRoomHeader(
      snapshot: value,
      compact: constraints.maxWidth < 520,
      roomCode: widget.room.roomCode,
      copied: _copied,
      onCopy: _copyCode,
      providerBadge: widget.config.showProvider
          ? _providerBadge(widget.room.providerId)
          : null,
      layoutMode: _layoutMode,
      onLayoutMode: setLayoutMode,
      hasContentControls: widget.contentControlsBuilder?.call(context) != null,
      onLeave: () => observeDetached(_showMeetingLeaveConfirmation()),
    ),
    header: widget.header,
    connectionBanner: _banner(value),
    errorBanner: RoomRegion(
      revision: _chatRevision,
      builder: (_) => _error == null ? const SizedBox.shrink() : _errorView(),
    ),
    stage: _mediaStage(value),
    sidePanel: _sidePanel(value),
    rtcData: _rtcDataOpen ? _rtcData() : null,
    dock: RoomRegion(
      revision: _controlRevision,
      builder: (_) => MeetingRoomDock(
        snapshot: value,
        compact: constraints.maxWidth < 520,
        interactive: _interactive,
        canEnableMicrophone: widget.canEnableMicrophone,
        runAction: _run,
        contentControls: widget.contentControlsBuilder?.call(context),
        extraControls: widget.extraControlsBuilder?.call(context) ?? const [],
        participantsOpen: _participantsOpen,
        onParticipants: _openParticipants,
        showChat: widget.config.showChat && widget.chatSession != null,
        chatOpen: _chatOpen,
        unreadChatCount: _unreadChatCount,
        onChat: _toggleChat,
        onMore: () => _showMeetingMoreSheet(value, _interactive),
        onLeave: () => observeDetached(_showMeetingLeaveConfirmation()),
      ),
    ),
  );
  Widget _liveLayout(MediaSnapshot value, BoxConstraints constraints) =>
      LiveRoomViewLayout(
        constraints: constraints,
        cleanScreen: _cleanScreen,
        onCleanScreen: _toggleCleanScreen,
        onLike: _sendLike,
        stage: _mediaStage(value),
        hearts: RoomRegion(
          revision: _likeRevision,
          builder: (_) => Stack(children: [_floatingHeartsOverlay()]),
        ),
        topBar: LiveRoomHeader(
          snapshot: value,
          isHost: widget.room.role == MediaRole.host,
          roomCode: widget.room.roomCode,
          onCleanScreen: _toggleCleanScreen,
          onLeave: () => observeDetached(
            widget.room.role == MediaRole.host
                ? _showLiveHostLeaveConfirmation()
                : _leave(),
          ),
        ),
        header: widget.header,
        connectionBanner: _banner(value),
        danmaku: LiveRoomDanmaku(
          chat: widget.chatSession,
          messages: _chatEvents.danmaku,
          participantId: widget.room.participantId,
          isHost: widget.room.role == MediaRole.host,
        ),
        dock: RoomRegion(
          revision: _controlRevision,
          builder: (_) => LiveRoomDock(
            snapshot: value,
            isHost: widget.room.role == MediaRole.host,
            interactive: _interactive,
            chatSession: widget.chatSession,
            inputOpen: _liveChatInputOpen,
            chatController: _chatPresentation,
            onOpenInput: _showLiveChatInputSheet,
            onCloseInput: _hideLiveChatInput,
            runAction: _run,
            backgroundCapabilities: _backgroundEffects.backgroundCapabilities,
            backgroundEffect: _backgroundEffects.backgroundEffect,
            onBackground: () => observeDetached(_openBackgroundEffects()),
            showGift:
                widget.liveGiftPanelOpener != null ||
                widget.extraControlsBuilder != null,
            onGift: _showLiveGiftSheet,
            showLikes: widget.liveLikes != null,
            likeCount: _likeCount,
            onLike: _sendLike,
          ),
        ),
      );
}
