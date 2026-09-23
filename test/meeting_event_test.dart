import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';
import 'package:flutter_aws_chime/handlers/method_channel_coordinator.dart';
import 'package:flutter_aws_chime/handlers/response_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.oneplusdream.aws.chime.methodChannel');
  final coordinator = MethodChannelCoordinator();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('parses meeting lifecycle events and status codes', () {
    final event = ChimeEvent.fromJson({
      'type': 'audioSessionStopped',
      'statusCode': 'MeetingEnded',
    });

    expect(event, isA<MeetingSessionEvent>());
    final sessionEvent = event! as MeetingSessionEvent;
    expect(sessionEvent.kind, MeetingSessionEventKind.audioStopped);
    expect(sessionEvent.statusCode, 'MeetingEnded');

    final reconnectEvent =
        ChimeEvent.fromJson({
              'type': 'audioSessionStarted',
              'reconnecting': true,
            })!
            as MeetingSessionEvent;
    expect(reconnectEvent.kind, MeetingSessionEventKind.audioStarted);
    expect(reconnectEvent.reconnecting, isTrue);
  });

  test('parses attendee volume and signal strength updates', () {
    final volume =
        ChimeEvent.fromJson({
              'type': 'attendeeVolumeChanged',
              'attendeeId': 'attendee-1',
              'externalUserId': 'user-1',
              'volumeLevel': 'NOT_SPEAKING',
            })!
            as AttendeeVolumeEvent;
    expect(volume.attendeeId, 'attendee-1');
    expect(volume.volumeLevel, MeetingVolumeLevel.notSpeaking);

    final signal =
        ChimeEvent.fromJson({
              'type': 'attendeeSignalStrengthChanged',
              'attendeeId': 'attendee-1',
              'externalUserId': 'user-1',
              'signalStrength': 'SignalStrength.high',
            })!
            as AttendeeSignalStrengthEvent;
    expect(signal.signalStrength, MeetingSignalStrength.high);
  });

  test('parses video tile updates and ignores unknown event types', () {
    final event =
        ChimeEvent.fromJson({
              'type': 'videoTileSizeChanged',
              'videoTile': {
                'tileId': 7,
                'attendeeId': 'attendee-1',
                'videoStreamContentWidth': 640,
                'videoStreamContentHeight': 360,
                'isLocalTile': false,
                'isContent': false,
              },
            })!
            as VideoTileEvent;
    expect(event.kind, VideoTileEventKind.sizeChanged);
    expect(event.videoTile.tileId, 7);
    expect(event.videoTile.videoStreamContentWidth, 640);
    expect(ChimeEvent.fromJson({'type': 'futureEvent'}), isNull);
  });

  test('pushes native events through the shared typed event stream', () async {
    final nextEvent = coordinator.events.first;
    await coordinator.methodCallHandler(
      const MethodCall(MethodCallOption.meetingEvent, {
        'type': 'connectionBecamePoor',
      }),
    );

    final event = await nextEvent;
    expect(event, isA<ConnectionQualityEvent>());
    expect((event as ConnectionQualityEvent).quality, ConnectionQuality.poor);
  });

  test(
    'switchCamera sends the typed camera position and returns native result',
    () async {
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return {'result': true, 'arguments': 'back'};
          });

      expect(await MeetingModel().switchCamera(CameraPosition.back), isTrue);
      expect(receivedCall?.method, MethodCallOption.setCameraPosition);
      expect(receivedCall?.arguments, {'position': 'back'});
    },
  );

  test('switchCamera reports native failures as false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'Failed');
        });

    expect(await MeetingModel().switchCamera(CameraPosition.front), isFalse);
  });

  test(
    'legacy message method keeps its existing method-channel payload',
    () async {
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return {'result': true, 'arguments': 'sent'};
          });

      expect(await MeetingModel().sendMessage('hello'), isTrue);
      expect(receivedCall?.method, MethodCallOption.sendMessage);
      expect(receivedCall?.arguments, {
        'topic': 'chat',
        'message': 'hello',
        'lifetimeMs': null,
      });
    },
  );
}
