import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'room_event_overlay.dart';

/// Compatibility presenter for hosts composing just the classroom overlay.
class RealtimeClassroomEventOverlay extends StatelessWidget {
  const RealtimeClassroomEventOverlay({
    super.key,
    required this.classroom,
    this.toastDuration = const Duration(seconds: 5),
  });
  final ClassroomSession classroom;
  final Duration toastDuration;
  @override
  Widget build(BuildContext context) => RealtimeRoomEventOverlay(
    classroom: classroom,
    toastDuration: toastDuration,
  );
}
