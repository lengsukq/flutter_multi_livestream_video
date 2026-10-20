import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'chat_ui_scope.dart';

class ChatMemberList extends StatelessWidget {
  const ChatMemberList({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView.builder(
        itemCount: controller.members.length,
        itemBuilder: (context, index) {
          final member = controller.members[index];
          final capabilities = controller.managementCapabilities;
          final canManage =
              controller.isHost &&
              member.role != ChatRole.host &&
              !(controller.session is ChatSessionIdentity &&
                  (controller.session as ChatSessionIdentity).localUserId ==
                      member.userId);
          final hasActions =
              canManage &&
              (capabilities.removeMember.supported ||
                  capabilities.muteMember.supported ||
                  capabilities.banMember.supported ||
                  capabilities.manageRoles.supported);
          return ListTile(
            leading: RealtimeAvatar(
              name: member.displayName.isEmpty
                  ? member.userId
                  : member.displayName,
              avatarUrl: member.avatarUrl,
              size: 36,
            ),
            title: Text(
              member.displayName.isEmpty ? member.userId : member.displayName,
            ),
            subtitle: Text(
              [
                zh
                    ? switch (member.role) {
                        ChatRole.host => '房主',
                        ChatRole.participant => '参与者',
                        _ => '成员',
                      }
                    : member.role.name,
                if (member.muted) (zh ? '已禁言' : 'muted'),
                if (member.banned) (zh ? '已封禁' : 'banned'),
              ].join(' · '),
            ),
            trailing: hasActions
                ? PopupMenuButton<String>(
                    tooltip: zh ? '管理成员' : 'Manage member',
                    onSelected: (action) async {
                      await Future<void>.delayed(Duration.zero);
                      if (!context.mounted) return;
                      try {
                        switch (action) {
                          case 'remove':
                            final approved = await showDialog<bool>(
                              context: context,
                              useRootNavigator: true,
                              builder: (dialogContext) => RealtimeGlassDialog(
                                title: Text(zh ? '移除成员？' : 'Remove member?'),
                                content: Text(
                                  member.displayName.isEmpty
                                      ? member.userId
                                      : member.displayName,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: Text(zh ? '取消' : 'Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: Text(zh ? '移除' : 'Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (approved == true) {
                              await controller.removeMember(member.userId);
                            }
                          case 'mute':
                            await controller.muteMember(
                              member.userId,
                              muted: !member.muted,
                            );
                          case 'ban':
                            await controller.banMember(
                              member.userId,
                              banned: !member.banned,
                            );
                          case 'role':
                            await controller.changeMemberRole(
                              member.userId,
                              ChatRole.participant,
                            );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (capabilities.removeMember.supported)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(zh ? '移除成员' : 'Remove member'),
                        ),
                      if (capabilities.muteMember.supported)
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(
                            member.muted
                                ? (zh ? '解除禁言' : 'Unmute')
                                : (zh ? '禁言' : 'Mute'),
                          ),
                        ),
                      if (capabilities.banMember.supported)
                        PopupMenuItem(
                          value: 'ban',
                          child: Text(
                            member.banned
                                ? (zh ? '解除封禁' : 'Unban')
                                : (zh ? '封禁' : 'Ban'),
                          ),
                        ),
                      if (capabilities.manageRoles.supported &&
                          member.role != ChatRole.participant)
                        PopupMenuItem(
                          value: 'role',
                          child: Text(zh ? '设为参与者' : 'Make participant'),
                        ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Default grouping for applications needing a quick chat pane.
