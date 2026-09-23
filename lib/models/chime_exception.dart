/// Stable error categories exposed by [ChimeMeetingSession].
enum ChimeErrorCode {
  invalidJoinInfo,
  invalidArgument,
  invalidState,
  meetingAlreadyActive,
  permissionDenied,
  unsupportedPlatform,
  sessionNotFound,
  methodNotImplemented,
  nativeError,
  unknown,
}

/// Failure returned by a Chime meeting operation.
class ChimeException implements Exception {
  const ChimeException({
    required this.code,
    required this.message,
    this.details,
  });

  final ChimeErrorCode code;
  final String message;
  final Object? details;

  @override
  String toString() => 'ChimeException(${code.name}): $message';
}
