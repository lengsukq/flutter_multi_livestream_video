part of 'agora_media_session.dart';

/// Maps vendor failures without printing native payloads through the API.
class _AgoraFailures {
  const _AgoraFailures(this.providerId);
  final String providerId;
  RealtimeException map(Object error, String stage, {StackTrace? stack}) {
    final typed = error is RealtimeException ? error : null;
    return normalizeRealtimeException(
      RealtimeException(
        code:
            (typed?.code == RealtimeErrorCode.unknown ? null : typed?.code) ??
            (error is TimeoutException
                ? RealtimeErrorCode.timeout
                : RealtimeErrorCode.providerError),
        message: 'agora.$stage failed.',
        providerId: providerId,
        domain: 'media',
        operation: stage,
        cause: typed?.cause ?? error,
        details: typed?.details,
        statusCode: typed?.statusCode,
        recoverable: typed?.recoverable ?? false,
        suggestedAction: typed?.suggestedAction,
        stackTrace: stack ?? typed?.stackTrace,
      ),
      providerId: providerId,
      domain: 'media',
      operation: stage,
      stackTrace: stack,
    );
  }
}
