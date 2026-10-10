import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_realtime_interaction_core/flutter_realtime_interaction_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Bridges the public Interaction contract to existing provider-neutral RTC
/// data. Does not dispose the MediaSession, which belongs to its room.
class MediaInteractionTransport implements InteractionTransport {
  const MediaInteractionTransport(this.media);

  final MediaSession media;

  @override
  InteractionCapabilities get capabilities => InteractionCapabilities(
    canPublish: media.capabilities.canSendData,
    canSubscribe: media.capabilities.canReceiveData,
    canTarget: media.capabilities.canTargetData,
    canSendUnreliable: media.capabilities.canSendUnreliableData,
    maxMessageBytes: media.capabilities.maxDataMessageBytes,
  );

  @override
  Stream<InteractionFrame> get frames => media.dataMessages
      .where((message) => message.topic == InteractionEventCodec.transportTopic)
      .map(
        (message) => InteractionFrame(
          senderId: message.participantId,
          topic: message.topic,
          content: message.message,
        ),
      );

  @override
  Future<void> publish(String encoded, InteractionPublishOptions options) =>
      media.sendData(
        encoded,
        options: MediaSendOptions(
          topic: InteractionEventCodec.transportTopic,
          targetParticipantIds: options.targets,
          reliability: options.reliability == InteractionReliability.reliable
              ? MediaDataReliability.reliable
              : MediaDataReliability.unreliable,
        ),
      );

  @override
  Future<void> dispose() async {}
}

/// A simple, provider-neutral event session. The authoritative commands and
/// snapshots are available only when an app or prebuilt feature supplies a
/// trusted control plane; incoming RTC frames are NEVER applied as state.
class DefaultInteractionSession implements InteractionSession {
  DefaultInteractionSession({
    required this.roomCode,
    required this.senderId,
    required this.transport,
    this.controlPlane,
  }) {
    _subscription = transport.frames.listen(
      _receive,
      onError: (Object error, StackTrace stack) {
        if (!_disposed) _errors.add(error);
      },
    );
  }

  @override
  final String roomCode;
  final String senderId;
  final InteractionTransport transport;
  final InteractionControlPlane? controlPlane;
  final _events = StreamController<InteractionEvent>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _seenIds = <String>{};
  static final _random = Random.secure();
  late final StreamSubscription<InteractionFrame> _subscription;
  Future<void>? _disposal;
  bool _disposed = false;

  @override
  InteractionCapabilities get capabilities {
    final current = transport.capabilities;
    return InteractionCapabilities(
      canPublish: current.canPublish,
      canSubscribe: current.canSubscribe,
      canTarget: current.canTarget,
      canSendUnreliable: current.canSendUnreliable,
      maxMessageBytes: current.maxMessageBytes,
      canExecuteCommands: controlPlane != null,
      canReadSnapshots: controlPlane != null,
    );
  }

  @override
  Stream<InteractionEvent> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  void _receive(InteractionFrame frame) {
    if (_disposed ||
        frame.topic != InteractionEventCodec.transportTopic ||
        frame.senderId.isEmpty) {
      return;
    }
    final event = InteractionEventCodec.tryDecode(frame.content);
    if (event == null ||
        event.roomCode != roomCode ||
        event.senderId != frame.senderId ||
        (event.targets.isNotEmpty && !event.targets.contains(senderId))) {
      return;
    }
    final key = '${event.senderId}/${event.eventId}';
    if (!_seenIds.add(key)) return;
    if (_seenIds.length > 512) _seenIds.remove(_seenIds.first);
    _events.add(event);
  }

  @override
  Future<void> publish(
    String topic,
    Map<String, Object?> payload, {
    InteractionPublishOptions options = const InteractionPublishOptions(),
  }) async {
    if (_disposed) throw StateError('Interaction session is disposed');
    final current = capabilities;
    if (!current.canPublish ||
        (options.targets.isNotEmpty && !current.canTarget) ||
        (options.reliability == InteractionReliability.unreliable &&
            !current.canSendUnreliable)) {
      throw UnsupportedError('Requested interaction delivery is unavailable');
    }
    final event = InteractionEvent(
      roomCode: roomCode,
      eventId:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
      senderId: senderId,
      topic: topic,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
      targets: options.targets,
    );
    final encoded = InteractionEventCodec.encode(event);
    if (current.maxMessageBytes != null &&
        utf8.encode(encoded).length > current.maxMessageBytes!) {
      throw ArgumentError('Interaction event exceeds provider limit');
    }
    await transport.publish(encoded, options);
  }

  @override
  Future<InteractionSnapshot> snapshot() async {
    if (_disposed) throw StateError('Interaction session is disposed');
    final plane = controlPlane;
    if (plane == null) {
      throw UnsupportedError('No authoritative interaction control plane');
    }
    return await plane.snapshot();
  }

  @override
  Future<InteractionCommandResult> execute(InteractionCommand command) async {
    if (_disposed) throw StateError('Interaction session is disposed');
    final plane = controlPlane;
    if (plane == null) {
      throw UnsupportedError('No authoritative interaction control plane');
    }
    return await plane.execute(command);
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription.cancel();
    await transport.dispose();
    await _events.close();
    await _errors.close();
  }
}
