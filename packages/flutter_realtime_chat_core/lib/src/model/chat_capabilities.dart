import 'chat_management_capability.dart';

class ChatCapabilities {
  const ChatCapabilities({
    this.canSendMessage = false,
    this.canDeleteMessage = false,
    this.canDisconnectUser = false,
    this.canStandalone = true,
    this.canReconnect = true,
    this.canLoadHistory = false,
    this.management,
  });

  const ChatCapabilities.none()
    : canSendMessage = false,
      canDeleteMessage = false,
      canDisconnectUser = false,
      canStandalone = false,
      canReconnect = false,
      canLoadHistory = false,
      management = null;

  final bool canSendMessage;
  final bool canDeleteMessage;
  final bool canDisconnectUser;
  final bool canStandalone;
  final bool canReconnect;
  final bool canLoadHistory;
  final ChatManagementCapabilities? management;

  ChatManagementCapabilities get managementCapabilities =>
      management ??
      ChatManagementCapabilities(
        removeMember: canDisconnectUser
            ? const ChatManagementCapability.client()
            : const ChatManagementCapability.unsupported(),
        deleteMessage: canDeleteMessage
            ? const ChatManagementCapability.client()
            : const ChatManagementCapability.unsupported(),
      );
}
