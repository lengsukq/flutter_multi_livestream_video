import 'dart:convert';

/// Optional provider-neutral control message transport for product Chat.
///
/// Adapters that implement this keep messages out of normal chat histories and
/// ChatSession.events. They are hints only, never an authorization channel.
abstract interface class ChatSystemMessaging {
  Stream<String> get systemMessages;
  Future<void> sendSystemMessage(String payload);
}

/// Internal reserved message frame. Its body must be a versioned and validated
/// application envelope; receiving a frame never authorizes any mutation.
class ChatSystemMessageCodec {
  static const prefix = '__flutter_realtime_system_v1__:';
  static const textPrefix = '__flutter_realtime_text_v1__:';

  static String encode(String payload) {
    if (!_validEnvelope(payload)) {
      throw ArgumentError(
        'Expected a versioned revision envelope of at most 1024 characters.',
      );
    }
    return '$prefix$payload';
  }

  /// Escape user text before transport, including text that resembles an escape.
  static String encodeUserText(String content) =>
      content.startsWith(prefix) || content.startsWith(textPrefix)
      ? '$textPrefix${jsonEncode(content)}'
      : content;

  static String decodeUserText(String content) {
    if (!content.startsWith(textPrefix)) return content;
    try {
      final value = jsonDecode(content.substring(textPrefix.length));
      if (value is String &&
          (value.startsWith(prefix) || value.startsWith(textPrefix))) {
        return value;
      }
    } on FormatException {
      // Malformed reserved text is still an ordinary message.
    }
    return content;
  }

  static bool isSystemFrame(String content) => decode(content) != null;

  static String? decode(String content) {
    if (!content.startsWith(prefix)) return null;
    final payload = content.substring(prefix.length);
    return _validEnvelope(payload) ? payload : null;
  }

  static bool _validEnvelope(String payload) {
    if (payload.isEmpty || payload.length > 1024) return false;
    try {
      final value = jsonDecode(payload);
      bool shortText(Object? text) =>
          text is String && text.isNotEmpty && text.length <= 128;
      return value is Map<String, dynamic> &&
          value['v'] == 1 &&
          shortText(value['type']) &&
          shortText(value['roomCode']) &&
          shortText(value['eventId']) &&
          value['revision'] is int &&
          (value['revision'] as int) >= 0 &&
          (value['revision'] as int) <= 9007199254740991 &&
          value['timestampMs'] is int;
    } on FormatException {
      return false;
    }
  }
}
