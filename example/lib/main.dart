import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';
import 'package:flutter_aws_chime/models/join_info.model.dart';
import 'package:flutter_aws_chime/views/meeting.view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StreamSubscription<ChimeEvent> _eventsSubscription;
  CameraPosition _cameraPosition = CameraPosition.front;

  @override
  void initState() {
    super.initState();
    // Listen before MeetingView starts joining the meeting.
    _eventsSubscription = MeetingModel().events.listen(_logEvent);
  }

  void _logEvent(ChimeEvent event) {
    switch (event) {
      case MeetingSessionEvent():
        debugPrint(
          'Meeting session: ${event.kind.name}, '
          'reconnecting=${event.reconnecting}, status=${event.statusCode}',
        );
      case ConnectionQualityEvent():
        debugPrint('Connection quality: ${event.quality.name}');
      case CameraAvailabilityEvent():
        debugPrint('Camera available: ${event.available}');
      case AttendeeVolumeEvent():
        debugPrint(
          'Attendee ${event.attendeeId} volume: ${event.volumeLevel.name}',
        );
      case AttendeeSignalStrengthEvent():
        debugPrint(
          'Attendee ${event.attendeeId} signal: '
          '${event.signalStrength.name}',
        );
      case VideoTileEvent():
        debugPrint('Video tile ${event.videoTile.tileId}: ${event.kind.name}');
    }
  }

  Future<void> _switchCamera() async {
    final requestedPosition = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    final succeeded = await MeetingModel().switchCamera(requestedPosition);
    if (!mounted) return;
    if (succeeded) {
      setState(() => _cameraPosition = requestedPosition);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not switch cameras.')),
      );
    }
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        child: Scaffold(
          body: Stack(
            children: [
              MeetingView(
                JoinInfo(
                  MeetingInfo.fromJson({
                    'ExternalMeetingId': '',
                    'MediaPlacement': {
                      'AudioFallbackUrl': '',
                      'AudioHostUrl': '',
                      'EventIngestionUrl': '',
                      'ScreenDataUrl': '',
                      'ScreenSharingUrl': '',
                      'ScreenViewingUrl': '',
                      'SignalingUrl': '',
                      'TurnControlUrl': '',
                    },
                    'MediaRegion': 'us-east-1',
                    'MeetingArn': '',
                    'MeetingId': '',
                    'TenantIds': [],
                  }),
                  AttendeeInfo.fromJson({
                    'AttendeeId': '',
                    'Capabilities': {
                      'Audio': 'SendReceive',
                      'Content': 'SendReceive',
                      'Video': 'SendReceive',
                    },
                    'ExternalUserId': '',
                    'JoinToken': '',
                  }),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  tooltip: 'Switch camera',
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.flip_camera_android),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
