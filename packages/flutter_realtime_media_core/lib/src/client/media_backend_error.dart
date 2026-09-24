/// Stable error codes raised by the backend convenience layer.
enum MediaBackendErrorCode {
  /// A method argument is invalid.
  invalidArgument,

  /// The backend response was malformed or used an unsupported contract.
  invalidResponse,

  /// The backend rejected the application token (HTTP 401).
  unauthorized,

  /// The backend refused the operation (HTTP 403).
  forbidden,

  /// The room does not exist (HTTP 404).
  roomNotFound,

  /// The room already exists (HTTP 409).
  roomConflict,

  /// The room code is invalid (HTTP 400).
  invalidRoomCode,

  /// The backend does not implement the requested provider (HTTP 400).
  unsupportedProvider,

  /// The backend has no credentials configured for the requested provider
  /// (HTTP 503).
  providerNotConfigured,

  /// The HTTP request could not be completed.
  network,

  /// The HTTP request timed out.
  timeout,

  /// The backend convenience layer is not available on this platform.
  unsupportedPlatform,

  /// The backend returned a 5xx failure.
  serverError,

  /// An unexpected failure with no better classification.
  unknown,
}

/// Typed failure raised by `MediaBackendClient` and `MediaRoomSession`.
class MediaBackendError implements Exception {
  const MediaBackendError({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final MediaBackendErrorCode code;
  final String message;

  /// HTTP status code when the failure came from a response.
  final int? statusCode;

  /// Optional decoded error payload.
  final Object? details;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'MediaBackendError(${code.name})$status: $message';
  }
}
