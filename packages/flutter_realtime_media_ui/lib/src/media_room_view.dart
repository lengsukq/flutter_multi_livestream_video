export 'media_participant_tile.dart' show MediaParticipantTile;
import 'room_members_controller.dart';
import 'room_chat_events_controller.dart';
import 'room_auxiliary_subscriptions.dart';
import 'room_rtc_data_panel.dart';
import 'initial_media_settings_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals, ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'live_likes_controller.dart';
import 'live_reactions_controller.dart';
import 'live_reaction_particle.dart';
import 'media_participant_tile.dart';
import 'media_room_layout_host.dart';
import 'meeting_room_layout.dart';
import 'live_room_layout.dart';
import 'room_regions.dart';
import 'background_effect_selector.dart';
import 'media_background_image_preset.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

part 'room_members_panel.dart';
part 'room_chat_panel.dart';
part 'room_controls.dart';
part 'legacy_room_media_stage.dart';

typedef MediaParticipantBuilder =
    Widget Function(
      BuildContext context,
      MediaParticipant participant,
      MediaTrackRenderer renderer,
    );

/// Layout modes supported in the room view.
enum MediaRoomLayoutMode { grid, speaker, presentation }

class MediaRoomViewConfig {
  const MediaRoomViewConfig({
    this.showProvider = false,
    this.showChat = true,
    this.showRtcDataMessages = false,
    this.confirmBeforeLeave = true,
    this.initialMediaSettings,
    this.backgroundImageBytes,
    this.backgroundImagePresets = const [],
    this.roomMode,
  });
  final bool showProvider;
  final bool showChat;
  final bool showRtcDataMessages;
  final bool confirmBeforeLeave;
  final MediaLocalPreviewSettings? initialMediaSettings;
  final Uint8List? backgroundImageBytes;
  final List<MediaBackgroundImagePreset> backgroundImagePresets;

  /// Optional explicitly configured room mode.
  /// When not provided, [MediaRoomView] deduces meeting vs live from the
  /// participant role and attached interactions.
  final MediaRoomMode? roomMode;
}

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

class _MediaRoomViewState extends State<MediaRoomView>
    with _LegacyRoomMediaStage
    implements MediaRoomLayoutHost {
  final _message = TextEditingController();
  final _liveChatInput = TextEditingController();
  final _liveChatInputFocus = FocusNode();
  final _chatScroll = ScrollController();
  final _auxiliarySubscriptions = RoomAuxiliarySubscriptions();
  Widget? _cachedMediaStage;
  List<Object?> _mediaStageKey = [];
  final _memberRevision = ValueNotifier<int>(0);
  final _controlRevision = ValueNotifier<int>(0);
  final _liveReactions = LiveReactionsController();
  ValueNotifier<int> get _likeRevision => _liveReactions.revision;
  final _chatEvents = RoomChatEventsController();
  final _chatRevision = ValueNotifier<int>(0);
  final _members = RoomMembersController();
  final _initialSettings = InitialMediaSettingsController();
  final Set<String> _visibleChatIds = {};
  bool _chatTimelineInitialized = false;
  bool _hasNewChatMessages = false;
  Timer? _copyTimer;
  int get _unreadChatCount => _chatEvents.unread;
  bool _chatOpen = false;
  bool _participantsOpen = false;
  bool _chatSending = false;
  bool _rtcDataOpen = false;
  bool _liveChatInputOpen = false;
  bool _liveChatSending = false;
  bool _copied = false;
  bool _initialSettingsApplied = false;
  @override
  String? _focusedParticipantId;
  String? _error;
  List<_ManagedRoomMember>? _roomMembers;
  Object? _roomMembersError;
  bool _loadingRoomMembers = false;
  @override
  MediaRoomLayoutMode _layoutMode = MediaRoomLayoutMode.grid;
  bool _cleanScreen = false;
  int get _likeCount => _liveReactions.totalLikes;
  List<LiveReactionHeart> get _floatingHearts => _liveReactions.hearts;
  bool _mutingAll = false;
  final Map<MediaParticipant, Object> _muteFailures = {};
  @override
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

  Future<void> _muteAllParticipants({bool retry = false}) async {
    if (_mutingAll) return;
    final strings = RealtimeStrings.of(context);
    final targetRoom = widget.room;
    final targets = retry
        ? _muteFailures.keys.toList()
        : session.snapshot.participants.where((p) => !p.isLocal).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.noMuteTargets)));
      return;
    }
    _updateMembers(() => _mutingAll = true);
    if (!retry) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => RealtimeGlassDialog(
          icon: Icons.volume_off_rounded,
          title: Text(strings.muteAll),
          content: Text(strings.muteAllConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.muteAll),
            ),
          ],
        ),
      );
      if (!mounted || targetRoom != widget.room) return;
      if (confirmed != true) {
        _updateMembers(() => _mutingAll = false);
        return;
      }
    }
    final result = await _members.mute(
      targetRoom,
      targets,
      isCurrent: () => mounted && targetRoom == widget.room,
    );
    if (!result.completed) return;
    final failures = result.failures;
    _updateMembers(() {
      _mutingAll = false;
      _muteFailures
        ..clear()
        ..addAll(failures);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures.isEmpty
              ? strings.muteAllSuccess
              : strings.muteSummary(
                  targets.length - failures.length,
                  failures.length,
                ),
        ),
      ),
    );
    await _refreshRoomMembers();
  }

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.room != widget.room) {
      _initialSettingsApplied = false;
      _roomMembers = null;
      _roomMembersError = null;
      _muteFailures.clear();
      _mutingAll = false;
      _loadingRoomMembers = false;
      _focusedParticipantId = null;
      _message.clear();
      _liveChatInput.clear();
      _liveChatInputOpen = false;
      _liveChatSending = false;
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
    _visibleChatIds.clear();
    _chatTimelineInitialized = false;
    _hasNewChatMessages = false;
    _chatSending = false;
  }

  void _updateRoom(VoidCallback update) => setState(update);
  void _updateChat(VoidCallback update) {
    update();
    _chatRevision.value++;
  }

  void _updateMembers(VoidCallback update) {
    update();
    _memberRevision.value++;
  }

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

  void _openParticipants() {
    final opening = !_participantsOpen;
    setState(() {
      _participantsOpen = !_participantsOpen;
      _chatOpen = false;
    });
    if (opening) unawaited(_refreshRoomMembers());
  }

  Future<void> _refreshRoomMembers() async {
    if (_loadingRoomMembers) return;
    final requestedRoom = widget.room;
    _updateMembers(() {
      _loadingRoomMembers = true;
      _roomMembersError = null;
    });
    final mediaCapabilities = widget.room.managementCapabilities;
    final chatModeration = widget.chatModeration;
    final chatCapabilities = chatModeration is ChatModerationCapabilitySource
        ? (chatModeration as ChatModerationCapabilitySource)
              .moderationCapabilities
        : const ChatManagementCapabilities();
    List<MediaRoomParticipantSummary> mediaParticipants = const [];
    List<ChatMember> chatMembers = const [];
    final loadErrors = <Object>[];
    if (mediaCapabilities.listParticipants.supported) {
      try {
        mediaParticipants = await widget.room.listParticipants();
      } catch (error) {
        loadErrors.add(error);
      }
    }
    if (chatModeration != null && chatCapabilities.listMembers.supported) {
      try {
        chatMembers = await chatModeration.listMembers();
      } catch (error) {
        loadErrors.add(error);
      }
    }
    if (!mounted || requestedRoom != widget.room) return;
    _updateMembers(() {
      _roomMembers = _mergeManagedMembers(
        mediaParticipants,
        chatMembers,
        localMediaParticipantId: widget.room.participantId,
        localChatUserId: widget.chatSession is ChatSessionIdentity
            ? (widget.chatSession as ChatSessionIdentity).localUserId
            : null,
      );
      _roomMembersError = loadErrors.isEmpty ? null : loadErrors.first;
      _loadingRoomMembers = false;
    });
  }

  Future<void> _closeChatRoomForEveryone() async {
    final moderation = widget.chatModeration;
    if (moderation == null) return;
    await _run(moderation.closeRoom);
  }

  Future<void> _closeRoomForEveryone() async {
    try {
      await widget.room.closeRoom();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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

  @override
  void dispose() {
    _liveReactions.totalsRevision.removeListener(_onLikeTotalChanged);
    _auxiliarySubscriptions.dispose();
    _copyTimer?.cancel();
    _memberRevision.dispose();
    _controlRevision.dispose();
    _liveReactions.dispose();
    _chatEvents.dispose();
    _chatRevision.dispose();
    _message.dispose();
    _liveChatInput.dispose();
    _liveChatInputFocus.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _leave() async {
    var leave = true;
    if (widget.config.confirmBeforeLeave) {
      final strings = RealtimeStrings.of(context);
      leave =
          await showDialog<bool>(
            context: context,
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

  @override
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
        builder: (ctx) => RealtimeGlassDialog(
          icon: Icons.meeting_room_rounded,
          iconColor: style.danger,
          iconBackground: style.danger.withValues(alpha: 0.14),
          title: Text(strings.leaveMeeting),
          content: Text(strings.endMeetingForAllDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                strings.cancel,
                style: TextStyle(color: style.textMuted),
              ),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
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
                Navigator.pop(ctx);
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
        builder: (ctx) => RealtimeGlassDialog(
          icon: Icons.meeting_room_rounded,
          iconColor: style.danger,
          iconBackground: style.danger.withValues(alpha: 0.14),
          title: Text(strings.leaveMeeting),
          content: Text(strings.leaveRoomConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                strings.cancel,
                style: TextStyle(color: style.textMuted),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
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
      builder: (ctx) => RealtimeGlassDialog(
        icon: Icons.stop_circle_rounded,
        iconColor: style.danger,
        iconBackground: style.danger.withValues(alpha: 0.14),
        title: Text(strings.endBroadcast),
        content: Text(strings.endBroadcastConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              strings.cancel,
              style: TextStyle(color: style.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _liveChatInputOpen) _liveChatInputFocus.requestFocus();
    });
  }

  void _hideLiveChatInput() {
    if (!_liveChatInputOpen) return;
    setState(() => _liveChatInputOpen = false);
    _controlRevision.value++;
    _liveChatInputFocus.unfocus();
  }

  Future<void> _sendLiveChat() async {
    final chat = widget.chatSession;
    if (chat == null || _liveChatSending) return;
    final trimmed = _liveChatInput.text.trim();
    if (trimmed.isEmpty) return;
    setState(() => _liveChatSending = true);
    try {
      await chat.sendMessage(trimmed);
      if (!mounted || chat != widget.chatSession) return;
      _liveChatInput.clear();
      _hideLiveChatInput();
    } on Object catch (error) {
      if (mounted && chat == widget.chatSession) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && chat == widget.chatSession) {
        setState(() => _liveChatSending = false);
      }
    }
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
      ).showSnackBar(SnackBar(content: Text('${strings.sendGift}功能已开启')));
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
          builder: (context, constraints) => LiveRoomViewLayout(
            host: this,
            snapshot: value,
            constraints: constraints,
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) => MeetingRoomViewLayout(
          host: this,
          snapshot: value,
          constraints: constraints,
        ),
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

  Widget _participantsList(MediaSnapshot value) =>
      _RoomMembersPanel(host: this, snapshot: value);

  Future<void> _runMemberManagement(Future<void> Function() action) async {
    final room = widget.room;
    try {
      await action();
      if (mounted && room == widget.room) await _refreshRoomMembers();
    } on Object catch (error) {
      if (mounted && room == widget.room) {
        _updateMembers(() => _roomMembersError = error);
      }
    }
  }

  Widget _memberActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool danger = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger
            ? RealtimeUiTokens.danger
            : (isDark ? Colors.white : RealtimeUiTokens.text),
        side: BorderSide(
          color: danger
              ? RealtimeUiTokens.dangerBorder
              : (isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : RealtimeUiTokens.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
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
      _focusedParticipantId,
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

  Widget _buildMediaStage(MediaSnapshot value) {
    final style = RealtimeStyle.of(context);
    final isLive = this.isLive;
    if (isLive) {
      return ColoredBox(color: style.background, child: _buildLiveStage(value));
    }
    final customContent = widget.contentStageBuilder?.call(context, value);
    final stageContent = customContent != null
        ? Column(
            children: [
              Expanded(child: customContent),
              if (value.participants.isNotEmpty)
                SizedBox(height: 116, child: _participantStrip(value)),
            ],
          )
        : widget.contentStageBuilder != null &&
              widget.contentControlsBuilder?.call(context) != null
        ? (value.participants.isEmpty ? _waiting() : _grid(value))
        : value.contentShareTrack == null &&
              _layoutMode != MediaRoomLayoutMode.presentation
        ? value.participants.isEmpty
              ? _waiting()
              : _grid(value)
        : Column(
            children: [
              Expanded(child: _screenShare(value)),
              if (value.participants.isNotEmpty)
                SizedBox(height: 116, child: _participantStrip(value)),
            ],
          );

    return ColoredBox(color: style.background, child: stageContent);
  }

  Widget _buildLiveStage(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isLocalHost = widget.room.role == MediaRole.host;

    // In livestream / broadcast, resolve the single host participant.
    final MediaParticipant? hostParticipant = isLocalHost
        ? (value.participants.where((p) => p.isLocal).firstOrNull ??
              (value.localParticipantId != null
                  ? value.participants
                        .where((p) => p.id == value.localParticipantId)
                        .firstOrNull
                  : null) ??
              MediaParticipant(
                id: widget.room.participantId,
                displayName: widget.room.participantId,
                isLocal: true,
                isVideoEnabled: value.localVideoEnabled,
              ))
        : (value.participants
                  .where(
                    (p) =>
                        !p.isLocal &&
                        (p.isVideoEnabled || p.videoTrack != null),
                  )
                  .firstOrNull ??
              value.participants.where((p) => !p.isLocal).firstOrNull ??
              value.participants.firstOrNull);

    // If custom participant builder provided, honor it.
    if (widget.participantBuilder != null && hostParticipant != null) {
      return widget.participantBuilder!(
        context,
        hostParticipant,
        widget.renderer,
      );
    }

    if (hostParticipant == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RealtimeGlassSurface(
            radius: RealtimeUiTokens.cardRadius,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RoomWaitingPulse(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(
                      Icons.sensors_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.waitingForHost,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.room.roomCode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: style.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasVideo =
        hostParticipant.videoTrack != null &&
        (isLocalHost
            ? value.localVideoEnabled
            : hostParticipant.isVideoEnabled);

    if (hasVideo) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight > constraints.maxWidth;
          return Center(
            child: MediaTrackView(
              renderer: widget.renderer,
              track: hostParticipant.videoTrack,
              fit: isPortrait ? BoxFit.cover : BoxFit.contain,
              placeholder: _buildLiveHostOffCameraPlaceholder(
                hostParticipant,
                strings,
                style,
              ),
            ),
          );
        },
      );
    }

    return _buildLiveHostOffCameraPlaceholder(hostParticipant, strings, style);
  }

  Widget _buildLiveHostOffCameraPlaceholder(
    MediaParticipant host,
    RealtimeStrings strings,
    RealtimeStyle style,
  ) {
    final name = host.displayName.isEmpty ? host.id : host.displayName;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.sheetRadius,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: style.primarySubtle,
                child: Text(
                  name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: style.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: style.text,
                ),
              ),
              const SizedBox(height: 8),
              RealtimePill(
                label: strings.cameraOff,
                icon: Icons.videocam_off_rounded,
                foreground: style.danger,
                background: style.dangerSubtle,
                borderColor: style.isDark
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFFFECDD3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _participantStrip(MediaSnapshot value) => ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    scrollDirection: Axis.horizontal,
    itemCount: value.participants.length,
    separatorBuilder: (_, _) => const SizedBox(width: 8),
    itemBuilder: (context, index) => SizedBox(
      width: 144,
      child: _buildParticipantWidget(
        value.participants[index],
        isFocused: false,
        canFocus: true,
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

  Widget _waiting() {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.sheetRadius,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          opacity: 0.84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RoomWaitingPulse(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Icon(
                    Icons.wifi_tethering_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.onlyOneHere,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: style.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.shareRoomCode,
                textAlign: TextAlign.center,
                style: TextStyle(color: style.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 18),
              RealtimeGlassButton(
                onPressed: _copyCode,
                icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                child: Text(
                  _copied
                      ? strings.copied
                      : strings.copyRoom(widget.room.roomCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productChat(ChatSession chat, {bool showHeader = true}) =>
      _RoomChatPanel(host: this, chat: chat, showHeader: showHeader);

  bool _isOwnChatMessage(ChatSession chat, ChatMessage message) {
    if (chat is ChatSessionIdentity) {
      final identity = chat as ChatSessionIdentity;
      final localUserId = identity.localUserId.trim();
      if (localUserId.isNotEmpty && message.userId == localUserId) return true;
      final localParticipantId = identity.localParticipantId.trim();
      if (localParticipantId.isNotEmpty &&
          message.attributes['participantId'] == localParticipantId) {
        return true;
      }
    }
    if (message.attributes['local'] == 'true') return true;
    return message.userId == widget.room.participantId;
  }

  String _formatChatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _syncChatScroll(List<ChatMessage> messages) {
    final first = !_chatTimelineInitialized;
    final added = messages.any((m) => !_visibleChatIds.contains(m.id));
    _chatTimelineInitialized = true;
    _visibleChatIds
      ..clear()
      ..addAll(messages.map((m) => m.id));
    if (!first && !added) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScroll.hasClients) return;
      final nearLatest = first || _chatScroll.position.pixels <= 72;
      if (nearLatest) {
        _chatScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _hasNewChatMessages = true;
        _chatRevision.value++;
      }
    });
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      _participantsOpen = false;
      if (_chatOpen) {
        _chatEvents.markRead();
        _hasNewChatMessages = false;
      }
    });
    if (_chatOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScroll.hasClients) _chatScroll.jumpTo(0);
      });
    }
  }

  Future<void> _sendChat(ChatSession chat) async {
    final text = _message.text.trim();
    if (text.isEmpty || _chatSending) return;
    _updateChat(() => _chatSending = true);
    try {
      await chat.sendMessage(text);
      if (!mounted || chat != widget.chatSession) return;
      _message.clear();
      _updateChat(() => _error = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && chat == widget.chatSession && _chatScroll.hasClients) {
          _chatScroll.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } on Object catch (error) {
      if (mounted && chat == widget.chatSession) {
        _updateChat(() => _error = error.toString());
      }
    } finally {
      if (mounted && chat == widget.chatSession) {
        _updateChat(() => _chatSending = false);
      }
    }
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

  // Presentation facade: no Meeting/Live component can access private State.
  @override
  MediaRoomView get view => widget;
  @override
  MediaBackgroundEffectsController get backgroundEffects => _backgroundEffects;
  @override
  bool get chatOpen => _chatOpen;
  @override
  bool get participantsOpen => _participantsOpen;
  @override
  bool get rtcDataOpen => _rtcDataOpen;
  @override
  bool get copied => _copied;
  @override
  bool get cleanScreen => _cleanScreen;
  @override
  int get unreadChatCount => _unreadChatCount;
  @override
  int get likeCount => _likeCount;
  @override
  Object? get error => _error;
  @override
  MediaRoomLayoutMode get layoutMode => _layoutMode;
  @override
  ValueNotifier<int> get chatRevision => _chatRevision;
  @override
  ValueListenable<List<ChatMessage>> get chatMessages => _chatEvents.danmaku;
  @override
  ValueNotifier<int> get likeRevision => _likeRevision;
  @override
  ValueNotifier<int> get controlRevision => _controlRevision;
  @override
  bool get liveChatInputOpen => _liveChatInputOpen;
  @override
  Widget connectionBanner(MediaSessionState state) => _connectionBanner(state);
  @override
  Widget errorView() => _errorView();
  @override
  Widget rtcData() => _rtcData();
  @override
  Widget mediaStage(MediaSnapshot value) => _mediaStage(value);
  @override
  Widget sidePanel(MediaSnapshot value) => _sidePanel(value);
  @override
  Widget providerBadge(String id) => _providerBadge(id);
  @override
  Widget floatingHeartsOverlay() => _floatingHeartsOverlay();
  @override
  void copyCode() => _copyCode();
  @override
  void openParticipants() => _openParticipants();
  @override
  void toggleChat() => _toggleChat();
  @override
  void toggleCleanScreen() => _toggleCleanScreen();
  @override
  void sendLike() => _sendLike();
  @override
  void showLiveChatInputSheet() => _showLiveChatInputSheet();
  @override
  void hideLiveChatInput() => _hideLiveChatInput();
  @override
  Future<void> sendLiveChat() => _sendLiveChat();
  @override
  void showLiveGiftSheet() => _showLiveGiftSheet();
  @override
  void showMeetingMoreSheet(
    MediaSnapshot value,
    InteractiveMediaSession? interactive,
  ) => _showMeetingMoreSheet(value, interactive);
  @override
  Future<void> showMeetingLeaveConfirmation() =>
      _showMeetingLeaveConfirmation();
  @override
  Future<void> showLiveHostLeaveConfirmation() =>
      _showLiveHostLeaveConfirmation();
  @override
  Future<void> leave() => _leave();
  @override
  Future<void> openBackgroundEffects() => _openBackgroundEffects();
  @override
  Future<void> runAction(Future<void> Function() action) => _run(action);
}
