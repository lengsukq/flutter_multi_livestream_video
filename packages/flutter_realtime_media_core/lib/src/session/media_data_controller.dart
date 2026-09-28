import 'dart:convert';

import '../model/media_error.dart';
import '../model/media_event.dart';
import '../model/media_message.dart';
import '../model/media_send_options.dart';
import 'interactive_media_session.dart';
import 'media_session.dart';

abstract interface class MediaAdvancedDataMessenger {
  Future<void> sendDataMessage(
    String message, {
    MediaSendOptions options = const MediaSendOptions(),
  });
}

/// Provider-neutral inbound realtime-data surface.
///
/// Adapters continue to emit [MediaMessageReceived] on [MediaSession.events].
/// This extension exposes the same events as a dedicated message stream so
/// product integrations do not need to inspect the generic event stream.
extension MediaSessionDataReceive on MediaSession {
  /// Incoming realtime data messages, in provider delivery order.
  Stream<MediaMessage> get dataMessages => events
      .where((event) => event is MediaMessageReceived)
      .cast<MediaMessageReceived>()
      .map((event) => event.message);

  /// True only when this session can both send and receive realtime data.
  bool get supportsBidirectionalData =>
      capabilities.canSendData && capabilities.canReceiveData;
}

/// Optional hook for adapters whose provider limit applies to an encoded
/// envelope rather than the raw application message.
abstract interface class MediaDataPayloadSizer {
  int dataPayloadSizeBytes(String message, MediaSendOptions options);
}

extension MediaSessionDataControl on MediaSession {
  Future<void> sendData(
    String message, {
    MediaSendOptions options = const MediaSendOptions(),
  }) {
    if (!capabilities.canSendData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Data messages are not supported for this session.',
        providerId: providerId,
      );
    }
    if (message.trim().isEmpty || options.topic.trim().isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message and topic must not be empty.',
        providerId: providerId,
      );
    }
    final maxBytes = capabilities.maxDataMessageBytes;
    final current = this;
    final payloadBytes = current is MediaDataPayloadSizer
        ? (current as MediaDataPayloadSizer).dataPayloadSizeBytes(
            message,
            options,
          )
        : utf8.encode(message).length;
    if (maxBytes != null && payloadBytes > maxBytes) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Data message exceeds the provider payload-size limit.',
        providerId: providerId,
      );
    }
    if (!options.isBroadcast && !capabilities.canTargetData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Targeted data messages are not supported.',
        providerId: providerId,
      );
    }
    if (options.reliability == MediaDataReliability.unreliable &&
        !capabilities.canSendUnreliableData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Unreliable data delivery is not supported.',
        providerId: providerId,
      );
    }
    if (!options.ordered && !capabilities.canSendUnorderedData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Unordered data delivery is not supported.',
        providerId: providerId,
      );
    }
    if (current is MediaAdvancedDataMessenger) {
      return (current as MediaAdvancedDataMessenger).sendDataMessage(
        message,
        options: options,
      );
    }
    if (current is MediaDataMessenger &&
        options.isBroadcast &&
        options.reliability == MediaDataReliability.reliable &&
        options.ordered) {
      return (current as MediaDataMessenger).sendMessage(
        message,
        topic: options.topic,
      );
    }
    throw MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message: 'The requested data delivery mode is not implemented.',
      providerId: providerId,
    );
  }
}
