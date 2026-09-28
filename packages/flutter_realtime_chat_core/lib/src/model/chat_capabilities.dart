class ChatCapabilities {
  const ChatCapabilities({
    this.canSendMessage = false,
    this.canDeleteMessage = false,
    this.canDisconnectUser = false,
    this.canStandalone = true,
    this.canReconnect = true,
    this.canLoadHistory = false,
  });

  const ChatCapabilities.none()
    : canSendMessage = false,
      canDeleteMessage = false,
      canDisconnectUser = false,
      canStandalone = false,
      canReconnect = false,
      canLoadHistory = false;

  final bool canSendMessage;
  final bool canDeleteMessage;
  final bool canDisconnectUser;
  final bool canStandalone;
  final bool canReconnect;
  final bool canLoadHistory;
}
