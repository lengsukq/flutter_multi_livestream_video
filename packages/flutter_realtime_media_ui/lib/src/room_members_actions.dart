part of 'media_room_view.dart';

/// The legacy page handles dialogs and navigation while RTC/IM member
/// authority and merging are delegated to RoomMembersController.
extension _LegacyRoomMemberActions on _MediaRoomViewState {
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

  void _openParticipants() {
    final opening = !_participantsOpen;
    _updateRoom(() {
      _participantsOpen = !_participantsOpen;
      _chatOpen = false;
    });
    if (opening) unawaited(_refreshRoomMembers());
  }

  Future<void> _refreshRoomMembers() async {
    if (_loadingRoomMembers) return;
    final requestedRoom = widget.room;
    final requestedChat = widget.chatSession;
    final requestedModeration = widget.chatModeration;
    _updateMembers(() {
      _loadingRoomMembers = true;
      _roomMembersError = null;
    });
    final result = await _members.load(
      requestedRoom,
      chatSession: requestedChat,
      chatModeration: requestedModeration,
      isCurrent: () =>
          mounted &&
          identical(requestedRoom, widget.room) &&
          identical(requestedChat, widget.chatSession) &&
          identical(requestedModeration, widget.chatModeration),
    );
    if (!result.completed) return;
    _updateMembers(() {
      _roomMembers = result.members;
      _roomMembersError = result.error;
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
}
