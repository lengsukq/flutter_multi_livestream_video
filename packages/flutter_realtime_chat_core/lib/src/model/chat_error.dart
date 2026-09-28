enum ChatErrorCode {
  invalidJoinInfo,
  invalidArgument,
  invalidState,
  unauthorized,
  forbidden,
  roomNotFound,
  providerNotRegistered,
  providerNotConfigured,
  unsupportedPlatform,
  unsupportedFeature,
  network,
  timeout,
  serverError,
  nativeError,
  unknown,
}

class ChatError implements Exception {
  const ChatError({
    required this.code,
    required this.message,
    this.providerId,
    this.details,
  });

  final ChatErrorCode code;
  final String message;
  final String? providerId;
  final Object? details;

  ChatError withProvider(String providerId) => ChatError(
    code: code,
    message: message,
    providerId: this.providerId ?? providerId,
    details: details,
  );

  @override
  String toString() {
    final provider = providerId == null ? '' : ' [$providerId]';
    return 'ChatError(${code.name})$provider: $message';
  }
}
