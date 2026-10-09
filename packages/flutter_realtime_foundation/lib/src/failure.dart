enum RealtimeErrorCode {
  invalidArgument,
  invalidState,
  invalidResponse,
  unauthorized,
  forbidden,
  roomNotFound,
  roomConflict,
  participantNotFound,
  providerNotRegistered,
  providerNotConfigured,
  unsupportedPlatform,
  unsupportedFeature,
  invalidCredential,
  credentialExpired,
  driverInitializationFailed,
  webSdkUnavailable,
  permissionDenied,
  network,
  timeout,
  serverError,
  providerError,
  unknown,
  cancelled,
  cleanupFailed,
}

/// Application-facing failure shared by every SDK domain.
class RealtimeException implements Exception {
  const RealtimeException({
    required this.code,
    required this.message,
    this.domain,
    this.operation,
    this.providerId,
    this.statusCode,
    this.recoverable = false,
    this.suggestedAction,
    this.cause,
    this.details,
    this.stackTrace,
  });
  final RealtimeErrorCode code;
  final String message;
  final String? domain, operation, providerId;
  final int? statusCode;
  final bool recoverable;
  final String? suggestedAction;
  final Object? cause, details;
  final StackTrace? stackTrace;

  RealtimeException withProvider(String provider) => RealtimeException(
    code: code,
    message: message,
    domain: domain,
    operation: operation,
    providerId: providerId ?? provider,
    statusCode: statusCode,
    recoverable: recoverable,
    suggestedAction: suggestedAction,
    cause: cause,
    details: details,
    stackTrace: stackTrace,
  );

  @override
  String toString() =>
      'RealtimeException(${code.name})'
      '${providerId == null ? '' : ' [$providerId]'}: $message';
}

RealtimeException normalizeRealtimeException(
  Object error, {
  String? domain,
  String? operation,
  String? providerId,
  StackTrace? stackTrace,
}) {
  if (error is RealtimeException) {
    final details = error.details;
    final reason = details is Map ? details['reason'] : null;
    final code = switch (reason) {
      'invalid-credential' => RealtimeErrorCode.invalidCredential,
      'credential-expired' => RealtimeErrorCode.credentialExpired,
      'driver-initialization-failed' =>
        RealtimeErrorCode.driverInitializationFailed,
      'web-sdk-unavailable' => RealtimeErrorCode.webSdkUnavailable,
      _ => error.code,
    };
    return RealtimeException(
      code: code,
      message: error.message,
      providerId: error.providerId ?? providerId,
      domain: error.domain ?? domain,
      operation: error.operation ?? operation,
      statusCode: error.statusCode,
      recoverable:
          error.recoverable ||
          {
            RealtimeErrorCode.network,
            RealtimeErrorCode.timeout,
            RealtimeErrorCode.serverError,
          }.contains(code),
      suggestedAction:
          error.suggestedAction ??
          switch (code) {
            RealtimeErrorCode.invalidCredential ||
            RealtimeErrorCode.credentialExpired =>
              'refresh-provider-credentials',
            RealtimeErrorCode.network ||
            RealtimeErrorCode.timeout ||
            RealtimeErrorCode.serverError => 'retry',
            RealtimeErrorCode.unsupportedFeature => 'check-capabilities',
            RealtimeErrorCode.webSdkUnavailable => 'load-web-provider-sdk',
            RealtimeErrorCode.driverInitializationFailed =>
              'retry-driver-initialization',
            RealtimeErrorCode.permissionDenied => 'request-permission',
            _ => null,
          },
      cause: error.cause ?? error,
      details: error.details,
      stackTrace: error.stackTrace ?? stackTrace,
    );
  }
  final code = switch (error) {
    ArgumentError() => RealtimeErrorCode.invalidArgument,
    StateError() => RealtimeErrorCode.invalidState,
    UnsupportedError() => RealtimeErrorCode.unsupportedFeature,
    _ => RealtimeErrorCode.providerError,
  };
  return RealtimeException(
    code: code,
    message: 'The ${operation ?? 'SDK operation'} failed.',
    domain: domain,
    operation: operation,
    providerId: providerId,
    cause: error,
    suggestedAction: code == RealtimeErrorCode.unsupportedFeature
        ? 'check-capabilities'
        : null,
    stackTrace: stackTrace,
  );
}
