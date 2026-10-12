import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

const _channel = MethodChannel('flutter_realtime_media_core/permissions');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('macOS TCC status, user request and settings use native bridge', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add('${call.method}:${call.arguments}');
          return switch (call.method) {
            'status' => 'unknown',
            'request' => 'granted',
            'openSettings' => true,
            _ => throw PlatformException(code: 'unsupported'),
          };
        });

    const probe = DefaultMediaPermissionProbe();
    expect(await probe.status(MediaPermissionKind.camera),
        MediaPermissionState.unknown);
    expect(await probe.request(MediaPermissionKind.microphone),
        MediaPermissionState.granted);
    expect(probe.canOpenAppSettings, isTrue);
    expect(await probe.openAppSettings(), isTrue);
    expect(calls[0], contains('camera'));
    expect(calls[1], contains('microphone'));
    expect(calls[2], startsWith('openSettings:'));
  });

  test('macOS denied and restricted statuses do not report as granted', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return call.method == 'request' ? 'permanentlyDenied' : 'restricted';
        });
    const probe = DefaultMediaPermissionProbe();
    expect(await probe.status(MediaPermissionKind.camera),
        MediaPermissionState.restricted);
    expect(await probe.request(MediaPermissionKind.camera),
        MediaPermissionState.permanentlyDenied);
  });

  test('macOS missing plugin remains unknown without false permission grant', () async {
    const probe = DefaultMediaPermissionProbe();
    expect(await probe.status(MediaPermissionKind.microphone),
        MediaPermissionState.unknown);
    expect(await probe.request(MediaPermissionKind.camera),
        MediaPermissionState.unknown);
    expect(await probe.openAppSettings(), isFalse);
  });
}
