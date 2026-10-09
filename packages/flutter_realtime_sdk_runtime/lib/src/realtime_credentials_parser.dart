import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'provider_driver.dart';
import 'provider_plugin.dart';
import 'realtime_error.dart';

class RealtimeCredentialsParser {
  RealtimeCredentialsParser(
    this.plugins,
    this.driverRegistry,
    this._assertPlatformSupport,
  );
  final RealtimePluginRegistry plugins;
  final RealtimeDriverRegistry? driverRegistry;
  final void Function(String) _assertPlatformSupport;
  void _validateDeclaredMediaProvider(
    Object? declared, {
    required String requestedProvider,
    required String engineProvider,
  }) {
    final value = declared?.toString().trim().toLowerCase();
    if (value == null ||
        value.isEmpty ||
        value == requestedProvider ||
        value == engineProvider) {
      return;
    }
    final publicProvider =
        driverRegistry?.publicProviderForEngine(engineProvider) ??
        engineProvider;
    if (value == publicProvider) return;
    throw RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message:
          'Credential field "provider" declares provider "$value", '
          'but "$requestedProvider" was requested.',
      providerId: requestedProvider,
    );
  }

  MediaRoomMode? _parseRoomMode(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'meeting' => MediaRoomMode.meeting,
      'broadcast' || 'live' => MediaRoomMode.broadcast,
      null || '' => null,
      _ => throw ArgumentError('Unsupported roomMode "$normalized".'),
    };
  }

  void _validateDeclaredProvider(
    Object? declared,
    String expected, {
    required String field,
  }) {
    final value = declared?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty || value == expected) return;
    throw RealtimeException(
      code: RealtimeErrorCode.invalidArgument,
      message:
          'Credential field "$field" declares provider "$value", '
          'but "$expected" was requested.',
      providerId: expected,
    );
  }

  MediaJoinInfo parseMediaCredentials({
    required String providerId,
    required Map<String, dynamic> joinPayload,
  }) {
    final normalizedProvider = providerId.trim().toLowerCase();
    try {
      final json = Map<String, dynamic>.from(joinPayload);
      final roomMode = _parseRoomMode(json['roomMode']);
      final registry = driverRegistry;
      final engineProvider =
          registry?.resolveMediaEngine(
            providerId: normalizedProvider,
            engineId: json['engine']?.toString(),
            roomMode: roomMode,
          ) ??
          normalizedProvider;
      _assertPlatformSupport(engineProvider);
      _validateDeclaredMediaProvider(
        json['provider'],
        requestedProvider: normalizedProvider,
        engineProvider: engineProvider,
      );
      json['provider'] = engineProvider;
      json['engine'] = engineProvider;
      return plugins.media.registry.require(engineProvider).parseJoinInfo(json);
    } on ArgumentError catch (error) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: error.message?.toString() ?? error.toString(),
        providerId: normalizedProvider,
        details: error,
      );
    } catch (error) {
      throw mapRealtimeException(error, providerId: normalizedProvider);
    }
  }

  /// Parses raw Product Chat credentials through the selected SDK driver.
  ChatJoinInfo parseChatCredentials({
    required String providerId,
    required Map<String, dynamic> joinPayload,
  }) {
    final normalizedProvider = providerId.trim().toLowerCase();
    _assertPlatformSupport(normalizedProvider);
    try {
      final json = Map<String, dynamic>.from(joinPayload);
      _validateDeclaredProvider(
        json['chatProvider'],
        normalizedProvider,
        field: 'chatProvider',
      );
      json['chatProvider'] = normalizedProvider;
      return plugins.chat.require(normalizedProvider).parseJoinInfo(json);
    } catch (error) {
      throw mapRealtimeException(error, providerId: normalizedProvider);
    }
  }
}
