import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'room_members_controller.dart';
import 'room_members_presentation_controller.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

class RoomMembersPanel extends StatefulWidget {
  const RoomMembersPanel({
    super.key,
    required this.presentation,
    required this.room,
    required this.snapshot,
    required this.onCloseRoom,
    this.chatSession,
    this.chatModeration,
  });
  final RoomMembersPresentationController presentation;
  final MediaRoomSession room;
  final MediaSnapshot snapshot;
  final ChatSession? chatSession;
  final ChatModeration? chatModeration;
  final Future<void> Function() onCloseRoom;
  @override
  State<RoomMembersPanel> createState() => _RoomMembersPanelState();
}

class _RoomMembersPanelState extends State<RoomMembersPanel> {
  bool _confirmingMute = false;
  bool get _mutingAll => widget.presentation.muting;
  Map<MediaParticipant, Object> get _muteFailures =>
      widget.presentation.muteFailures;
  List<RoomManagedMember> get _roomMembers => widget.presentation.state.members;
  bool get _loadingRoomMembers =>
      widget.presentation.state is RoomMemberDirectoryLoading;
  RealtimeException? get _roomMembersError =>
      switch (widget.presentation.state) {
        RoomMemberDirectoryFailed(:final error) => error,
        _ => null,
      };
  MediaSession get session => widget.room.session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.presentation,
    builder: (context, _) => _buildParticipantsList(widget.snapshot),
  );
  Future<void> _closeChatRoom() => widget.presentation.run(() async {
    await widget.chatModeration?.closeRoom();
  });
  Future<void> _muteAllParticipants({bool retry = false}) async {
    if (_mutingAll || _confirmingMute) return;
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
    setState(() => _confirmingMute = true);
    if (!retry) {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => RealtimeGlassDialog(
          icon: Icons.volume_off_rounded,
          title: Text(strings.muteAll),
          content: Text(strings.muteAllConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(strings.muteAll),
            ),
          ],
        ),
      );
      if (!mounted || targetRoom != widget.room) return;
      if (confirmed != true) {
        setState(() => _confirmingMute = false);
        return;
      }
    }
    if (mounted) setState(() => _confirmingMute = false);
    final result = await widget.presentation.mute(targets);
    if (!mounted || result == null || !result.completed) return;
    final failures = result.failures;
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
    await widget.presentation.refresh();
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

  Widget _buildParticipantsList(MediaSnapshot value) {
    final strings = RealtimeStrings.of(context);
    final capabilities = widget.room.managementCapabilities;
    final chatModeration = widget.chatModeration;
    final chatCapabilities = chatModeration is ChatModerationCapabilitySource
        ? (chatModeration as ChatModerationCapabilitySource)
              .moderationCapabilities
        : const ChatManagementCapabilities();
    final members = [..._roomMembers];
    for (final participant in value.participants) {
      final alreadyListed = members.any(
        (member) => member.media?.participantId == participant.id,
      );
      if (alreadyListed) continue;
      members.add(
        RoomManagedMember(
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
    final mediaOwner = widget.room.isLogicalOwner;
    final chatHost = widget.chatSession?.role == ChatRole.host;
    final canCloseChat =
        chatHost &&
        chatModeration != null &&
        chatCapabilities.closeRoom.supported;
    final canCloseMedia = mediaOwner && capabilities.closeRoom.supported;
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
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
                      : () => unawaited(widget.presentation.refresh()),
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
          if (mediaOwner && capabilities.muteParticipant.supported)
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
                                mediaOwner &&
                                !member.isSelf &&
                                media != null &&
                                capabilities.removeParticipant.supported;
                            final canMuteMedia =
                                mediaOwner &&
                                !member.isSelf &&
                                media != null &&
                                capabilities.muteParticipant.supported;
                            final canStopVideo =
                                mediaOwner &&
                                !member.isSelf &&
                                media != null &&
                                capabilities.stopParticipantVideo.supported;
                            final canRemoveChat =
                                chatHost &&
                                !member.isSelf &&
                                chat != null &&
                                chatModeration != null &&
                                chatCapabilities.removeMember.supported;
                            final canGrantHost =
                                !member.isSelf &&
                                media != null &&
                                mediaOwner &&
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
                              leading: RealtimeAvatar(
                                name: member.displayName,
                                avatarUrl: member.avatarUrl,
                                size: 36,
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
                                                widget.presentation.run(
                                                  () => widget
                                                      .presentation
                                                      .service
                                                      .manageMedia(
                                                        widget.room,
                                                        media.participantId,
                                                        RoomMediaMemberAction
                                                            .remove,
                                                      ),
                                                ),
                                          ),
                                        if (canMuteMedia)
                                          _memberActionButton(
                                            label: strings.muteParticipant,
                                            icon: Icons.mic_off_outlined,
                                            onPressed: () =>
                                                widget.presentation.run(
                                                  () => widget
                                                      .presentation
                                                      .service
                                                      .manageMedia(
                                                        widget.room,
                                                        media.participantId,
                                                        RoomMediaMemberAction
                                                            .mute,
                                                      ),
                                                ),
                                          ),
                                        if (canStopVideo)
                                          _memberActionButton(
                                            label: strings.stopParticipantVideo,
                                            icon: Icons.videocam_off_outlined,
                                            onPressed: () =>
                                                widget.presentation.run(
                                                  () => widget
                                                      .presentation
                                                      .service
                                                      .manageMedia(
                                                        widget.room,
                                                        media.participantId,
                                                        RoomMediaMemberAction
                                                            .stopVideo,
                                                      ),
                                                ),
                                          ),
                                        if (canGrantHost)
                                          _memberActionButton(
                                            label: strings.grantHost,
                                            icon: Icons.shield_outlined,
                                            onPressed: () =>
                                                widget.presentation.run(
                                                  () => widget
                                                      .presentation
                                                      .service
                                                      .manageMedia(
                                                        widget.room,
                                                        media.participantId,
                                                        RoomMediaMemberAction
                                                            .grantHost,
                                                      ),
                                                ),
                                          ),
                                        if (canRemoveChat)
                                          _memberActionButton(
                                            label: strings.removeFromChat,
                                            icon: Icons.forum_outlined,
                                            danger: true,
                                            onPressed: () =>
                                                widget.presentation.run(
                                                  () => widget
                                                      .presentation
                                                      .service
                                                      .removeChatMember(
                                                        chatModeration,
                                                        chat.userId,
                                                        session:
                                                            widget.chatSession,
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
                      onPressed: _closeChatRoom,
                      icon: const Icon(Icons.forum_outlined, size: 17),
                      label: Text(strings.closeChatRoom),
                    ),
                  if (canCloseMedia)
                    OutlinedButton.icon(
                      onPressed: widget.onCloseRoom,
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

extension _RoomManagedMemberLabels on RoomManagedMember {
  String roleLabel(RealtimeStrings strings) {
    final mediaRole = media?.role?.wireName;
    final chatRole = chat?.role.name;
    return strings.roleLabel(mediaRole ?? chatRole ?? 'participant');
  }
}
