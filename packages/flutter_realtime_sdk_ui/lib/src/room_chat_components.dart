import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';

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
            leading: CircleAvatar(
              child: Text(
                member.displayName.isEmpty
                    ? '?'
                    : member.displayName.characters.first.toUpperCase(),
              ),
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
