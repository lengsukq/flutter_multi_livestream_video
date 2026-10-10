import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_example/demo_custom_interaction.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _DataMedia extends Fake
    implements MediaSession, MediaAdvancedDataMessenger {
  _DataMedia({required this.supportsData});

  final bool supportsData;
  final received = StreamController<MediaEvent>.broadcast();
  final outbound = <String>[];
  final topics = <String>[];

  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => MediaCapabilities(
    canSendData: supportsData,
    canReceiveData: supportsData,
  );
  @override
  MediaSessionState get state => MediaSessionState.connected;
  @override
  MediaSnapshot get snapshot =>
      MediaSnapshot(state: state, role: role, capabilities: capabilities);
  @override
  Stream<MediaEvent> get events => received.stream;
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();

  @override
  Future<void> sendDataMessage(
    String message, {
    MediaSendOptions options = const MediaSendOptions(),
  }) async {
    outbound.add(message);
    topics.add(options.topic);
  }

  void emitWave({
    required String transportSender,
    required String eventSender,
    String roomCode = 'wave-room',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    received.add(
      MediaMessageReceived(
        MediaMessage(
          participantId: transportSender,
          topic: InteractionEventCodec.transportTopic,
          timestampMs: now,
          message: InteractionEventCodec.encode(
            InteractionEvent(
              roomCode: roomCode,
              eventId: 'wave-$now-${outbound.length}',
              senderId: eventSender,
              topic: DemoWaveInteraction.topic,
              timestampMs: now,
              payload: const {},
            ),
          ),
        ),
      ),
    );
  }

  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() => received.close();
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

RealtimeRoom _room(_DataMedia media) => RealtimeRoom(
  media: MediaRoomSession.direct(
    roomCode: 'wave-room',
    participantId: 'self',
    session: media,
  ),
  renderer: const _Renderer(),
  disposeClients: () {},
);

void main() {
  testWidgets(
    'custom wave uses generic RTC Interaction and filters forged senders',
    (tester) async {
      final media = _DataMedia(supportsData: true);
      final room = _room(media);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DemoWaveAction(room: room, showLabel: true),
                DemoWaveOverlay(room: room),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Wave'));
      await tester.pump();
      expect(media.topics, [InteractionEventCodec.transportTopic]);
      final published = InteractionEventCodec.tryDecode(media.outbound.single);
      expect(published?.topic, DemoWaveInteraction.topic);
      expect(published?.senderId, 'self');
      // A client-supplied JSON sender is never sufficient identity evidence.
      media.emitWave(transportSender: 'remote', eventSender: 'forged');
      await tester.pump();
      expect(find.text('remote waved'), findsNothing);
      media.emitWave(
        transportSender: 'remote',
        eventSender: 'remote',
        roomCode: 'other-room',
      );
      await tester.pump();
      expect(find.text('remote waved'), findsNothing);

      media.emitWave(transportSender: 'remote', eventSender: 'remote');
      await tester.pump();
      expect(find.text('remote waved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('remote waved'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('custom wave action is disabled when RTC data cannot publish', (
    tester,
  ) async {
    final media = _DataMedia(supportsData: false);
    final room = _room(media);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DemoWaveAction(room: room, showLabel: true)),
      ),
    );
    expect(find.text('Wave'), findsOneWidget);
    await tester.tap(find.text('Wave'), warnIfMissed: false);
    await tester.pump();
    expect(media.outbound, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
