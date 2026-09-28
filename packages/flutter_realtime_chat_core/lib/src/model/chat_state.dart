enum ChatConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
  disposed;

  bool get isConnected => this == ChatConnectionState.connected;
  bool get isTerminal =>
      this == ChatConnectionState.failed ||
      this == ChatConnectionState.disposed;
}
