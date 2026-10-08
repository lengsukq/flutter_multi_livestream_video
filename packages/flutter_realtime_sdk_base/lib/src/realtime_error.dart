import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_adapter.dart';

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
}

/// Stable application-facing failure for the high-level SDK.
class RealtimeException implements Exception {
  const RealtimeException({
    required this.code,
    required this.message,
    this.providerId,
    this.recoverable = false,
    this.suggestedAction,
    this.cause,
    this.details,
  });

  final RealtimeErrorCode code;
  final String message;
  final String? providerId;
  final bool recoverable;
  final String? suggestedAction;
  final Object? cause;
  final Object? details;

  @override
  String toString() {
    final provider = providerId == null ? '' : ' [$providerId]';
    return 'RealtimeException(${code.name})$provider: $message';
  }
}

RealtimeException mapRealtimeException(Object error, {String? providerId}) {
  if (error is RealtimeException) return error;
  if (error is RealtimeAdapterNotRegisteredError) {
    return RealtimeException(
      code: RealtimeErrorCode.providerNotRegistered,
      message: error.message,
      providerId: error.providerId,
      suggestedAction: 'register-provider',
      cause: error,
    );
  }
  if (error is MediaBackendError) {
    final code = switch (error.code) {
      MediaBackendErrorCode.invalidArgument ||
      MediaBackendErrorCode.invalidRoomCode =>
        RealtimeErrorCode.invalidArgument,
      MediaBackendErrorCode.invalidResponse =>
        RealtimeErrorCode.invalidResponse,
      MediaBackendErrorCode.unauthorized => RealtimeErrorCode.unauthorized,
      MediaBackendErrorCode.forbidden => RealtimeErrorCode.forbidden,
      MediaBackendErrorCode.roomNotFound => RealtimeErrorCode.roomNotFound,
      MediaBackendErrorCode.participantNotFound =>
        RealtimeErrorCode.participantNotFound,
      MediaBackendErrorCode.roomConflict => RealtimeErrorCode.roomConflict,
      MediaBackendErrorCode.unsupportedProvider =>
        RealtimeErrorCode.providerNotRegistered,
      MediaBackendErrorCode.unsupportedFeature =>
        RealtimeErrorCode.unsupportedFeature,
      MediaBackendErrorCode.providerNotConfigured =>
        RealtimeErrorCode.providerNotConfigured,
      MediaBackendErrorCode.network => RealtimeErrorCode.network,
      MediaBackendErrorCode.timeout => RealtimeErrorCode.timeout,
      MediaBackendErrorCode.unsupportedPlatform =>
        RealtimeErrorCode.unsupportedPlatform,
      MediaBackendErrorCode.serverError => RealtimeErrorCode.serverError,
      MediaBackendErrorCode.unknown => RealtimeErrorCode.unknown,
    };
    return RealtimeException(
      code: code,
      message: error.message,
      providerId: providerId,
      recoverable:
          code == RealtimeErrorCode.network ||
          code == RealtimeErrorCode.timeout ||
          code == RealtimeErrorCode.serverError,
      suggestedAction: _suggestedAction(code),
      cause: error,
      details: error.details,
    );
  }
  if (error is MediaError) {
    final reason = _structuredReason(error.details);
    final code = switch ((error.code, reason)) {
      (_, 'invalid-credential') => RealtimeErrorCode.invalidCredential,
      (_, 'credential-expired') => RealtimeErrorCode.credentialExpired,
      (_, 'driver-initialization-failed') =>
        RealtimeErrorCode.driverInitializationFailed,
      (_, 'web-sdk-unavailable') => RealtimeErrorCode.webSdkUnavailable,
      (MediaErrorCode.invalidJoinInfo, _) ||
      (MediaErrorCode.invalidArgument, _) => RealtimeErrorCode.invalidArgument,
      (MediaErrorCode.invalidState, _) ||
      (MediaErrorCode.sessionAlreadyActive, _) ||
      (MediaErrorCode.sessionNotFound, _) => RealtimeErrorCode.invalidState,
      (MediaErrorCode.permissionDenied, _) =>
        RealtimeErrorCode.permissionDenied,
      (MediaErrorCode.unsupportedPlatform, _) =>
        RealtimeErrorCode.unsupportedPlatform,
      (MediaErrorCode.unsupportedFeature, _) =>
        RealtimeErrorCode.unsupportedFeature,
      (MediaErrorCode.providerNotRegistered, _) =>
        RealtimeErrorCode.providerNotRegistered,
      (MediaErrorCode.nativeError, _) => RealtimeErrorCode.providerError,
      (MediaErrorCode.unknown, _) => RealtimeErrorCode.unknown,
    };
    return RealtimeException(
      code: code,
      message: error.message,
      providerId: error.providerId ?? providerId,
      recoverable: false,
      suggestedAction: _suggestedAction(code),
      cause: error,
      details: error.details,
    );
  }
  if (error is ChatError) {
    final reason = _structuredReason(error.details);
    final code = switch ((error.code, reason)) {
      (_, 'invalid-credential') => RealtimeErrorCode.invalidCredential,
      (_, 'credential-expired') => RealtimeErrorCode.credentialExpired,
      (_, 'driver-initialization-failed') =>
        RealtimeErrorCode.driverInitializationFailed,
      (_, 'web-sdk-unavailable') => RealtimeErrorCode.webSdkUnavailable,
      (ChatErrorCode.invalidJoinInfo, _) ||
      (ChatErrorCode.invalidArgument, _) => RealtimeErrorCode.invalidArgument,
      (ChatErrorCode.invalidState, _) => RealtimeErrorCode.invalidState,
      (ChatErrorCode.unauthorized, _) => RealtimeErrorCode.unauthorized,
      (ChatErrorCode.forbidden, _) => RealtimeErrorCode.forbidden,
      (ChatErrorCode.roomNotFound, _) => RealtimeErrorCode.roomNotFound,
      (ChatErrorCode.providerNotRegistered, _) =>
        RealtimeErrorCode.providerNotRegistered,
      (ChatErrorCode.providerNotConfigured, _) =>
        RealtimeErrorCode.providerNotConfigured,
      (ChatErrorCode.unsupportedPlatform, _) =>
        RealtimeErrorCode.unsupportedPlatform,
      (ChatErrorCode.unsupportedFeature, _) =>
        RealtimeErrorCode.unsupportedFeature,
      (ChatErrorCode.network, _) => RealtimeErrorCode.network,
      (ChatErrorCode.timeout, _) => RealtimeErrorCode.timeout,
      (ChatErrorCode.serverError, _) => RealtimeErrorCode.serverError,
      (ChatErrorCode.nativeError, _) => RealtimeErrorCode.providerError,
      (ChatErrorCode.unknown, _) => RealtimeErrorCode.unknown,
    };
    return RealtimeException(
      code: code,
      message: error.message,
      providerId: error.providerId ?? providerId,
      recoverable:
          code == RealtimeErrorCode.network ||
          code == RealtimeErrorCode.timeout ||
          code == RealtimeErrorCode.serverError,
      suggestedAction: _suggestedAction(code),
      cause: error,
      details: error.details,
    );
  }
  if (error is ArgumentError) {
    return RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message: error.message?.toString() ?? error.toString(),
      providerId: providerId,
      cause: error,
    );
  }
  if (error is StateError) {
    return RealtimeException(
      code: RealtimeErrorCode.invalidState,
      message: error.message,
      providerId: providerId,
      cause: error,
    );
  }
  if (error is UnsupportedError) {
    return RealtimeException(
      code: RealtimeErrorCode.unsupportedFeature,
      message: error.message?.toString() ?? error.toString(),
      providerId: providerId,
      suggestedAction: 'check-capabilities',
      cause: error,
    );
  }
  return RealtimeException(
    code: RealtimeErrorCode.unknown,
    message: error.toString(),
    providerId: providerId,
    cause: error,
  );
}

String? _suggestedAction(RealtimeErrorCode code) => switch (code) {
  RealtimeErrorCode.permissionDenied => 'request-permission',
  RealtimeErrorCode.invalidCredential ||
  RealtimeErrorCode.credentialExpired => 'refresh-provider-credentials',
  RealtimeErrorCode.driverInitializationFailed => 'retry-driver-initialization',
  RealtimeErrorCode.webSdkUnavailable => 'load-web-provider-sdk',
  RealtimeErrorCode.network ||
  RealtimeErrorCode.timeout ||
  RealtimeErrorCode.serverError => 'retry',
  RealtimeErrorCode.unauthorized => 'refresh-auth',
  RealtimeErrorCode.providerNotConfigured => 'configure-provider',
  _ => null,
};

String? _structuredReason(Object? details) {
  if (details is! Map) return null;
  return details['reason']?.toString().trim().toLowerCase();
}
