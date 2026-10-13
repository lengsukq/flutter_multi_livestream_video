import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'room_members_controller.dart';

sealed class RoomMemberDirectoryState {
  const RoomMemberDirectoryState(this.members);
  final List<RoomManagedMember> members;
}

final class RoomMemberDirectoryIdle extends RoomMemberDirectoryState {
  const RoomMemberDirectoryIdle() : super(const []);
}

final class RoomMemberDirectoryLoading extends RoomMemberDirectoryState {
  const RoomMemberDirectoryLoading(super.members);
}

final class RoomMemberDirectoryReady extends RoomMemberDirectoryState {
  RoomMemberDirectoryReady(List<RoomManagedMember> members)
    : super(List.unmodifiable(members));
}

final class RoomMemberDirectoryFailed extends RoomMemberDirectoryState {
  const RoomMemberDirectoryFailed(this.error, super.members);
  final RealtimeException error;
}

/// Presentation state for one directory. Domain permission checks and provider
/// commands remain in the Runtime directory service. No room is owned here.
class RoomMembersPresentationController extends ChangeNotifier {
  RoomMembersPresentationController({required this.onError});
  final ValueChanged<RealtimeException> onError;
  final service = RoomMembersController();
  RoomMemberDirectoryState _state = const RoomMemberDirectoryIdle();
  RoomMemberDirectoryState get state => _state;
  MediaRoomSession? _room;
  ChatSession? _chat;
  ChatModeration? _moderation;
  bool _disposed = false;
  int _generation = 0;
  Future<RoomMuteResult?>? _muting;
  bool get muting => _muting != null;
  Map<MediaParticipant, Object> _muteFailures = const {};
  Map<MediaParticipant, Object> get muteFailures => _muteFailures;
  void bind(
    MediaRoomSession room,
    ChatSession? chat,
    ChatModeration? moderation,
  ) {
    if (identical(room, _room) &&
        identical(chat, _chat) &&
        identical(moderation, _moderation)) {
      return;
    }
    ++_generation;
    _room = room;
    _chat = chat;
    _moderation = moderation;
    _state = const RoomMemberDirectoryIdle();
    _muteFailures = const {};
    _muting = null;
  }

  bool _valid(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  RealtimeException _failure(Object error) {
    final failure = normalizeRealtimeException(
      error,
      domain: 'room.members.ui',
    );
    onError(failure);
    return failure;
  }

  Future<void> refresh() async {
    final room = _room;
    if (_disposed || room == null || _state is RoomMemberDirectoryLoading) {
      return;
    }
    final generation = _generation;
    _state = RoomMemberDirectoryLoading(_state.members);
    _notify();
    final result = await service.load(
      room,
      chatSession: _chat,
      chatModeration: _moderation,
      isCurrent: () => _valid(generation),
    );
    if (!_valid(generation) || !result.completed) return;
    final error = result.error;
    _state = error == null
        ? RoomMemberDirectoryReady(result.members)
        : RoomMemberDirectoryFailed(
            _failure(error),
            List.unmodifiable(result.members),
          );
    _notify();
  }

  Future<void> run(Future<void> Function() action) async {
    if (_disposed) return;
    final generation = _generation;
    try {
      await action();
      if (_valid(generation)) await refresh();
    } catch (error) {
      final failure = _failure(error);
      if (_valid(generation)) {
        _state = RoomMemberDirectoryFailed(failure, _state.members);
        _notify();
      }
    }
  }

  Future<RoomMuteResult?> mute(List<MediaParticipant> targets) {
    if (_disposed || _room == null) return Future.value();
    if (_muting case final pending?) return pending;
    final generation = _generation;
    final room = _room!;
    final operation = service
        .mute(room, targets, isCurrent: () => _valid(generation))
        .then<RoomMuteResult?>((result) {
          if (_valid(generation) && result.completed) {
            _muteFailures = Map.unmodifiable(result.failures);
          }
          return result;
        });
    _muting = operation;
    _notify();
    return operation.whenComplete(() {
      if (_valid(generation)) {
        _muting = null;
        _notify();
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
