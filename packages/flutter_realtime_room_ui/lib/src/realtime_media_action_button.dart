import 'dart:async';
import 'package:flutter/material.dart';
import 'realtime_room_ui_action.dart';
import 'realtime_room_ui_scope.dart';

class RealtimeMediaActionButton extends StatelessWidget {
  const RealtimeMediaActionButton({super.key, required this.action, required this.label, required this.icon});
  final RealtimeRoomUiAction action;
  final String label;
  final IconData icon;
  @override Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final supported = switch(action) {
        RealtimeRoomUiAction.microphone => controller.canUseMicrophone,
        RealtimeRoomUiAction.camera => controller.canUseCamera,
        RealtimeRoomUiAction.screenShare => controller.canShareScreen,
        RealtimeRoomUiAction.switchCamera => controller.canSwitchCamera,
        RealtimeRoomUiAction.leave => true,
        _ => false,
      };
      Future<void> invoke() => switch(action) {
        RealtimeRoomUiAction.microphone => controller.toggleMicrophone(),
        RealtimeRoomUiAction.camera => controller.toggleCamera(),
        RealtimeRoomUiAction.screenShare => controller.toggleScreenShare(),
        RealtimeRoomUiAction.switchCamera => controller.switchCamera(),
        RealtimeRoomUiAction.leave => controller.leave(),
        _ => Future<void>.value(),
      };
      return FilledButton.tonalIcon(
        onPressed: supported && !controller.isPending(action) ? () => unawaited(invoke().catchError((Object error) => controller.reportActionError(error))) : null,
        icon: Icon(icon), label: Text(label),
      );
    });
  }
}
