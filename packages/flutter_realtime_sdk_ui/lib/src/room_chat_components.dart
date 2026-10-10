import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';

/// Room roster without a sidebar, drawer or modal route.
class RealtimeParticipantList extends StatelessWidget {
  const RealtimeParticipantList({super.key, this.onSelected});
  final ValueChanged<MediaParticipant>? onSelected;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView.builder(
        itemCount: controller.snapshot.participants.length,
        itemBuilder: (context, index) {
          final member = controller.snapshot.participants[index];
          return ListTile(
            key: ValueKey(member.id),
            leading: RealtimeAvatar(
              name: member.displayName,
              size: 36,
              isOnline: true,
              showOnlineDot: true,
            ),
            title: Text(member.displayName),
            subtitle: member.isLocal ? const Text('You') : null,
            trailing: _ParticipantActions(
              controller: controller,
              member: member,
            ),
            onTap: onSelected == null ? null : () => onSelected!(member),
          );
        },
      ),
    );
  }
}

/// Host-only bulk mute with partial-failure retry. Layout stays app-owned.
class RealtimeBulkMuteButton extends StatelessWidget {
  const RealtimeBulkMuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canMuteAllParticipants) {
          return const SizedBox.shrink();
        }
        final busy = controller.isPending(
          RealtimeRoomUiAction.participantManagement,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Mute all participants',
              icon: const Icon(Icons.volume_off_outlined),
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Mute all participants?'),
                          content: const Text(
                            'Mute every other participant in this room.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Mute all'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      await _performBulkMute(context, controller, retry: false);
                    },
            ),
            if (controller.bulkMuteFailures.isNotEmpty)
              IconButton(
                tooltip: 'Retry failed mutes',
                icon: const Icon(Icons.refresh_outlined),
                onPressed: busy
                    ? null
                    : () => _performBulkMute(context, controller, retry: true),
              ),
          ],
        );
      },
    );
  }

  Future<void> _performBulkMute(
    BuildContext context,
    RealtimeRoomUiController controller, {
    required bool retry,
  }) async {
    try {
      await controller.muteAllParticipants(retryFailed: retry);
      if (context.mounted && controller.bulkMuteFailures.isNotEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              '${controller.bulkMuteFailures.length} participants could not be muted.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

/// Combined RTC/IM directory, sharing the same member reconciliation as the
/// legacy room. The app owns its placement and the list doesn't poll.
class RealtimeManagedParticipantList extends StatefulWidget {
  const RealtimeManagedParticipantList({super.key});

  @override
  State<RealtimeManagedParticipantList> createState() =>
      _RealtimeManagedParticipantListState();
}

class _RealtimeManagedParticipantListState
    extends State<RealtimeManagedParticipantList> {
  RealtimeRoomUiController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = RealtimeRoomUiScope.of(context);
    if (identical(current, _controller)) return;
    _controller = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(current, _controller)) {
        unawaited(current.refreshManagedMembers());
      }
    });
  }

  Future<void> _manage(
    BuildContext context,
    RealtimeRoomUiController controller,
    String action,
    String mediaId,
    String chatId,
    String name,
  ) async {
    if (action == 'removeMedia' || action == 'removeChat') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            action == 'removeChat'
                ? 'Remove from chat?'
                : 'Remove from meeting?',
          ),
          content: Text(name),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
    }
    try {
      switch (action) {
        case 'mute':
          await controller.muteParticipant(mediaId);
        case 'stopVideo':
          await controller.stopParticipantVideo(mediaId);
        case 'removeMedia':
          await controller.removeParticipant(mediaId);
        case 'removeChat':
          await controller.removeChatMember(chatId);
        case 'host':
          await controller.changeParticipantRole(mediaId, MediaRole.host);
      }
      if (action != 'removeChat' && action != 'host') {
        await controller.refreshManagedMembers();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final members = controller.managedMembers;
        final capabilities = controller.room.media.managementCapabilities;
        final mediaHost = controller.room.media.isLogicalOwner;
        final chat = controller.chatUiController;
        final canManageChat =
            chat?.isHost == true &&
            chat!.managementCapabilities.removeMember.supported;
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(child: Text('Participants (${members.length})')),
                const RealtimeBulkMuteButton(),
                IconButton(
                  tooltip: 'Refresh participants',
                  onPressed: controller.membersLoading
                      ? null
                      : () => unawaited(controller.refreshManagedMembers()),
                  icon: controller.membersLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (controller.memberLoadError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  controller.memberLoadError.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final media = member.media;
                  final chatMember = member.chat;
                  final canManageMedia =
                      !member.isSelf && media != null && mediaHost;
                  final canRemoveChat =
                      !member.isSelf && chatMember != null && canManageChat;
                  final actions = <PopupMenuEntry<String>>[
                    if (canManageMedia &&
                        capabilities.muteParticipant.supported)
                      const PopupMenuItem(value: 'mute', child: Text('Mute')),
                    if (canManageMedia &&
                        capabilities.stopParticipantVideo.supported)
                      const PopupMenuItem(
                        value: 'stopVideo',
                        child: Text('Stop video'),
                      ),
                    if (canManageMedia &&
                        capabilities.changeParticipantRole.supported)
                      const PopupMenuItem(
                        value: 'host',
                        child: Text('Grant host'),
                      ),
                    if (canManageMedia &&
                        capabilities.removeParticipant.supported)
                      const PopupMenuItem(
                        value: 'removeMedia',
                        child: Text('Remove from media'),
                      ),
                    if (canRemoveChat)
                      const PopupMenuItem(
                        value: 'removeChat',
                        child: Text('Remove from chat'),
                      ),
                  ];
                  return ListTile(
                    key: ValueKey(member.userId),
                    leading: RealtimeAvatar(
                      name: member.displayName,
                      size: 36,
                      isOnline: media != null || chatMember != null,
                      showOnlineDot: true,
                    ),
                    title: Text(member.displayName),
                    subtitle: Text(
                      [
                        if (media != null) 'Media online',
                        if (chatMember != null) 'Chat online',
                        if (member.isSelf) 'You',
                      ].join(' · '),
                    ),
                    trailing: actions.isEmpty
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: 'Manage member',
                            enabled: !controller.isPending(
                              RealtimeRoomUiAction.participantManagement,
                            ),
                            onSelected: (action) => _manage(
                              context,
                              controller,
                              action,
                              media?.participantId ?? '',
                              chatMember?.userId ?? '',
                              member.displayName,
                            ),
                            itemBuilder: (_) => actions,
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParticipantActions extends StatelessWidget {
  const _ParticipantActions({required this.controller, required this.member});
  final RealtimeRoomUiController controller;
  final MediaParticipant member;

  @override
  Widget build(BuildContext context) {
    final caps = controller.room.media.managementCapabilities;
    final canManage =
        controller.room.media.isLogicalOwner &&
        !member.isLocal &&
        (caps.removeParticipant.supported ||
            caps.muteParticipant.supported ||
            caps.stopParticipantVideo.supported);
    if (!canManage) {
      return Icon(member.isMuted ? Icons.mic_off : Icons.mic, size: 18);
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return PopupMenuButton<String>(
      tooltip: zh ? '管理成员' : 'Manage participant',
      enabled: !controller.isPending(
        RealtimeRoomUiAction.participantManagement,
      ),
      onSelected: (value) async {
        try {
          switch (value) {
            case 'mute':
              await controller.muteParticipant(member.id);
            case 'stopVideo':
              await controller.stopParticipantVideo(member.id);
            case 'remove':
              final approved = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(zh ? '移出成员' : 'Remove participant'),
                  content: Text(member.displayName),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(zh ? '取消' : 'Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(zh ? '确定' : 'Remove'),
                    ),
                  ],
                ),
              );
              if (approved == true) {
                await controller.removeParticipant(member.id);
              }
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
      },
      itemBuilder: (_) => [
        if (caps.muteParticipant.supported)
          PopupMenuItem(value: 'mute', child: Text(zh ? '静音' : 'Mute')),
        if (caps.stopParticipantVideo.supported)
          PopupMenuItem(
            value: 'stopVideo',
            child: Text(zh ? '关闭摄像头' : 'Stop video'),
          ),
        if (caps.removeParticipant.supported)
          PopupMenuItem(value: 'remove', child: Text(zh ? '移出会议' : 'Remove')),
      ],
    );
  }
}

/// Message timeline rendered separately from the send form.
class RealtimeChatMessageList extends StatelessWidget {
  const RealtimeChatMessageList({super.key});
  @override
  Widget build(BuildContext context) => const ChatMessageList();
}

/// Room-specific facade for the same composer used by standalone chat.
class RealtimeChatComposer extends StatelessWidget {
  const RealtimeChatComposer({super.key, this.hintText});
  final String? hintText;
  @override
  Widget build(BuildContext context) => ChatComposer(hintText: hintText);
}

/// Convenience grouping; consumers may place list and composer separately.
class RealtimeChatPanel extends StatelessWidget {
  const RealtimeChatPanel({super.key});

  @override
  Widget build(BuildContext context) => const ChatPanel();
}
