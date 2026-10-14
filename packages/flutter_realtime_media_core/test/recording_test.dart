import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

void main() {
  group('RecordingOptions & CloudRecordingDescriptor', () {
    test('RecordingOptions default values and factory helpers', () {
      final cloud = RecordingOptions.cloud(
        layout: RecordingLayout.speaker,
        qualityPreset: RecordingQualityPreset.fullHd1080p30,
        rawProviderParams: {'customKey': 123},
      );
      expect(cloud.mode, RecordingMode.cloud);
      expect(cloud.layout, RecordingLayout.speaker);
      expect(cloud.qualityPreset, RecordingQualityPreset.fullHd1080p30);
      expect(cloud.rawProviderParams['customKey'], 123);

      final json = cloud.toJson();
      expect(json['mode'], 'cloud');
      expect(json['layout'], 'speaker');
      expect(json['qualityPreset'], 'fullHd1080p30');
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
        expect(descriptor.endpoint, contains('api.sd-rtn.com'));
        expect(descriptor.endpoint, contains('/mode/mix/start'));
        expect(
          descriptor.suggestedHeaders['Content-Type'],
          contains('application/json'),
        );
        expect(descriptor.suggestedHeaders['Authorization'], contains('Basic'));
        expect(descriptor.documentationUrl, contains('docs.agora.io'));

        final payload = descriptor.payload;
        final parameters = payload['clientRequest'];
        expect(payload['cname'], 'room_101');
        expect(payload['uid'], '{recordingUid}');
        expect(
          parameters['recordingConfig']['transcodingConfig']['mixedVideoLayout'],
          1,
        ); // 1 = Best-Fit Grid
        expect(parameters['recordingConfig']['channelType'], 1);
        expect(parameters['recordingFileConfig']['avFileType'], ['hls', 'mp4']);
        // Deep merge check:
        expect(parameters['storageConfig']['bucket'], 'my-custom-bucket');
        expect(
          parameters['storageConfig']['vendor'],
          1,
        ); // Preserves existing vendor
        expect(parameters['extraTrackingTag'], 'agora-prod');
      },
    );

    test('Agora example query endpoint uses GET and mix, never composite', () {
      final query = CloudRecordingBlueprints.buildDescriptor(
        providerId: 'agora',
        roomCode: 'room_101',
        action: 'query',
      );
      expect(query.httpMethod, 'GET');
      expect(query.endpoint, contains('/sid/{sid}/mode/mix/query'));
      expect(query.endpoint, isNot(contains('composite')));
    });

    test('AWS Chime blueprint emits only valid webcam grid layout', () {
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
        config['ArtifactsConfiguration']['CompositedVideo']['Layout'],
        'GridView',
      );

      expect(
        () => CloudRecordingBlueprints.buildDescriptor(
          providerId: 'chime',
          roomCode: 'chime-meeting-99',
          options: RecordingOptions.cloud(
            layout: RecordingLayout.featuredParticipant,
          ),
        ),
        throwsUnsupportedError,
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
        3,
      ); // 3 = 九宫格
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
