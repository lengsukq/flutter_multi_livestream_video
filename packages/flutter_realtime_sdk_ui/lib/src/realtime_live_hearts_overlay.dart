import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'room_ui_controller.dart';

class RealtimeLiveHeartsOverlay extends StatelessWidget {
  const RealtimeLiveHeartsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.liveInteractions == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 1100),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.8),
              end: const Offset(0, -1.5),
            ).animate(animation),
            child: child,
          ),
        ),
        child: controller.receivedLikeCount == 0
            ? const SizedBox.shrink(key: ValueKey(0))
            : Icon(
                Icons.favorite,
                key: ValueKey(controller.receivedLikeCount),
                color: Colors.pinkAccent,
                size: 32,
              ),
      ),
    );
  }
}

/// Host tools panel providing quick access to camera flip, virtual background,
/// screen sharing, audio output routing and custom host extensions.
