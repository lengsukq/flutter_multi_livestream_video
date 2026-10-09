import 'room_members_controller.dart';
import 'chat_timeline_controller.dart';
import 'initial_media_settings_controller.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'live_likes_controller.dart';
import 'room_regions.dart';
import 'background_effect_selector.dart';
import 'media_background_image_preset.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

part 'room_members_panel.dart';
part 'room_chat_panel.dart';
part 'room_controls.dart';

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
  });
  final bool showProvider;
  final bool showChat;
  final bool showRtcDataMessages;
  final bool confirmBeforeLeave;
  final MediaLocalPreviewSettings? initialMediaSettings;
  final Uint8List? backgroundImageBytes;
  final List<MediaBackgroundImagePreset> backgroundImagePresets;
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
  @override
  State<MediaRoomView> createState() => _MediaRoomViewState();
}

class _MediaRoomViewState extends State<MediaRoomView> {
  final _message = TextEditingController();
  final _rtcDataMessage = TextEditingController();
  final _chatScroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _chatUnreadSub;
  StreamSubscription<int>? _likesSub;
  StreamSubscription<int>? _likeTotalsSub;
  StreamSubscription<Object?>? _micPermissionSub;
  StreamSubscription<Object?>? _contentSub;
  Widget? _cachedMediaStage;
  List<Object?> _mediaStageKey = [];
  final _memberRevision = ValueNotifier<int>(0);
  final _controlRevision = ValueNotifier<int>(0);
  final _likeRevision = ValueNotifier<int>(0);
  final _danmakuMessages = ValueNotifier<List<ChatMessage>>(const []);
  final _chatRevision = ValueNotifier<int>(0);
  final _timeline = ChatTimelineController();
  final _members = RoomMembersController();
  final _initialSettings = InitialMediaSettingsController();
  final Set<String> _visibleChatIds = {};
  bool _chatTimelineInitialized = false;
  bool _hasNewChatMessages = false;
  final Set<Timer> _heartTimers = {};
  Timer? _copyTimer;
  int _unreadChatCount = 0;
  bool _chatOpen = false;
  bool _participantsOpen = false;
  bool _chatSending = false;
  bool _rtcDataOpen = false;
  bool _copied = false;
  bool _initialSettingsApplied = false;
  String? _focusedParticipantId;
  String? _error;
  List<_ManagedRoomMember>? _roomMembers;
  Object? _roomMembersError;
  bool _loadingRoomMembers = false;
  MediaRoomLayoutMode _layoutMode = MediaRoomLayoutMode.grid;
  bool _cleanScreen = false;
  int _likeCount = 0;
  final List<_FloatingHeartItem> _floatingHearts = [];
  bool _mutingAll = false;
  final Map<MediaParticipant, Object> _muteFailures = {};
  MediaSession get session => widget.room.session;
  MediaBackgroundEffectsController get _backgroundEffects =>
      widget.backgroundEffects ?? widget.room;

  void _sendLike() {
    final likes = widget.liveLikes;
    if (likes == null) return;
    observeDetached(_run(likes.sendLike));
  }

  void _watchLikes() {
    observeDetached(_likesSub?.cancel());
    observeDetached(_likeTotalsSub?.cancel());
    for (final timer in _heartTimers) {
      timer.cancel();
    }
    _heartTimers.clear();
    _floatingHearts.clear();
    _likeRevision.value++;
    final likes = widget.liveLikes;
    _likeCount = likes?.totalLikes ?? 0;
    _controlRevision.value++;
    if (likes == null) return;
    _likesSub = likes.receivedLikes.listen((count) {
      if (!mounted || likes != widget.liveLikes) return;
      for (var index = 0; index < count.clamp(0, 5); index++) {
        _animateLike();
      }
    });
    _likeTotalsSub = likes.totals.listen((count) {
      if (!mounted || likes != widget.liveLikes) return;
      _likeCount = count;
      _controlRevision.value++;
    });
  }

  void _animateLike() {
    final random = math.Random();
    const hues = [
      Color(0xFFEF4444),
      Color(0xFFF43F5E),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
    ];
    final heart = _FloatingHeartItem(
      id: '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1000)}',
      color: hues[random.nextInt(hues.length)],
      startX: 0.65 + (random.nextDouble() * 0.25),
    );
    {
      _floatingHearts.add(heart);
    }
    _likeRevision.value++;
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 1600), () {
      _heartTimers.remove(timer);
      if (mounted) {
        _floatingHearts.removeWhere((h) => h.id == heart.id);
        _likeRevision.value++;
      }
    });
    _heartTimers.add(timer);
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
      _rtcDataMessage.clear();
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
    observeDetached(_contentSub?.cancel());
    _contentSub = widget.contentStageUpdates?.listen((_) {
      if (mounted) setState(() => _cachedMediaStage = null);
    });
  }

  void _watchMicPermission() {
    observeDetached(_micPermissionSub?.cancel());
    _micPermissionSub = widget.microphonePermissionUpdates?.listen((_) {
      if (!mounted) return;
      _controlRevision.value++;
      if (widget.canEnableMicrophone?.call() == false &&
          session is InteractiveMediaSession &&
          !session.snapshot.localMuted) {
        unawaited(
          _run(() => (session as InteractiveMediaSession).setMuted(true)),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedMediaStage = null;
  }

  void _watchUnreadChat() {
    observeDetached(_chatUnreadSub?.cancel());
    final chat = widget.chatSession;
    _danmakuMessages.value = List.unmodifiable(chat?.messages ?? const []);
    _timeline.seed(chat?.messages ?? const []);
    _unreadChatCount = 0;
    _visibleChatIds.clear();
    _chatTimelineInitialized = false;
    _hasNewChatMessages = false;
    _chatSending = false;
    if (chat == null) return;
    _chatUnreadSub = chat.messageSnapshots.listen((messages) {
      if (!mounted || chat != widget.chatSession) return;
      _danmakuMessages.value = List.unmodifiable(messages);
      final remoteCount = _timeline.accept(
        messages,
        (m) => _isOwnChatMessage(chat, m),
      );
      if (!_chatOpen && remoteCount > 0) {
        _unreadChatCount += remoteCount;
        _controlRevision.value++;
        _chatRevision.value++;
      }
    });
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
    observeDetached(_chatUnreadSub?.cancel());
    observeDetached(_likesSub?.cancel());
    observeDetached(_likeTotalsSub?.cancel());
    observeDetached(_micPermissionSub?.cancel());
    observeDetached(_contentSub?.cancel());
    _copyTimer?.cancel();
    for (final timer in _heartTimers) {
      timer.cancel();
    }
    _memberRevision.dispose();
    _controlRevision.dispose();
    _likeRevision.dispose();
    _danmakuMessages.dispose();
    _chatRevision.dispose();
    _message.dispose();
    _rtcDataMessage.dispose();
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
      final strings = RealtimeStrings.of(context);
      if (_cleanScreen && widget.room.role != MediaRole.participant) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _mediaStage(value),
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: RealtimePill(
                    label: strings.exitCleanScreen,
                    icon: Icons.fullscreen_exit_rounded,
                    foreground: Colors.white,
                    background: Colors.black.withValues(alpha: 0.65),
                    borderColor: Colors.white.withValues(alpha: 0.35),
                    onTap: _toggleCleanScreen,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: RealtimeAmbientBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1200;
                final medium = constraints.maxWidth >= 760;
                final compact = constraints.maxWidth < 520;
                return Column(
                  children: [
                    _topBar(value, compact: compact),
                    if (widget.header != null) widget.header!,
                    if (value.state == MediaSessionState.reconnecting ||
                        value.state == MediaSessionState.failed ||
                        value.state == MediaSessionState.ended)
                      _connectionBanner(value.state),
                    RoomRegion(
                      revision: _chatRevision,
                      builder: (_) => _error == null
                          ? const SizedBox.shrink()
                          : _errorView(),
                    ),
                    Expanded(
                      child: wide
                          ? _wideContent(value, constraints)
                          : medium
                          ? _mediumContent(value, constraints)
                          : _compactContent(value, constraints),
                    ),
                    if (_rtcDataOpen) _rtcData(),
                    _controls(value),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _wideContent(MediaSnapshot value, BoxConstraints constraints) {
    final panelOpen = _chatOpen || _participantsOpen;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _mediaStage(value)),
        if (panelOpen)
          SizedBox(
            key: ValueKey(
              _participantsOpen ? 'participants-panel-wide' : 'chat-panel-wide',
            ),
            width: 320,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset((1 - progress) * 16, 0),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: _sidePanel(value),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mediumContent(MediaSnapshot value, BoxConstraints constraints) =>
      Stack(
        fit: StackFit.expand,
        children: [
          _mediaStage(value),
          if (_chatOpen || _participantsOpen)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                key: ValueKey(
                  _participantsOpen
                      ? 'participants-panel-medium'
                      : 'chat-panel-medium',
                ),
                width: math.min(360, constraints.maxWidth * .56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                  child: _sidePanel(value),
                ),
              ),
            ),
        ],
      );

  Widget _compactContent(MediaSnapshot value, BoxConstraints constraints) {
    final maxChatHeight = math.max(140.0, constraints.maxHeight - 150);
    final desiredChatHeight = (constraints.maxHeight * .42).clamp(180.0, 380.0);
    final chatHeight = math.min(desiredChatHeight, maxChatHeight);
    return Column(
      children: [
        Expanded(child: _mediaStage(value)),
        if (_chatOpen || _participantsOpen)
          SizedBox(
            key: ValueKey(
              _participantsOpen
                  ? 'participants-panel-compact'
                  : 'chat-panel-compact',
            ),
            height: chatHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 14),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: _sidePanel(value),
              ),
            ),
          ),
      ],
    );
  }

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
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: danger
          ? RealtimeUiTokens.danger
          : RealtimeUiTokens.textMuted,
      side: BorderSide(
        color: danger ? RealtimeUiTokens.dangerBorder : RealtimeUiTokens.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 11)),
  );

  Widget _danmakuOverlay(List<ChatMessage> messages) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final recent = messages.reversed.take(4).toList().reversed.toList();
    final identity = widget.chatSession is ChatSessionIdentity
        ? widget.chatSession as ChatSessionIdentity
        : null;
    final myId = identity?.localUserId;
    return Positioned(
      left: 14,
      bottom: 14,
      width: 290,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: recent.map((m) {
            final own = m.userId == myId;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${m.displayName.isEmpty ? m.userId : m.displayName}: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: own
                            ? const Color(0xFF67E8F9)
                            : const Color(0xFFFDE047),
                      ),
                    ),
                    TextSpan(
                      text: m.message,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _floatingHeartsOverlay() => Positioned.fill(
    child: IgnorePointer(
      child: Stack(
        children: _floatingHearts
            .map(
              (heart) =>
                  _FloatingHeartParticle(key: ValueKey(heart.id), heart: heart),
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
    final isLive = widget.room.role != MediaRole.participant;
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

    return ColoredBox(
      color: isLive ? Colors.black : RealtimeUiTokens.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          stageContent,
          if (isLive && !_cleanScreen) ...[
            ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: _danmakuMessages,
              builder: (_, messages, _) => _danmakuOverlay(messages),
            ),
            Positioned.fill(
              child: RoomRegion(
                revision: _likeRevision,
                builder: (_) => Stack(children: [_floatingHeartsOverlay()]),
              ),
            ),
          ],
        ],
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

  Widget _topBar(MediaSnapshot value, {required bool compact}) {
    final strings = RealtimeStrings.of(context);
    final isLive = widget.room.role != MediaRole.participant;
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .86,
      child: Row(
        children: [
          RealtimeGlassIconButton(
            tooltip: strings.leave,
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: _leave,
            size: 44,
            radius: RealtimeUiTokens.compactRadius,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLive ? strings.live : strings.meeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: RealtimeUiTokens.text,
                  ),
                ),
                InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                strings.roomLabel(widget.room.roomCode),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: RealtimeUiTokens.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 13,
                              color: _copied
                                  ? RealtimeUiTokens.success
                                  : RealtimeUiTokens.textMuted,
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
          if (widget.config.showProvider && !compact) ...[
            const SizedBox(width: 8),
            _providerBadge(widget.room.providerId),
          ],
          if (widget.room.role == MediaRole.host && !compact) ...[
            const SizedBox(width: 8),
            RealtimePill(
              label: strings.hostBadge,
              icon: Icons.shield_outlined,
              foreground: const Color(0xFFD97706),
              background: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
            ),
          ],
          if (!isLive && !compact) ...[
            const SizedBox(width: 4),
            PopupMenuButton<MediaRoomLayoutMode>(
              tooltip: strings.layoutMode,
              icon: Icon(
                switch (_layoutMode) {
                  MediaRoomLayoutMode.grid => Icons.grid_view_rounded,
                  MediaRoomLayoutMode.speaker => Icons.person_pin_rounded,
                  MediaRoomLayoutMode.presentation =>
                    Icons.present_to_all_rounded,
                },
                size: 20,
                color: RealtimeUiTokens.text,
              ),
              onSelected: (mode) => setState(() => _layoutMode = mode),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: MediaRoomLayoutMode.grid,
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(strings.gridMode),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: MediaRoomLayoutMode.speaker,
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(strings.speakerMode),
                    ],
                  ),
                ),
                if (widget.contentControlsBuilder?.call(context) == null)
                  PopupMenuItem(
                    value: MediaRoomLayoutMode.presentation,
                    child: Row(
                      children: [
                        const Icon(Icons.present_to_all_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(strings.presentationMode),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(width: 8),
          RoomElapsedPill(key: ValueKey(widget.room)),
          const SizedBox(width: 4),
          Tooltip(
            message: _stateLabel(strings, value.state),
            child: Icon(
              Icons.circle,
              size: 9,
              color: switch (value.state) {
                MediaSessionState.connected => RealtimeUiTokens.success,
                MediaSessionState.reconnecting => RealtimeUiTokens.warning,
                MediaSessionState.failed ||
                MediaSessionState.ended => RealtimeUiTokens.danger,
                _ => RealtimeUiTokens.textMuted,
              },
            ),
          ),
          const SizedBox(width: 4),
          RealtimeGlassIconButton(
            tooltip: strings.participants,
            icon: Icons.people_outline_rounded,
            badgeCount: value.participants.length,
            active: _participantsOpen,
            size: 44,
            radius: RealtimeUiTokens.compactRadius,
            onPressed: _openParticipants,
          ),
        ],
      ),
    );
  }

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

  String _stateLabel(RealtimeStrings strings, MediaSessionState state) =>
      switch (state) {
        MediaSessionState.connected => strings.connected,
        MediaSessionState.reconnecting => strings.reconnecting,
        MediaSessionState.ended || MediaSessionState.disposed => strings.ended,
        _ => strings.connecting,
      };

  Widget _errorView() => RealtimeGlassSurface(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    radius: RealtimeUiTokens.controlRadius,
    fillColor: RealtimeUiTokens.dangerSubtle,
    borderColor: RealtimeUiTokens.dangerBorder,
    opacity: .92,
    shadow: false,
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: RealtimeUiTokens.danger,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _error = null),
          icon: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Color(0xFFB91C1C),
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  Widget _connectionBanner(MediaSessionState state) {
    final strings = RealtimeStrings.of(context);
    final reconnecting = state == MediaSessionState.reconnecting;
    final ended = state == MediaSessionState.ended;
    final color = reconnecting
        ? RealtimeUiTokens.warning
        : RealtimeUiTokens.danger;
    final text = reconnecting
        ? strings.reconnectingDetail
        : ended
        ? strings.ended
        : strings.connectionFailed;
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: RealtimeUiTokens.controlRadius,
      fillColor: reconnecting
          ? RealtimeUiTokens.warningSubtle
          : RealtimeUiTokens.dangerSubtle,
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
            TextButton(onPressed: _leave, child: Text(strings.leave)),
        ],
      ),
    );
  }

  Widget _waiting() {
    final strings = RealtimeStrings.of(context);
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
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: RealtimeUiTokens.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.shareRoomCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RealtimeUiTokens.textMuted,
                  fontSize: 13.5,
                ),
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

  Widget _grid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final participants = value.participants;
      final count = participants.length;
      final focused = count > 1 && _focusedParticipantId != null
          ? participants.where((p) => p.id == _focusedParticipantId).firstOrNull
          : null;
      final isSpeaker = _layoutMode == MediaRoomLayoutMode.speaker;
      final effectiveFocused =
          focused ??
          (isSpeaker && count > 1
              ? (participants.where((p) => p.isSpeaking).firstOrNull ??
                    participants.first)
              : null);

      if (effectiveFocused != null) {
        final others = participants
            .where((p) => p.id != effectiveFocused.id)
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: _buildParticipantWidget(
                  effectiveFocused,
                  isFocused: true,
                  canFocus: true,
                ),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: others.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _buildParticipantWidget(
                        others[index],
                        isFocused: false,
                        canFocus: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      final columns = constraints.maxWidth > 900
          ? (count <= 4 ? 2 : 3)
          : constraints.maxWidth > 600
          ? (count <= 2 ? 2 : 3)
          : (count == 1 ? 1 : 2);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: count == 1 ? 4 / 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return _buildParticipantWidget(
            participant,
            isFocused: false,
            canFocus: count > 1,
          );
        },
      );
    },
  );

  Widget _buildParticipantWidget(
    MediaParticipant participant, {
    required bool isFocused,
    required bool canFocus,
  }) {
    if (widget.participantBuilder != null) {
      return widget.participantBuilder!(context, participant, widget.renderer);
    }
    return MediaParticipantTile(
      participant: participant,
      renderer: widget.renderer,
      isFocused: isFocused,
      onTap: canFocus
          ? () => setState(() {
              _focusedParticipantId = _focusedParticipantId == participant.id
                  ? null
                  : participant.id;
            })
          : null,
    );
  }

  Widget _screenShare(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center, not expand: a contained screen share must keep its own
            // aspect ratio instead of being stretched or cropped, with the
            // stage background showing as letterbox bars.
            Center(
              child: MediaTrackView(
                renderer: widget.renderer,
                track: value.contentShareTrack,
                fit: BoxFit.contain,
              ),
            ),
            if (value.contentShareTrack != null &&
                widget.screenShareOverlayBuilder != null)
              Center(
                child: AspectRatio(
                  aspectRatio: value.contentShareTrack!.aspectRatio,
                  child: widget.screenShareOverlayBuilder!(
                    context,
                    value.contentShareTrack!,
                  ),
                ),
              ),
            Positioned(
              left: 10,
              top: 10,
              child: RealtimePill(
                label: strings.screenShare,
                icon: Icons.present_to_all_rounded,
                foreground: Colors.white,
                background: const Color(0xB3000000),
                borderColor: const Color(0x40FFFFFF),
              ),
            ),
          ],
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
        _unreadChatCount = 0;
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

  Widget _rtcData() {
    if (!session.capabilities.canSendData) return const SizedBox.shrink();
    final strings = RealtimeStrings.of(context);
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      radius: RealtimeUiTokens.controlRadius,
      opacity: .88,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: RealtimePill(
              label: strings.rtcData,
              foreground: RealtimeUiTokens.primary,
              background: RealtimeUiTokens.primarySubtle,
              borderColor: RealtimeUiTokens.primaryBorder,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _rtcDataMessage,
              decoration: InputDecoration(
                hintText: strings.debugDataPayload,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _sendRtcData(),
            ),
          ),
          IconButton(
            onPressed: _sendRtcData,
            icon: const Icon(
              Icons.send_rounded,
              color: RealtimeUiTokens.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _sendRtcData() {
    final text = _rtcDataMessage.text.trim();
    if (text.isEmpty) return;
    observeDetached(
      _run(
        () => session.sendData(
          text,
          options: const MediaSendOptions(topic: 'debug'),
        ),
      ).then((_) {
        if (mounted && _error == null) _rtcDataMessage.clear();
      }),
    );
  }

  Future<void> _openBackgroundEffects() async {
    var effect = _backgroundEffects.backgroundEffect;
    var busy = false;
    String? errorMessage;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(MediaSnapshot value) =>
      _RoomControls(host: this, snapshot: value);
}

class MediaParticipantTile extends StatelessWidget {
  const MediaParticipantTile({
    super.key,
    required this.participant,
    required this.renderer,
    this.isFocused = false,
    this.onTap,
  });
  final MediaParticipant participant;
  final MediaTrackRenderer renderer;
  final bool isFocused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final name = participant.displayName.isEmpty
        ? strings.participant
        : participant.displayName;
    final speaking = participant.isSpeaking;

    Widget tile = AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: RealtimeUiTokens.glassGradient(opacity: 0.90),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(
          color: speaking
              ? const Color(0xFF10B981)
              : isFocused
              ? RealtimeUiTokens.primary
              : RealtimeUiTokens.border,
          width: speaking || isFocused ? 2.2 : 1.1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : RealtimeUiTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant.isVideoEnabled && participant.videoTrack != null)
              MediaTrackView(renderer: renderer, track: participant.videoTrack)
            else
              Container(
                color: RealtimeUiTokens.background,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: RealtimeUiTokens.animNormal,
                  padding: EdgeInsets.all(speaking ? 8 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: speaking
                        ? Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.45),
                            width: 2.5,
                          )
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: RealtimeUiTokens.primarySubtle,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: RealtimeUiTokens.primary,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            if (onTap != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                    border: Border.all(color: RealtimeUiTokens.border),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isFocused
                        ? Icons.grid_view_rounded
                        : Icons.open_in_full_rounded,
                    size: 13,
                    color: RealtimeUiTokens.textMuted,
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .90),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                  boxShadow: RealtimeUiTokens.cardShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name${participant.isLocal ? strings.youSuffix : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: RealtimeUiTokens.text,
                        ),
                      ),
                    ),
                    Icon(
                      participant.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 15,
                      color: participant.isMuted
                          ? RealtimeUiTokens.danger
                          : speaking
                          ? const Color(0xFF10B981)
                          : RealtimeUiTokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      tile = RealtimeGlassPressable(
        onTap: onTap,
        pressedScale: 0.985,
        borderRadius: RealtimeUiTokens.cardRadius,
        child: tile,
      );
    }
    return tile;
  }
}

class _FloatingHeartItem {
  _FloatingHeartItem({
    required this.id,
    required this.color,
    required this.startX,
  });
  final String id;
  final Color color;
  final double startX;
}

class _FloatingHeartParticle extends StatefulWidget {
  const _FloatingHeartParticle({super.key, required this.heart});
  final _FloatingHeartItem heart;

  @override
  State<_FloatingHeartParticle> createState() => _FloatingHeartParticleState();
}

class _FloatingHeartParticleState extends State<_FloatingHeartParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, child) {
      final value = _progress.value;
      final yOffset = -value * 220;
      final xOffset = math.sin(value * math.pi * 2) * 16;
      final opacity = (1.0 - value).clamp(0.0, 1.0);
      return Align(
        alignment: Alignment(widget.heart.startX * 2 - 1, 0.85),
        child: Transform.translate(
          offset: Offset(xOffset, yOffset),
          child: Opacity(
            opacity: opacity,
            child: Icon(
              Icons.favorite_rounded,
              size: 26,
              color: widget.heart.color,
            ),
          ),
        ),
      );
    },
  );
}
