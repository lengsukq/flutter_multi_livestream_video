import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'realtime_room_ui_scope.dart';

class RealtimeConnectionIndicator extends StatelessWidget {
  const RealtimeConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.snapshot.state;
        final strings = RealtimeStrings.of(context);
        final (foreground, background, border, dot) = switch (state) {
          MediaSessionState.connected => (
            const Color(0xFF059669),
            const Color(0xFF10B981).withValues(alpha: 0.15),
            const Color(0xFF10B981).withValues(alpha: 0.35),
            const Color(0xFF10B981),
          ),
          MediaSessionState.connecting ||
          MediaSessionState.joining ||
          MediaSessionState.reconnecting ||
          MediaSessionState.leaving => (
            const Color(0xFFD97706),
            const Color(0xFFF59E0B).withValues(alpha: 0.15),
            const Color(0xFFF59E0B).withValues(alpha: 0.4),
            const Color(0xFFF59E0B),
          ),
          MediaSessionState.failed => (
            const Color(0xFFDC2626),
            const Color(0xFFEF4444).withValues(alpha: 0.12),
            const Color(0xFFEF4444).withValues(alpha: 0.4),
            const Color(0xFFEF4444),
          ),
          _ => (
            RealtimeUiTokens.textMuted,
            RealtimeUiTokens.surfaceSubtle,
            RealtimeUiTokens.border,
            null,
          ),
        };
        return Semantics(
          label: 'Connection: ${strings.mediaConnectionState(state)}',
          child: RealtimePill(
            label: strings.mediaConnectionState(state),
            leadingDotColor: dot,
            foreground: foreground,
            background: background,
            borderColor: border,
          ),
        );
      },
    );
  }
}

/// Renders one participant from the room without owning the entire stage.
