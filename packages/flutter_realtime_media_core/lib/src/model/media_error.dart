/// Stable error codes raised by media session operations.
///
/// Codes are part of the public contract and must not be renamed: applications
/// branch on them. Provider adapters translate native SDK failures into one of
/// these codes instead of leaking SDK-specific types.
enum MediaErrorCode {
  /// Join information is malformed or missing required provider fields.
  invalidJoinInfo,

  /// A method argument is invalid.
  invalidArgument,

  /// The operation is not valid for the current session state.
  invalidState,

  /// Microphone or camera permission was denied or restricted.
  permissionDenied,

  /// Media APIs were called on a platform without a provider implementation.
  unsupportedPlatform,

  /// The provider or the session role does not support this feature.
  unsupportedFeature,

  /// Another media session is already active and the provider allows only one.
  sessionAlreadyActive,

  /// The native session has already ended or is unavailable.
  sessionNotFound,

  /// The requested provider id is not registered in the [MediaRegistry].
  providerNotRegistered,

  /// The native SDK returned an unclassified failure.
  nativeError,

  /// An unexpected Dart-side failure with no better classification.
  unknown,
}

/// Typed failure raised by media session operations.
class MediaError implements Exception {
  const MediaError({
    required this.code,
    required this.message,
    this.details,
    this.providerId,
  });

  /// Stable machine-readable code.
  final MediaErrorCode code;

  /// Human-readable description.
  final String message;

  /// Optional native or adapter payload for diagnostics.
  final Object? details;

  /// Provider that raised the failure, when known.
  final String? providerId;

  /// Returns a copy with additional context filled in when it was missing.
  MediaError withProvider(String provider) => MediaError(
    code: code,
    message: message,
    details: details,
    providerId: providerId ?? provider,
  );

  @override
  String toString() {
    final provider = providerId == null ? '' : ' [$providerId]';
    return 'MediaError(${code.name})$provider: $message';
  }
}
