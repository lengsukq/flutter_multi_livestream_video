class ChatCapabilities {
  const ChatCapabilities({
    this.canSendMessage = false,
    this.canDeleteMessage = false,
    this.canDisconnectUser = false,
  });

  const ChatCapabilities.none()
    : canSendMessage = false,
      canDeleteMessage = false,
      canDisconnectUser = false;

  final bool canSendMessage;
  final bool canDeleteMessage;
  final bool canDisconnectUser;
}
