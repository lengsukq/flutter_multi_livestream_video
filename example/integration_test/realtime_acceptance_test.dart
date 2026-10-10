import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _backend = String.fromEnvironment('ACCEPTANCE_BACKEND_URL');
const _roomCode = String.fromEnvironment('ACCEPTANCE_ROOM_CODE');
const _provider = String.fromEnvironment('ACCEPTANCE_PROVIDER');
const _name = String.fromEnvironment(
  'ACCEPTANCE_USER',
  defaultValue: 'acceptance-user',
);
const _device = String.fromEnvironment(
  'ACCEPTANCE_DEVICE',
  defaultValue: 'unspecified',
);
const _sdkVersion = String.fromEnvironment(
  'ACCEPTANCE_VENDOR_SDK_VERSION',
  defaultValue: 'unrecorded',
);
const _cycles = int.fromEnvironment('ACCEPTANCE_CYCLES', defaultValue: 20);
const _holdSeconds = int.fromEnvironment(
  'ACCEPTANCE_HOLD_SECONDS',
  defaultValue: 1800,
);
const _remoteCount = int.fromEnvironment(
  'ACCEPTANCE_REMOTE_COUNT',
  defaultValue: _live && !_viewer ? 2 : 1,
);
const _live = bool.fromEnvironment('ACCEPTANCE_LIVE');
const _viewer = bool.fromEnvironment('ACCEPTANCE_VIEWER');
const _expectRecovery = bool.fromEnvironment('ACCEPTANCE_EXPECT_RECOVERY');
const _switchCamera = bool.fromEnvironment('ACCEPTANCE_SWITCH_CAMERA');
const _closeRoom = bool.fromEnvironment('ACCEPTANCE_CLOSE_ROOM');
const _effect = String.fromEnvironment(
  'ACCEPTANCE_EFFECT',
  defaultValue: 'none',
);

void _record(
  String scenario,
  String result, {
  RealtimeRoom? room,
  Map<String, Object?> extra = const {},
}) {
  // Deliberately excludes credentials, backend responses and native payloads.
  debugPrint(
    'ACCEPTANCE ${jsonEncode({'timestamp': DateTime.now().toUtc().toIso8601String(), 'scenario': scenario, 'result': result, 'platform': kIsWeb ? 'web' : defaultTargetPlatform.name, 'device': _device, 'provider': room?.providerId ?? _provider, 'engine': room?.engineProviderId, 'vendorSdkVersion': _sdkVersion, 'cycles': _cycles, 'holdSeconds': _holdSeconds, ...extra})}',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'provider-neutral lifecycle, endurance and processed-video acceptance',
    (tester) async {
      expect(_cycles, greaterThan(0));
      expect(_viewer && !_live, isFalse, reason: 'Viewer is a live-only role');
      expect(_remoteCount, greaterThanOrEqualTo(0));
      expect(_holdSeconds, greaterThanOrEqualTo(0));
      expect(
        _roomCode,
        isNotEmpty,
        reason: 'Use an explicitly provisioned test room.',
      );
      expect(
        _provider,
        isNotEmpty,
        reason: 'Record and verify the intended provider.',
      );
      expect(_device, isNot('unspecified'));
      expect(_sdkVersion, isNot('unrecorded'));
      final realtime = Realtime.standard(backendUrl: _backend);
      RealtimeConnection? connection;
      StreamSubscription<MediaRecoveryStatus>? recoverySubscription;
      var recovered = false;
      var cleanup = 'pending';
      try {
        for (var cycle = 0; cycle <= _cycles; cycle++) {
          final joining = Stopwatch()..start();
          connection = await realtime
              .open(
                RealtimeRequest.join(
                  type: _live
                      ? RealtimeExperience.live
                      : RealtimeExperience.meeting,
                  roomCode: _roomCode,
                  mediaRole: !_live
                      ? MediaRole.participant
                      : _viewer
                      ? MediaRole.viewer
                      : MediaRole.host,
                  user: RealtimeUser(id: _name, name: _name, deviceId: _device),
                ),
              )
              .timeout(const Duration(seconds: 60));
          joining.stop();
          final room = connection.mediaRoom!;
          expect(room.providerId, _provider);
          expect(room.media.session.state, MediaSessionState.connected);
          if (cycle < _cycles) {
            await connection.dispose().timeout(const Duration(seconds: 20));
            connection = null;
          }
          if (cycle < _cycles) {
            _record(
              'join-leave-cycle',
              'passed',
              room: room,
              extra: {
                'cycle': cycle + 1,
                'joinElapsedMs': joining.elapsedMilliseconds,
              },
            );
          }
        }
        final room = connection!.mediaRoom!;
        recoverySubscription = room.media.recoveries.listen((status) {
          if (status.phase == MediaRecoveryPhase.recovered) recovered = true;
          _record('recovery', status.phase.name, room: room);
        });
        if (!_viewer) {
          final MediaBackgroundEffect effect;
          switch (_effect) {
            case 'none':
              effect = const MediaBackgroundEffect.none();
            case 'blur':
              effect = const MediaBackgroundEffect.blur();
            case 'replaceImage':
              final data = await rootBundle.load(
                'assets/backgrounds/meeting-room-preset.png',
              );
              effect = MediaBackgroundEffect.replaceImage(
                imageBytes: data.buffer.asUint8List(
                  data.offsetInBytes,
                  data.lengthInBytes,
                ),
              );
            default:
              throw ArgumentError.value(_effect, 'ACCEPTANCE_EFFECT');
          }
          await room.prepareVideoEffects(
            MediaLocalPreviewSettings(
              cameraEnabled: true,
              microphoneEnabled: true,
              backgroundEffect: effect,
            ),
          );
          final media = room.media.session;
          if (media is InteractiveMediaSession) {
            await media.setMuted(false);
            await media.setVideoEnabled(true);
            if (_switchCamera) {
              expect(media.capabilities.canSwitchCamera, isTrue);
              await media.switchCamera(MediaCameraPosition.back);
              await media.switchCamera(MediaCameraPosition.front);
            }
          }
        }
        await tester.pumpWidget(
          MaterialApp(home: RealtimeRoomView(room: room)),
        );
        await tester.pump();
        final deadline = DateTime.now().add(Duration(seconds: _holdSeconds));
        while (DateTime.now().isBefore(deadline)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 1)),
          );
          await tester.pump();
          expect(room.media.session.state, isNot(MediaSessionState.failed));
          expect(room.media.session.state, isNot(MediaSessionState.ended));
        }
        expect(
          room.media.snapshot.remoteParticipants.length,
          greaterThanOrEqualTo(_remoteCount),
        );
        if (_expectRecovery) expect(recovered, isTrue);
        _record(
          'endurance',
          'passed',
          room: room,
          extra: {
            'remoteParticipants': room.media.snapshot.remoteParticipants.length,
            'effect': _effect,
            'remoteFrameReview': 'pending-manual',
            'credentialRenewal': 'use-provider-specific-renewal-suite',
          },
        );
        if (_closeRoom) await room.media.closeRoom();
      } on Object catch (error) {
        _record(
          'suite',
          'failed',
          extra: {'errorType': error.runtimeType.toString()},
        );
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        try {
          await recoverySubscription?.cancel();
          await connection?.dispose().timeout(const Duration(seconds: 20));
          cleanup = 'local-released';
        } finally {
          _record(
            'cleanup',
            cleanup,
            extra: {
              'providerResourceDeletion': _closeRoom
                  ? 'verify-control-plane-deletion'
                  : 'pending-room-owner',
            },
          );
        }
      }
    },
    skip: _backend.isEmpty,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
