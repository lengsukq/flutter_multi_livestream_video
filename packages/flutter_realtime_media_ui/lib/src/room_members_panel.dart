part of 'media_room_view.dart';

class _RoomMembersPanel extends StatelessWidget {
  const _RoomMembersPanel({required this.host, required this.snapshot});
  final _MediaRoomViewState host;
  final MediaSnapshot snapshot;
  @override
  Widget build(BuildContext context) => RoomRegion(
    revision: host._memberRevision,
    builder: (_) => host._buildParticipantsList(snapshot),
  );
}

extension _RoomMembersRendering on _MediaRoomViewState {
  Widget _buildParticipantsList(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    final capabilities = widget.room.managementCapabilities;
    final chatModeration = widget.chatModeration;
    final chatCapabilities = chatModeration is ChatModerationCapabilitySource
        ? (chatModeration as ChatModerationCapabilitySource)
              .moderationCapabilities
        : const ChatManagementCapabilities();
    final members = [...?_roomMembers];
    for (final participant in value.participants) {
      final alreadyListed = members.any(
        (member) => member.media?.participantId == participant.id,
      );
      if (alreadyListed) continue;
      members.add(
        _ManagedRoomMember(
          userId: '',
          displayName: participant.displayName.isEmpty
              ? participant.id
              : participant.displayName,
          media: MediaRoomParticipantSummary(
            participantId: participant.id,
            displayName: participant.displayName,
            role: participant.isLocal ? widget.room.role : null,
          ),
          isSelf: participant.isLocal,
        ),
      );
    }
    final canCloseChat =
        chatModeration != null && chatCapabilities.closeRoom.supported;
    final canCloseMedia = capabilities.closeRoom.supported;
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.controlRadius,
      opacity: .97,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.roomMembers,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${members.length}'),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: strings.refresh,
                  onPressed: _loadingRoomMembers
                      ? null
                      : () => unawaited(_refreshRoomMembers()),
                  visualDensity: VisualDensity.compact,
                  icon: _loadingRoomMembers
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 19),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (capabilities.muteParticipant.supported &&
              widget.room.role == MediaRole.host)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _mutingAll
                          ? null
                          : () => _muteAllParticipants(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RealtimeUiTokens.warning,
                        side: const BorderSide(color: RealtimeUiTokens.warning),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.volume_off_rounded, size: 16),
                      label: Text(
                        strings.muteAll,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  if (_muteFailures.isNotEmpty)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _mutingAll
                            ? null
                            : () => _muteAllParticipants(retry: true),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          strings.retryFailed,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_roomMembersError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _roomMembersError.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: members.isEmpty
                      ? Center(
                          child: _loadingRoomMembers
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : Text(strings.noManagedMembers),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: members.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final media = member.media;
                            final chat = member.chat;
                            final canRemoveMedia =
                                !member.isSelf &&
                                media != null &&
                                capabilities.removeParticipant.supported;
                            final canMuteMedia =
                                !member.isSelf &&
                                media != null &&
                                capabilities.muteParticipant.supported;
                            final canStopVideo =
                                !member.isSelf &&
                                media != null &&
                                capabilities.stopParticipantVideo.supported;
                            final canRemoveChat =
                                !member.isSelf &&
                                chat != null &&
                                chatModeration != null &&
                                chatCapabilities.removeMember.supported;
                            final canGrantHost =
                                !member.isSelf &&
                                media != null &&
                                widget.room.role == MediaRole.host &&
                                capabilities.changeParticipantRole.supported;
                            final hasActions =
                                canRemoveMedia ||
                                canMuteMedia ||
                                canStopVideo ||
                                canRemoveChat ||
                                canGrantHost;
                            return ListTile(
                              minLeadingWidth: 36,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: RealtimeUiTokens.primarySubtle,
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18,
                                  color: RealtimeUiTokens.primary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      member.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (member.isSelf)
                                    RealtimePill(
                                      label: strings.you,
                                      foreground: RealtimeUiTokens.primary,
                                      background:
                                          RealtimeUiTokens.primarySubtle,
                                      borderColor:
                                          RealtimeUiTokens.primaryBorder,
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(member.roleLabel(strings)),
                                  if (media != null &&
                                      _muteFailures.keys.any(
                                        (p) => p.id == media.participantId,
                                      ))
                                    Text(
                                      _muteFailures.entries
                                          .firstWhere(
                                            (entry) =>
                                                entry.key.id ==
                                                media.participantId,
                                          )
                                          .value
                                          .toString(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 5,
                                    runSpacing: 4,
                                    children: [
                                      if (media != null)
                                        RealtimePill(
                                          label: strings.mediaOnline,
                                          icon: Icons.videocam_outlined,
                                          foreground: const Color(0xFF047857),
                                          background: const Color(0xFFECFDF5),
                                          borderColor: const Color(0xFFA7F3D0),
                                        ),
                                      if (chat != null)
                                        RealtimePill(
                                          label: strings.chatOnline,
                                          icon: Icons.forum_outlined,
                                          foreground: RealtimeUiTokens.primary,
                                          background:
                                              RealtimeUiTokens.primarySubtle,
                                          borderColor:
                                              RealtimeUiTokens.primaryBorder,
                                        ),
                                    ],
                                  ),
                                  if (hasActions) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        if (canRemoveMedia)
                                          _memberActionButton(
                                            label: strings.removeFromMedia,
                                            icon: Icons.person_remove_outlined,
                                            danger: true,
                                            onPressed: () =>
                                                _runMemberManagement(
                                                  () => widget.room
                                                      .removeParticipant(
                                                        media.participantId,
                                                      ),
                                                ),
                                          ),
                                        if (canMuteMedia)
                                          _memberActionButton(
                                            label: strings.muteParticipant,
                                            icon: Icons.mic_off_outlined,
                                            onPressed: () =>
                                                _runMemberManagement(
                                                  () => widget.room
                                                      .muteParticipant(
                                                        media.participantId,
                                                      ),
                                                ),
                                          ),
                                        if (canStopVideo)
                                          _memberActionButton(
                                            label: strings.stopParticipantVideo,
                                            icon: Icons.videocam_off_outlined,
                                            onPressed: () =>
                                                _runMemberManagement(
                                                  () => widget.room
                                                      .stopParticipantVideo(
                                                        media.participantId,
                                                      ),
                                                ),
                                          ),
                                        if (canGrantHost)
                                          _memberActionButton(
                                            label: strings.grantHost,
                                            icon: Icons.shield_outlined,
                                            onPressed: () =>
                                                _runMemberManagement(
                                                  () => widget.room
                                                      .changeParticipantRole(
                                                        media.participantId,
                                                        MediaRole.host,
                                                      ),
                                                ),
                                          ),
                                        if (canRemoveChat)
                                          _memberActionButton(
                                            label: strings.removeFromChat,
                                            icon: Icons.forum_outlined,
                                            danger: true,
                                            onPressed: () =>
                                                _runMemberManagement(
                                                  () => chatModeration
                                                      .removeMember(
                                                        chat.userId,
                                                      ),
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          if (canCloseChat || canCloseMedia)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (canCloseChat)
                    OutlinedButton.icon(
                      onPressed: _closeChatRoomForEveryone,
                      icon: const Icon(Icons.forum_outlined, size: 17),
                      label: Text(strings.closeChatRoom),
                    ),
                  if (canCloseMedia)
                    OutlinedButton.icon(
                      onPressed: _closeRoomForEveryone,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RealtimeUiTokens.danger,
                        side: const BorderSide(
                          color: RealtimeUiTokens.dangerBorder,
                        ),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined, size: 17),
                      label: Text(strings.closeRoomForEveryone),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ManagedRoomMember {
  const _ManagedRoomMember({
    required this.userId,
    required this.displayName,
    this.media,
    this.chat,
    required this.isSelf,
  });

  final String userId;
  final String displayName;
  final MediaRoomParticipantSummary? media;
  final ChatMember? chat;
  final bool isSelf;

  String roleLabel(RealtimeStrings strings) {
    final mediaRole = media?.role?.wireName;
    final chatRole = chat?.role.name;
    return strings.roleLabel(mediaRole ?? chatRole ?? 'participant');
  }
}

List<_ManagedRoomMember> _mergeManagedMembers(
  List<MediaRoomParticipantSummary> media,
  List<ChatMember> chat, {
  required String localMediaParticipantId,
  String? localChatUserId,
}) {
  final mediaByKey = <String, MediaRoomParticipantSummary>{};
  final chatByKey = <String, ChatMember>{};
  final orderedKeys = <String>[];

  String mediaKey(MediaRoomParticipantSummary item) =>
      item.userId.trim().isNotEmpty
      ? item.userId.trim()
      : 'media:${item.participantId}';

  for (final item in media) {
    final key = mediaKey(item);
    mediaByKey[key] = item;
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
  }
  for (final item in chat) {
    final key = item.userId.trim();
    if (key.isEmpty) continue;
    chatByKey[key] = item;
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
  }

  return orderedKeys
      .map((key) {
        final mediaMember = mediaByKey[key];
        final chatMember = chatByKey[key];
        final rawName = mediaMember?.displayName.trim().isNotEmpty == true
            ? mediaMember!.displayName.trim()
            : chatMember?.displayName.trim().isNotEmpty == true
            ? chatMember!.displayName.trim()
            : key;
        final selfByMedia =
            mediaMember?.participantId == localMediaParticipantId;
        final selfByChat =
            localChatUserId != null &&
            localChatUserId.isNotEmpty &&
            chatMember?.userId == localChatUserId;
        return _ManagedRoomMember(
          userId: key,
          displayName: rawName,
          media: mediaMember,
          chat: chatMember,
          isSelf: selfByMedia || selfByChat,
        );
      })
      .toList(growable: false);
}
