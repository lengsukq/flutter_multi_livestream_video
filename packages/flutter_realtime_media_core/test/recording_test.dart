import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

void main() {
  group('RecordingOptions & CloudRecordingDescriptor', () {
    test('RecordingOptions default values and factory helpers', () {
      final cloud = RecordingOptions.cloud(
        layout: RecordingLayout.speaker,
        rawProviderParams: {'customKey': 123},
      );
      expect(cloud.mode, RecordingMode.cloud);
      expect(cloud.layout, RecordingLayout.speaker);
      expect(cloud.rawProviderParams['customKey'], 123);

      final json = cloud.toJson();
      expect(json['mode'], 'cloud');
      expect(json['layout'], 'speaker');
      expect(json['rawProviderParams']['customKey'], 123);
    });

    test(
      'Agora blueprint generates complete REST API contract and merges rawProviderParams',
      () {
        final descriptor = CloudRecordingBlueprints.buildDescriptor(
          providerId: 'agora',
          roomCode: 'room_101',
          participantId: 'user_888',
          options: RecordingOptions.cloud(
            layout: RecordingLayout.grid,
            rawProviderParams: {
              'storageConfig': {'bucket': 'my-custom-bucket'},
              'extraTrackingTag': 'agora-prod',
            },
          ),
        );

        expect(descriptor.providerId, 'agora');
        expect(descriptor.action, 'start');
        expect(descriptor.httpMethod, 'POST');
        expect(descriptor.endpoint, contains('api.agora.io'));
        expect(
          descriptor.suggestedHeaders['Content-Type'],
          contains('application/json'),
        );
        expect(descriptor.suggestedHeaders['Authorization'], contains('Basic'));
        expect(descriptor.documentationUrl, contains('shengwang.cn'));

        final payload = descriptor.payload;
        expect(payload['cname'], 'room_101');
        expect(payload['uid'], 'user_888');
        expect(
          payload['recordingConfig']['transcodingConfig']['mixedVideoLayout'],
          1,
        ); // 1 = Best-Fit Grid
        // Deep merge check:
        expect(payload['storageConfig']['bucket'], 'my-custom-bucket');
        expect(
          payload['storageConfig']['vendor'],
          1,
        ); // Preserves existing vendor
        expect(payload['extraTrackingTag'], 'agora-prod');
      },
    );

    test('AWS Chime blueprint maps grid and speaker layouts properly', () {
      final gridDescriptor = CloudRecordingBlueprints.buildDescriptor(
        providerId: 'chime',
        roomCode: 'chime-meeting-99',
        options: RecordingOptions.cloud(
          layout: RecordingLayout.grid,
          rawProviderParams: {
            'SinkArn': 'arn:aws:s3:::my-production-chime-bucket',
          },
        ),
      );

      expect(gridDescriptor.providerId, 'chime');
      expect(gridDescriptor.endpoint, contains('media-pipelines-chime'));
      expect(gridDescriptor.payload['SourceArn'], contains('chime-meeting-99'));
      expect(
        gridDescriptor.payload['SinkArn'],
        'arn:aws:s3:::my-production-chime-bucket',
      );
      final config = gridDescriptor.payload['ChimeSdkMeetingConfiguration'];
      expect(
        config['CompositedVideoArtifactsConfiguration']['Layout'],
        'GridView',
      );

      final speakerDescriptor = CloudRecordingBlueprints.buildDescriptor(
        providerId: 'chime',
        roomCode: 'chime-meeting-99',
        options: RecordingOptions.cloud(layout: RecordingLayout.speaker),
      );
      final speakerConfig =
          speakerDescriptor.payload['ChimeSdkMeetingConfiguration'];
      expect(
        speakerConfig['CompositedVideoArtifactsConfiguration']['Layout'],
        'ActiveSpeakerOnly',
      );
    });

    test('Tencent TRTC blueprint maps layout mode and mixes payload', () {
      final descriptor = CloudRecordingBlueprints.buildDescriptor(
        providerId: 'trtc',
        roomCode: 'room_tencent',
        participantId: 'bot_trtc',
        options: RecordingOptions.cloud(
          layout: RecordingLayout.grid,
          rawProviderParams: {'SdkAppId': 1409999999},
        ),
      );

      expect(descriptor.providerId, 'trtc');
      expect(descriptor.endpoint, 'https://trtc.tencentcloudapi.com');
      expect(descriptor.payload['SdkAppId'], 1409999999);
      expect(descriptor.payload['RoomId'], 'room_tencent');
      expect(descriptor.payload['UserId'], 'bot_trtc');
      expect(
        descriptor.payload['MixLayoutParams']['MixLayoutMode'],
        2,
      ); // 2 = 九宫格
    });

    test('LiveKit blueprint maps Egress twirp API and layout correctly', () {
      final descriptor = CloudRecordingBlueprints.buildDescriptor(
        providerId: 'livekit',
        roomCode: 'livekit_room',
        options: RecordingOptions.cloud(
          layout: RecordingLayout.grid,
          rawProviderParams: {'customEgressOption': true},
        ),
      );

      expect(descriptor.providerId, 'livekit');
      expect(descriptor.endpoint, contains('StartEgress'));
      expect(descriptor.payload['room_name'], 'livekit_room');
      expect(descriptor.payload['template']['layout'], 'grid');
      expect(descriptor.payload['customEgressOption'], true);
    });

    test('Alibaba ARTC blueprint formats MPU task parameters', () {
      final descriptor = CloudRecordingBlueprints.buildDescriptor(
        providerId: 'artc',
        roomCode: 'artc_room_1',
      );

      expect(descriptor.providerId, 'artc');
      expect(descriptor.payload['Action'], 'StartMPUTask');
      expect(descriptor.payload['ChannelId'], 'artc_room_1');
    });
  });
}
