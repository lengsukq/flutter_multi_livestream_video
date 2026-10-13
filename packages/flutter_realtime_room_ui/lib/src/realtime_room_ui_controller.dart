import 'realtime_room_ui_action.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';

/// Presentation state and commands; never owns provider sessions or rendering.
///
/// A single instance is shared by every room component. Subscriptions are
/// attached once, and disposing the UI does not disconnect the actual room.
class RealtimeRoomUiController extends ChangeNotifier {
  RealtimeRoomUiController(
    this.room, {
    this.onActionError,
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
  }

  /// Shares the same partially-successful bulk moderation service as the
  /// legacy room. Failures are retained so a host can retry only failed IDs.
  Future<void> muteAllParticipants({bool retryFailed = false}) async {
    if (!canMuteAllParticipants) return;
    final targets = retryFailed ? _bulkMuteFailures.keys.toList() : null;
    if (targets != null && targets.isEmpty) return;
    await execute(RealtimeRoomUiAction.participantManagement, () async {
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

  Future<void> removeParticipant(String participantId) => execute(
    RealtimeRoomUiAction.participantManagement,
    () => _memberDirectory.manageMedia(
      room.media,
      participantId,
      RoomMediaMemberAction.remove,
    ),
  );

  Future<void> muteParticipant(String participantId) => execute(
    RealtimeRoomUiAction.participantManagement,
    () => _memberDirectory.manageMedia(
      room.media,
      participantId,
      RoomMediaMemberAction.mute,
    ),
  );

  Future<void> stopParticipantVideo(String participantId) => execute(
    RealtimeRoomUiAction.participantManagement,
    () => _memberDirectory.manageMedia(
      room.media,
      participantId,
      RoomMediaMemberAction.stopVideo,
    ),
  );

  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) => execute(
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
  MediaCameraPosition _cameraPosition;
  RealtimeException? _error;
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
    await execute(RealtimeRoomUiAction.participantManagement, () async {
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
    await execute(
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

  final void Function(RealtimeException error)? onActionError;
  bool get isDisposed => _disposed;
  RealtimeException? get error => _error;
  void reportActionError(Object error) {
    final failure = normalizeRealtimeException(error, domain: 'room.ui');
    if (!_disposed) {
      _error = failure;
      onActionError?.call(failure);
      notifyListeners();
    } else {
      room.reportLifecycleFailure(failure);
    }
  }

  MediaCameraPosition get cameraPosition => _cameraPosition;
  bool isPending(RealtimeRoomUiAction action) => _pending.contains(action);

  InteractiveMediaSession? get _interactive =>
      room.media.session is InteractiveMediaSession
      ? room.media.session as InteractiveMediaSession
      : null;

  bool get canUseMicrophone =>
      _interactive != null && _snapshot.capabilities.canPublishAudio;

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
    await execute(
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
    await execute(
      RealtimeRoomUiAction.audioOutput,
      () => _interactive!.selectAudioDevice(device),
    );
  }

  /// Runs once per action; concurrent duplicate button presses are ignored.
  Future<void> execute(
    RealtimeRoomUiAction action,
    Future<void> Function() command,
  ) async {
    if (_disposed || _pending.contains(action)) return;
    _pending.add(action);
    _error = null;
    notifyListeners();
    try {
      await command();
    } catch (error, stack) {
      final failure = normalizeRealtimeException(
        error,
        domain: 'room.ui',
        stackTrace: stack,
      );
      if (!_disposed) _error = failure;
      Error.throwWithStackTrace(failure, stack);
    } finally {
      if (!_disposed) {
        _pending.remove(action);
        notifyListeners();
      }
    }
  }

  Future<void> toggleMicrophone() async {
    if (!canUseMicrophone) return;
    await execute(RealtimeRoomUiAction.microphone, _interactive!.toggleMute);
  }

  Future<void> toggleCamera() async {
    if (!canUseCamera) return;
    await execute(
      RealtimeRoomUiAction.camera,
      () => _interactive!.setVideoEnabled(!_snapshot.localVideoEnabled),
    );
  }

  Future<void> toggleScreenShare() async {
    if (!canShareScreen) return;
    await execute(
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
    await execute(RealtimeRoomUiAction.switchCamera, () async {
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
    await execute(
      RealtimeRoomUiAction.sendMessage,
      () => chat.send(text.trim()),
    );
  }

  /// Ends the underlying room only when requested, never on UI disposal.
  /// The caller owns navigation and the optional confirmation dialog.
  Future<void> leave({bool? closeForEveryone}) =>
      execute(RealtimeRoomUiAction.leave, () async {
        if (closeForEveryone ??
            (room.media.role == MediaRole.host &&
                room.media.managementCapabilities.closeRoom.supported)) {
          await room.media.closeRoom();
        }
        await room.dispose();
      });

  Future<void>? _disposal;

  /// Cancels owned presentation subscriptions; the borrowed room stays open.
  Future<void> close() {
    dispose();
    return _disposal!;
  }

  @protected
  Future<void> releaseResources() async {
    // Local subscription cancellation has no external I/O or acquisition.
    final cleanup = Cleanup(timeout: null);
    final mediaRelease = cleanup.run('room.ui.media', () async {
      await _mediaSubscription?.cancel();
    });
    final chatRelease = cleanup.run('room.ui.chat', () {
      _chatUi?.removeListener(_onChatChanged);
      _chatUi?.dispose();
    });
    await Future.wait([mediaRelease, chatRelease]);
    cleanup.finish(domain: 'room.ui');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
    _disposal = releaseResources();
    observeDetached(
      _disposal!,
      onFailure: (error) {
        room.reportLifecycleFailure(error);
      },
    );
  }
}
