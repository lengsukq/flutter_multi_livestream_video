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
    final code = switch (error.code) {
      MediaErrorCode.invalidJoinInfo ||
      MediaErrorCode.invalidArgument => RealtimeErrorCode.invalidArgument,
      MediaErrorCode.invalidState ||
      MediaErrorCode.sessionAlreadyActive ||
      MediaErrorCode.sessionNotFound => RealtimeErrorCode.invalidState,
      MediaErrorCode.permissionDenied => RealtimeErrorCode.permissionDenied,
      MediaErrorCode.unsupportedPlatform =>
        RealtimeErrorCode.unsupportedPlatform,
      MediaErrorCode.unsupportedFeature => RealtimeErrorCode.unsupportedFeature,
      MediaErrorCode.providerNotRegistered =>
        RealtimeErrorCode.providerNotRegistered,
      MediaErrorCode.nativeError => RealtimeErrorCode.providerError,
      MediaErrorCode.unknown => RealtimeErrorCode.unknown,
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
    final code = switch (error.code) {
      ChatErrorCode.invalidJoinInfo ||
      ChatErrorCode.invalidArgument => RealtimeErrorCode.invalidArgument,
      ChatErrorCode.invalidState => RealtimeErrorCode.invalidState,
      ChatErrorCode.unauthorized => RealtimeErrorCode.unauthorized,
      ChatErrorCode.forbidden => RealtimeErrorCode.forbidden,
      ChatErrorCode.roomNotFound => RealtimeErrorCode.roomNotFound,
      ChatErrorCode.providerNotRegistered =>
        RealtimeErrorCode.providerNotRegistered,
      ChatErrorCode.providerNotConfigured =>
        RealtimeErrorCode.providerNotConfigured,
      ChatErrorCode.unsupportedPlatform =>
        RealtimeErrorCode.unsupportedPlatform,
      ChatErrorCode.unsupportedFeature => RealtimeErrorCode.unsupportedFeature,
      ChatErrorCode.network => RealtimeErrorCode.network,
      ChatErrorCode.timeout => RealtimeErrorCode.timeout,
      ChatErrorCode.serverError => RealtimeErrorCode.serverError,
      ChatErrorCode.nativeError => RealtimeErrorCode.providerError,
      ChatErrorCode.unknown => RealtimeErrorCode.unknown,
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
  return RealtimeException(
    code: RealtimeErrorCode.unknown,
    message: error.toString(),
    providerId: providerId,
    cause: error,
  );
}

String? _suggestedAction(RealtimeErrorCode code) => switch (code) {
  RealtimeErrorCode.permissionDenied => 'request-permission',
  RealtimeErrorCode.network ||
  RealtimeErrorCode.timeout ||
  RealtimeErrorCode.serverError => 'retry',
  RealtimeErrorCode.unauthorized => 'refresh-auth',
  RealtimeErrorCode.providerNotConfigured => 'configure-provider',
  _ => null,
};
