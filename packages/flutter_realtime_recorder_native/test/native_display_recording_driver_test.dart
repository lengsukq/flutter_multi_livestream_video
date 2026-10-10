import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_recorder_native/flutter_realtime_recorder_native.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_realtime_recorder_native_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native recorder delegates to platform and exposes real file metadata',
    () async {
      final called = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        called.add(call.method);
        if (call.method == 'start') {
          expect((call.arguments as Map)['roomCode'], 'meeting-1');
          return {
            'localFilePath': '/sandbox/meeting-1.mp4',
            'fileName': 'meeting-1.mp4',
          };
        }
        return {
          'localFilePath': '/sandbox/meeting-1.mp4',
          'fileName': 'meeting-1.mp4',
          'fileSizeBytes': 16384,
          'durationMs': 2500,
          'hasVideo': true,
          'hasAudio': false,
        };
      });
      final driver = NativeDisplayRecordingDriver(
        roomCode: 'meeting-1',
        channel: channel,
      );
      final started = await driver.startLocalRecording(
        RecordingOptions.local(),
      );
      expect(started.localFilePath, '/sandbox/meeting-1.mp4');
      await expectLater(
        driver.startLocalRecording(RecordingOptions.local()),
        throwsStateError,
      );
      final stopped = await driver.stopLocalRecording();
      expect(stopped.fileSizeBytes, 16384);
      expect(stopped.duration.inMilliseconds, 2500);
      expect(stopped.mimeType, 'video/mp4');
      expect(stopped.metadata['hasAudio'], false);
      expect(called, ['start', 'stop']);
    },
  );

  test(
    'native driver rejects unsuitable recording options before native call',
    () async {
      final driver = NativeDisplayRecordingDriver(
        roomCode: 'meeting-2',
        channel: channel,
      );
      await expectLater(
        driver.startLocalRecording(
          RecordingOptions.local(streamType: RecordingStreamType.audioOnly),
        ),
        throwsUnsupportedError,
      );
      await expectLater(
        driver.startLocalRecording(
          RecordingOptions.local(localFilePath: '/tmp/other.mp4'),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'a failed native start does not leave a recording marked active',
    () async {
      var attempts = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        attempts++;
        throw PlatformException(
          code: 'permissionDenied',
          message: 'Access denied',
        );
      });
      final driver = NativeDisplayRecordingDriver(
        roomCode: 'meeting-3',
        channel: channel,
      );
      await expectLater(
        driver.startLocalRecording(RecordingOptions.local()),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        driver.startLocalRecording(RecordingOptions.local()),
        throwsA(isA<PlatformException>()),
      );
      expect(attempts, 2);
    },
  );

  test('exports finalized local artifacts via platform file picker', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'content://documents/recording.mp4';
    });
    final driver = NativeDisplayRecordingDriver(
      roomCode: 'meeting-export',
      channel: channel,
    );
    const completed = RecordingResult(
      mode: RecordingMode.local,
      localFilePath: '/private/recordings/meeting.mp4',
      fileSizeBytes: 1024,
    );
    expect(
      await driver.exportRecording(completed),
      'content://documents/recording.mp4',
    );
    expect(calls.single.method, 'export');
    expect(
      (calls.single.arguments as Map)['localFilePath'],
      completed.localFilePath,
    );
    await expectLater(
      driver.exportRecording(const RecordingResult(mode: RecordingMode.local)),
      throwsArgumentError,
    );
    expect(calls.length, 1);
  });
}
