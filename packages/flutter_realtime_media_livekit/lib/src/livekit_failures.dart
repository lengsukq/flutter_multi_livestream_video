part of 'livekit_media_session.dart';

class _LiveKitFailures {
  const _LiveKitFailures(this.providerId);
  final String providerId;
  RealtimeException map(
    Object error,
    String stage, {
    String? operation,
    StackTrace? stackTrace,
  }) {
    final failureStage = operation ?? stage;
    if (error is RealtimeException) {
      return normalizeRealtimeException(
        RealtimeException(
          code: error.code == RealtimeErrorCode.unknown
              ? RealtimeErrorCode.providerError
              : error.code,
          message: 'livekit.$failureStage failed.',
          providerId: providerId,
          domain: 'media',
          operation: failureStage,
          cause: error.cause ?? error,
          details: error.details,
          statusCode: error.statusCode,
          recoverable: error.recoverable,
          suggestedAction: error.suggestedAction,
          stackTrace: error.stackTrace ?? stackTrace,
        ),
        domain: 'media',
        operation: failureStage,
        providerId: providerId,
        stackTrace: stackTrace,
      );
    }
    final status = error is lk.ConnectException && error.statusCode != 0
        ? error.statusCode
        : null;
    final code = switch (error) {
      lk.ConnectException(statusCode: 401) =>
        RealtimeErrorCode.invalidCredential,
      lk.ConnectException(statusCode: 403) =>
        RealtimeErrorCode.permissionDenied,
      lk.ConnectException(reason: lk.ConnectionErrorReason.Timeout) ||
      lk.TimeoutException() ||
      TimeoutException() => RealtimeErrorCode.timeout,
      lk.ConnectException() ||
      lk.MediaConnectException() ||
      lk.CertificatePinningException() => RealtimeErrorCode.network,
      MissingPluginException() => RealtimeErrorCode.driverInitializationFailed,
      lk.UnexpectedStateException() ||
      StateError() => RealtimeErrorCode.invalidState,
      _ => RealtimeErrorCode.providerError,
    };
    return normalizeRealtimeException(
      RealtimeException(
        code: code,
        message: 'livekit.$failureStage failed.',
        cause: error,
        details: {
          'causeType': error.runtimeType.toString(),
          if (error is lk.ConnectException)
            'connectionReason': error.reason.name,
        },
        statusCode: status,
      ),
      domain: 'media',
      operation: failureStage,
      providerId: providerId,
      stackTrace: stackTrace,
    );
  }
}
