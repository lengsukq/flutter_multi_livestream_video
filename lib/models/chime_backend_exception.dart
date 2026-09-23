enum ChimeBackendErrorCode {
  invalidArgument,
  unsupportedPlatform,
  unauthorized,
  forbidden,
  roomNotFound,
  roomConflict,
  invalidRoomCode,
  timeout,
  network,
  invalidResponse,
  serverError,
  unknown,
}

/// Failure returned by, or encountered while contacting, the application
/// backend. Media-session failures continue to use `ChimeException`.
class ChimeBackendException implements Exception {
  const ChimeBackendException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final ChimeBackendErrorCode code;
  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => 'ChimeBackendException(${code.name}): $message';
}
