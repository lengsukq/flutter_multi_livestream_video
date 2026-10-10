import 'dart:convert';

/// Semantics requested from a provider. Unsupported modes must fail visibly.
enum InteractionReliability { reliable, unreliable }

class InteractionCapabilities {
  const InteractionCapabilities({
    this.canPublish = false,
    this.canSubscribe = false,
    this.canTarget = false,
    this.canSendUnreliable = false,
    this.canExecuteCommands = false,
    this.canReadSnapshots = false,
    this.maxMessageBytes,
  });

  final bool canPublish;
  final bool canSubscribe;
  final bool canTarget;
  final bool canSendUnreliable;
  final bool canExecuteCommands;
  final bool canReadSnapshots;
  final int? maxMessageBytes;
}

class InteractionPublishOptions {
  const InteractionPublishOptions({
    this.targets = const [],
    this.reliability = InteractionReliability.reliable,
  });

  final List<String> targets;
  final InteractionReliability reliability;
}

/// A *transient* event, not proof of identity or permission.
///
/// [senderId] within the serialized envelope is user-provided and MUST be
/// checked against authenticated transport metadata. A received event is
/// never a substitute for a trusted command response or state snapshot.
class InteractionEvent {
  InteractionEvent({
    required this.roomCode,
    required this.eventId,
    required this.senderId,
    required this.topic,
    required this.timestampMs,
    required Map<String, Object?> payload,
    this.version = 1,
    List<String> targets = const [],
  }) : payload = Map.unmodifiable(payload),
       targets = List.unmodifiable(targets);

  final int version;
  final String roomCode;
  final String eventId;
  final String senderId;
  final String topic;
  final int timestampMs;
  final Map<String, Object?> payload;
  final List<String> targets;
}

/// JSON envelope on the reserved transport topic. Bounded, versioned and
/// validated before the runtime publishes it to consumers.
class InteractionEventCodec {
  const InteractionEventCodec._();

  static const transportTopic = 'realtime.interaction.v1';
  static const maxEnvelopeBytes = 16 * 1024;

  static final _identifier = RegExp(r'^[a-zA-Z0-9._:/-]{1,128}$');

  static String encode(InteractionEvent event) {
    _validate(event);
    final encoded = jsonEncode({
      'v': event.version,
      'roomCode': event.roomCode,
      'eventId': event.eventId,
      'senderId': event.senderId,
      'topic': event.topic,
      'timestampMs': event.timestampMs,
      'targets': event.targets,
      'payload': event.payload,
    });
    if (utf8.encode(encoded).length > maxEnvelopeBytes) {
      throw ArgumentError.value(
        encoded.length,
        'event',
        'Interaction event exceeds maximum encoded size',
      );
    }
    return encoded;
  }

  static InteractionEvent? tryDecode(String encoded) {
    if (utf8.encode(encoded).length > maxEnvelopeBytes) return null;
    try {
      final json = jsonDecode(encoded);
      if (json is! Map<String, dynamic>) return null;
      final payload = json['payload'];
      final targets = json['targets'];
      if (payload is! Map<String, dynamic> ||
          targets is! List ||
          targets.any((item) => item is! String)) {
        return null;
      }
      final event = InteractionEvent(
        version: json['v'] as int,
        roomCode: json['roomCode'] as String,
        eventId: json['eventId'] as String,
        senderId: json['senderId'] as String,
        topic: json['topic'] as String,
        timestampMs: json['timestampMs'] as int,
        payload: payload,
        targets: targets.cast<String>(),
      );
      _validate(event);
      return event;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static void _validate(InteractionEvent event) {
    if (event.version != 1 ||
        !_identifier.hasMatch(event.roomCode) ||
        !_identifier.hasMatch(event.eventId) ||
        !_identifier.hasMatch(event.senderId) ||
        !_identifier.hasMatch(event.topic) ||
        event.timestampMs <= 0 ||
        event.timestampMs > 9007199254740991 ||
        event.targets.length > 100 ||
        event.targets.any((id) => !_identifier.hasMatch(id))) {
      throw ArgumentError('Invalid interaction event envelope');
    }
  }
}

/// A command is an application-level request; its authorization never comes
/// from an event delivered over RTC Data or Chat.
class InteractionCommand {
  InteractionCommand({
    required this.operation,
    required this.requestId,
    required Map<String, Object?> arguments,
  }) : arguments = Map.unmodifiable(arguments);

  final String operation;
  final String requestId;
  final Map<String, Object?> arguments;
}

class InteractionCommandResult {
  InteractionCommandResult({
    required this.revision,
    Map<String, Object?> value = const {},
  }) : value = Map.unmodifiable(value);
  final int revision;
  final Map<String, Object?> value;
}

/// Revisioned authoritative state for late join and reconnect recovery.
class InteractionSnapshot {
  InteractionSnapshot({
    required this.revision,
    required Map<String, Object?> state,
  }) : state = Map.unmodifiable(state);
  final int revision;
  final Map<String, Object?> state;
}

/// Injected trusted backend for persistent state and privileged operations.
abstract interface class InteractionControlPlane {
  Future<InteractionSnapshot> snapshot();
  Future<InteractionCommandResult> execute(InteractionCommand command);
}

/// Authenticated transport metadata (not the JSON envelope) supplies sender.
class InteractionFrame {
  const InteractionFrame({
    required this.senderId,
    required this.topic,
    required this.content,
  });

  final String senderId;
  final String topic;
  final String content;
}

/// Provider adapter; a transport that cannot meet requested semantics rejects
/// the operation rather than silently broadcasting a targeted message.
abstract interface class InteractionTransport {
  InteractionCapabilities get capabilities;
  Stream<InteractionFrame> get frames;
  Future<void> publish(String encoded, InteractionPublishOptions options);
  Future<void> dispose();
}

/// A notification that the trusted state may have advanced. Hints received
/// over RTC or IM are never a valid command or an authoritative state change.
abstract interface class InteractionRevisionTransport {
  Stream<int> get revisions;
  Future<void> publish(int revision);
  Future<void> dispose();
}

/// UI-independent public interaction service. No provider or business types.
abstract interface class InteractionSession {
  String get roomCode;
  InteractionCapabilities get capabilities;
  Stream<InteractionEvent> get events;
  Stream<Object> get errors;

  /// Non-replaying stream; read [currentSnapshot] for a late subscriber.
  Stream<InteractionSnapshot> get snapshots;
  InteractionSnapshot? get currentSnapshot;
  Future<void> publish(
    String topic,
    Map<String, Object?> payload, {
    InteractionPublishOptions options = const InteractionPublishOptions(),
  });
  Future<InteractionSnapshot> snapshot();

  /// Reloads authoritative state, deduplicated against concurrent reloads.
  Future<InteractionSnapshot> refresh();
  Future<InteractionCommandResult> execute(InteractionCommand command);
  Future<void> dispose();
}
