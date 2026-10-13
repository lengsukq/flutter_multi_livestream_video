import 'package:flutter/material.dart';
import 'chat_ui_scope.dart';
import 'chat_member_list.dart';

class ChatManagementButton extends StatelessWidget {
  const ChatManagementButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    if (!controller.isHost || controller.moderation == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: zh ? '管理聊天室' : 'Manage chat',
      icon: const Icon(Icons.admin_panel_settings_outlined),
      onPressed: () async {
        try {
          await controller.refreshMembers();
          if (!context.mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ChatUiScope(
              session: controller.session,
              controller: controller,
              moderation: controller.moderation,
              child: SafeArea(
                child: SizedBox(
                  height: 420,
                  child: Column(
                    children: [
                      ListTile(title: Text(zh ? '聊天室管理' : 'Chat management')),
                      const Expanded(child: ChatMemberList()),
                      if (controller.managementCapabilities.closeRoom.supported)
                        TextButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              useRootNavigator: true,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(zh ? '关闭聊天室？' : 'Close chat room?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: Text(zh ? '取消' : 'Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: Text(zh ? '关闭' : 'Close'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await controller.closeRoom();
                                if (context.mounted) Navigator.pop(context);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.maybeOf(
                                    context,
                                  )?.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.block),
                          label: Text(zh ? '关闭聊天室' : 'Close room'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
      },
    );
  }
}
