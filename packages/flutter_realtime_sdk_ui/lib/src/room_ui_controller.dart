import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';

/// Room actions shared by independent widgets in a host-defined layout.
enum RealtimeRoomUiAction {
  microphone,
  camera,
  switchCamera,
  audioOutput,
  device,
  screenShare,
  sendMessage,
  backgroundEffect,
  liveLike,
  classroom,
  participantManagement,
  leave,
}

/// Presentation state and commands; never owns provider sessions or rendering.
///
/// A single instance is shared by every room component. Subscriptions are
/// attached once, and disposing the UI does not disconnect the actual room.
class RealtimeRoomUiController extends ChangeNotifier {
  RealtimeRoomUiController(
    this.room, {
    MediaCameraPosition initialCameraPosition = MediaCameraPosition.front,
  }) : _cameraPosition = initialCameraPosition {
    _snapshot = room.media.session.snapshot;
    _mediaSubscription = room.media.session.snapshots.listen((snapshot) {
      if (_disposed) return;
      _snapshot = snapshot;
      notifyListeners();
    });
    final chat = room.chat;
    if (chat != null) {
      _chatUi = ChatUiController(chat, moderation: room.chatModeration);
      _chatUi!.addListener(_onChatChanged);
    }
    _classroomSubscription = room.classroom?.states
        .map<Object?>((_) => null)
        .listen((_) {
          if (!_disposed) notifyListeners();
        });
    _liveState = room.liveInteractions?.state;
    _liveSubscription = room.liveInteractions?.states.listen((state) {
      if (_disposed) return;
      _liveState = state;
      notifyListeners();
    });
    _likeSubscription = room.liveInteractions?.likes.listen((event) {
      if (_disposed) return;
      _receivedLikeCount += event.quantity;
      notifyListeners();
    });
  }

  /// Shares the same partially-successful bulk moderation service as the
  /// legacy room. Failures are retained so a host can retry only failed IDs.
  Future<void> muteAllParticipants({bool retryFailed = false}) async {
    if (!canMuteAllParticipants) return;
    final targets = retryFailed ? _bulkMuteFailures.keys.toList() : null;
    if (targets != null && targets.isEmpty) return;
    await _execute(RealtimeRoomUiAction.participantManagement, () async {
      final result = await _memberDirectory.muteAll(
        room.media,
        targets: targets,
        isCurrent: () => !_disposed,
      );
      if (_disposed || !result.completed) return;
      _bulkMuteFailures = result.failures;
      notifyListeners();
      await refreshManagedMembers();
    });
  }

  Future<void> answerClassroomActivity(String activityId, int option) async {
    final classroom = room.classroom;
    if (classroom == null || classroomState?.capabilities.canUseTools != true) {
      return;
    }
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => classroom.answerActivity(activityId, option),
    );
  }

  Future<void> closeClassroomActivity(String activityId) async {
    final classroom = room.classroom;
    if (classroom == null ||
        classroomState?.capabilities.canPublishTools != true) {
      return;
    }
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => classroom.closeActivity(activityId),
    );
  }

  Future<void> removeParticipant(String participantId) => _execute(
    RealtimeRoomUiAction.participantManagement,
    () => _memberDirectory.manageMedia(
      room.media,
      participantId,
      RoomMediaMemberAction.remove,
    ),
  );

  ClassroomState? get classroomState => room.classroom?.state;
  bool get canRaiseHand => classroomState?.capabilities.canRaiseHand == true;
  bool get canManageQuestions =>
      classroomState?.capabilities.canManageQuestions == true;
  bool get canAskQuestion =>
      classroomState?.capabilities.canAskQuestion == true;
  bool get canGrantSpeak => classroomState?.capabilities.canGrantSpeak == true;
  bool get canViewClassroomRoster =>
      classroomState?.capabilities.canViewRoster == true;

  Future<void> setHandRaised(bool raised) async {
    final classroom = room.classroom;
    if (classroom == null || !canRaiseHand) return;
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => raised ? classroom.raiseHand() : classroom.lowerHand(),
    );
  }

  Future<void> setStudentCanSpeak(
    String userId, {
    required bool canSpeak,
  }) async {
    final classroom = room.classroom;
    if (classroom == null || !canGrantSpeak) return;
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => canSpeak
          ? classroom.grantSpeak(userId)
          : classroom.revokeSpeak(userId),
    );
  }

  Future<void> askClassroomQuestion(String question) async {
    final classroom = room.classroom;
    if (classroom == null || !canAskQuestion || question.trim().isEmpty) return;
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => classroom.askQuestion(question.trim()),
    );
  }

  Future<void> answerClassroomQuestion(String id, String answer) async {
    final classroom = room.classroom;
    if (classroom == null || !canManageQuestions || answer.trim().isEmpty) {
      return;
    }
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => classroom.answerQuestion(id, answer.trim()),
    );
  }

  Future<void> resolveClassroomQuestion(String id) async {
    final classroom = room.classroom;
    if (classroom == null || !canManageQuestions) return;
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => classroom.resolveQuestion(id),
    );
  }

  Future<void> sendClassroomFeedback(ClassroomFeedbackKind kind) async {
    final classroom = room.classroom;
    if (classroom == null ||
        classroomState?.capabilities.canSendFeedback != true) {
      return;
    }
    await _execute(
      RealtimeRoomUiAction.classroom,
      () => classroom.sendFeedback(kind),
    );
  }

  Future<void> sendLiveLike() async {
    final live = room.liveInteractions;
    if (live == null) return;
    await _execute(RealtimeRoomUiAction.liveLike, live.sendLike);
  }

  Future<void> muteParticipant(String participantId) => _execute(
    RealtimeRoomUiAction.participantManagement,
    () => _memberDirectory.manageMedia(
      room.media,
      participantId,
      RoomMediaMemberAction.mute,
    ),
  );

  Future<void> stopParticipantVideo(String participantId) => _execute(
    RealtimeRoomUiAction.participantManagement,
    () => _memberDirectory.manageMedia(
      room.media,
      participantId,
      RoomMediaMemberAction.stopVideo,
    ),
  );

  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) => _execute(
    RealtimeRoomUiAction.backgroundEffect,
    () => room.setBackgroundEffect(effect),
  );

  final RealtimeRoom room;
  RoomMembersController get _memberDirectory => room.memberDirectory;
  List<RoomManagedMember> _managedMembers = const [];
  Map<MediaParticipant, Object> _bulkMuteFailures = const {};
  Object? _memberLoadError;
  bool _membersLoading = false;
  late MediaSnapshot _snapshot;
  ChatUiController? _chatUi;
  final Set<RealtimeRoomUiAction> _pending = {};
  StreamSubscription<MediaSnapshot>? _mediaSubscription;
  StreamSubscription<Object?>? _classroomSubscription;
  StreamSubscription<LiveInteractionState>? _liveSubscription;
  StreamSubscription<LiveLikeEvent>? _likeSubscription;
  LiveInteractionState? _liveState;
  MediaCameraPosition _cameraPosition;
  int _receivedLikeCount = 0;
  Object? _error;
  bool _disposed = false;

  MediaSnapshot get snapshot => _snapshot;
  bool get membersLoading => _membersLoading;
  Map<MediaParticipant, Object> get bulkMuteFailures => _bulkMuteFailures;
  bool get canMuteAllParticipants =>
      room.media.isLogicalOwner &&
      room.media.managementCapabilities.muteParticipant.supported &&
      _snapshot.participants.any((member) => !member.isLocal);
  Object? get memberLoadError => _memberLoadError;

  /// Includes RTC-only and chat-only members, reconciled by logical user ID.
  List<RoomManagedMember> get managedMembers => mergeSnapshotMembers(
    _managedMembers,
    _snapshot,
    localRole: room.media.role,
  );

  /// Explicit refresh avoids backend polling by every independent UI widget.
  Future<void> refreshManagedMembers() async {
    if (_disposed || _membersLoading) return;
    _membersLoading = true;
    _memberLoadError = null;
    notifyListeners();
    final result = await _memberDirectory.load(
      room.media,
      chatSession: room.chat,
      chatModeration: room.chatModeration,
      isCurrent: () => !_disposed,
    );
    if (_disposed || !result.completed) return;
    _managedMembers = result.members;
    _memberLoadError = result.error;
    _membersLoading = false;
    notifyListeners();
  }

  Future<void> removeChatMember(String userId) async {
    final chat = _chatUi;
    if (chat == null ||
        !chat.isHost ||
        !chat.managementCapabilities.removeMember.supported) {
      return;
    }
    await _execute(RealtimeRoomUiAction.participantManagement, () async {
      await _memberDirectory.removeChatMember(
        room.chatModeration!,
        userId,
        session: room.chat,
      );
      await chat.refreshMembers();
      await refreshManagedMembers();
    });
  }

  Future<void> changeParticipantRole(
    String participantId,
    MediaRole role,
  ) async {
    if (!room.media.isLogicalOwner ||
        !room.media.managementCapabilities.changeParticipantRole.supported) {
      return;
    }
    await _execute(
      RealtimeRoomUiAction.participantManagement,
      () => role == MediaRole.host
          ? _memberDirectory.manageMedia(
              room.media,
              participantId,
              RoomMediaMemberAction.grantHost,
            )
          : room.media.changeParticipantRole(participantId, role),
    );
    await refreshManagedMembers();
  }

  List<ChatMessage> get messages => _chatUi?.messages ?? const <ChatMessage>[];
  ChatUiController? get chatUiController => _chatUi;
  void _onChatChanged() {
    if (!_disposed) notifyListeners();
  }

  Object? get error => _error;
  LiveInteractionState? get liveState => _liveState;
  MediaCameraPosition get cameraPosition => _cameraPosition;
  int get receivedLikeCount => _receivedLikeCount;
  bool isPending(RealtimeRoomUiAction action) => _pending.contains(action);

  InteractiveMediaSession? get _interactive =>
      room.media.session is InteractiveMediaSession
      ? room.media.session as InteractiveMediaSession
      : null;

  bool get canUseMicrophone =>
      _interactive != null &&
      _snapshot.capabilities.canPublishAudio &&
      _canSpeak;

  bool get _canSpeak {
    final classroom = room.classroom;
    if (classroom == null || !_snapshot.localMuted) return true;
    final state = classroom.state;
    if (state?.isTeacher == true || room.media.roomOwnerCredential != null) {
      return true;
    }
    if (state == null) return false;
    return state.students.any(
      (student) => student.userId == state.selfUserId && student.canSpeak,
    );
  }

  bool get canUseCamera =>
      _interactive != null && _snapshot.capabilities.canPublishVideo;
  bool get canShareScreen =>
      _interactive != null && _snapshot.capabilities.canScreenShare;
  bool get canSwitchCamera =>
      _interactive != null && _snapshot.capabilities.canSwitchCamera;
  bool get canListAudioOutputs =>
      _interactive != null && _snapshot.capabilities.canEnumerateAudioDevices;
  bool get canSelectAudioOutput =>
      canListAudioOutputs && _snapshot.capabilities.canSelectAudioOutput;

  /// MediaDeviceController is optional: the capability flags remain the
  /// source of truth, and unsupported providers never receive a command.
  bool canListMediaDevices(MediaDeviceKind kind) => switch (kind) {
    MediaDeviceKind.microphone =>
      _snapshot.capabilities.canEnumerateMicrophones,
    MediaDeviceKind.camera => _snapshot.capabilities.canEnumerateCameras,
    MediaDeviceKind.audioOutput =>
      _snapshot.capabilities.canEnumerateAudioDevices,
  };

  bool canSelectMediaDevice(MediaDeviceKind kind) => switch (kind) {
    MediaDeviceKind.microphone => _snapshot.capabilities.canSelectMicrophone,
    MediaDeviceKind.camera => _snapshot.capabilities.canSelectCamera,
    MediaDeviceKind.audioOutput => _snapshot.capabilities.canSelectAudioOutput,
  };

  Future<List<MediaDevice>> listMediaDevices(MediaDeviceKind kind) async {
    if (!canListMediaDevices(kind)) return const [];
    return room.media.session.listMediaDevices(kinds: {kind});
  }

  Future<void> selectMediaDevice(MediaDevice device) async {
    if (!canSelectMediaDevice(device.kind)) return;
    await _execute(
      RealtimeRoomUiAction.device,
      () => room.media.session.selectMediaDevice(device),
    );
  }

  Future<List<MediaAudioDevice>> listAudioOutputs() async {
    if (!canListAudioOutputs) return const [];
    return _interactive!.listAudioDevices();
  }

  Future<void> selectAudioOutput(MediaAudioDevice device) async {
    if (!canSelectAudioOutput) return;
    await _execute(
      RealtimeRoomUiAction.audioOutput,
      () => _interactive!.selectAudioDevice(device),
    );
  }

  /// Runs once per action; concurrent duplicate button presses are ignored.
  Future<void> _execute(
    RealtimeRoomUiAction action,
    Future<void> Function() command,
  ) async {
    if (_disposed || _pending.contains(action)) return;
    _pending.add(action);
    _error = null;
    notifyListeners();
    try {
      await command();
    } catch (error) {
      if (!_disposed) _error = error;
      rethrow;
    } finally {
      if (!_disposed) {
        _pending.remove(action);
        notifyListeners();
      }
    }
  }

  Future<void> toggleMicrophone() async {
    if (!canUseMicrophone) return;
    await _execute(RealtimeRoomUiAction.microphone, _interactive!.toggleMute);
  }

  Future<void> toggleCamera() async {
    if (!canUseCamera) return;
    await _execute(
      RealtimeRoomUiAction.camera,
      () => _interactive!.setVideoEnabled(!_snapshot.localVideoEnabled),
    );
  }

  Future<void> toggleScreenShare() async {
    if (!canShareScreen) return;
    await _execute(
      RealtimeRoomUiAction.screenShare,
      () => _interactive!.setScreenShareEnabled(
        !_snapshot.localScreenShareEnabled,
      ),
    );
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    final next = _cameraPosition == MediaCameraPosition.front
        ? MediaCameraPosition.back
        : MediaCameraPosition.front;
    await _execute(RealtimeRoomUiAction.switchCamera, () async {
      await _interactive!.switchCamera(next);
      if (!_disposed) {
        _cameraPosition = next;
        notifyListeners();
      }
    });
  }

  Future<void> sendMessage(String text) async {
    final chat = _chatUi;
    if (chat == null || text.trim().isEmpty) return;
    await _execute(
      RealtimeRoomUiAction.sendMessage,
      () => chat.send(text.trim()),
    );
  }

  /// Ends the underlying room only when requested, never on UI disposal.
  /// The caller owns navigation and the optional confirmation dialog.
  Future<void> leave({bool? closeForEveryone}) =>
      _execute(RealtimeRoomUiAction.leave, () async {
        if (closeForEveryone ??
            (room.media.role == MediaRole.host &&
                room.media.managementCapabilities.closeRoom.supported)) {
          await room.media.closeRoom();
        }
        await room.dispose();
      });

  @override
  void dispose() {
    _disposed = true;
    unawaited(_mediaSubscription?.cancel());
    _chatUi?.removeListener(_onChatChanged);
    _chatUi?.dispose();
    unawaited(_classroomSubscription?.cancel());
    unawaited(_liveSubscription?.cancel());
    unawaited(_likeSubscription?.cancel());
    super.dispose();
  }
}

/// Exposes one room UI controller to arbitrarily composed descendant widgets.
///
/// Multiple room layouts can use the same controller. Supply [controller] to
/// retain presentation state across layout changes, or let the scope own it.
class RealtimeRoomUiScope extends StatefulWidget {
  const RealtimeRoomUiScope({
    super.key,
    required this.room,
    required this.child,
    this.controller,
  });

  final RealtimeRoom room;
  final Widget child;
  final RealtimeRoomUiController? controller;

  static RealtimeRoomUiController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RealtimeRoomUiInherited>();
    assert(scope != null, 'RealtimeRoomUiScope is required above this widget');
    return scope!.controller;
  }

  @override
  State<RealtimeRoomUiScope> createState() => _RealtimeRoomUiScopeState();
}

class _RealtimeRoomUiScopeState extends State<RealtimeRoomUiScope> {
  late RealtimeRoomUiController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RealtimeRoomUiController(widget.room);
    assert(identical(_controller.room, widget.room));
  }

  @override
  void didUpdateWidget(covariant RealtimeRoomUiScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        !identical(oldWidget.controller, widget.controller)) {
      if (_ownsController) _controller.dispose();
      _initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _RealtimeRoomUiInherited(
      controller: _controller,
      child: widget.child,
    );
    final chat = _controller.chatUiController;
    return chat == null
        ? content
        : ChatUiScope(
            session: chat.session,
            moderation: chat.moderation,
            controller: chat,
            child: content,
          );
  }
}

class _RealtimeRoomUiInherited extends InheritedWidget {
  const _RealtimeRoomUiInherited({
    required this.controller,
    required super.child,
  });

  final RealtimeRoomUiController controller;

  @override
  bool updateShouldNotify(_RealtimeRoomUiInherited oldWidget) =>
      !identical(controller, oldWidget.controller);
}
