import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_ui_controller.dart';

class RealtimeLeaveButton extends StatelessWidget {
  const RealtimeLeaveButton({
    super.key,
    this.onConfirm,
    this.onLeft,
    this.closeForEveryone,
    this.iconOnly = false,
  });

  final Future<bool> Function(BuildContext context)? onConfirm;
  final VoidCallback? onLeft;

  /// Null retains the SDK default: a broadcast host with close rights ends it.
  final bool? closeForEveryone;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final leaveAction = controller.isPending(RealtimeRoomUiAction.leave)
            ? null
            : () async {
                if (onConfirm != null && !await onConfirm!(context)) return;
                try {
                  await controller.leave(closeForEveryone: closeForEveryone);
                  if (context.mounted) onLeft?.call();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(
                      context,
                    )?.showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              };
        final label = RealtimeStrings.of(context).leave;
        if (iconOnly) {
          return Tooltip(
            message: label,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: RealtimeUiTokens.appleDanger,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              onPressed: leaveAction,
              icon: const Icon(Icons.call_end_rounded, size: 20),
            ),
          );
        }
        return FilledButton.icon(
          onPressed: leaveAction,
          style: FilledButton.styleFrom(
            backgroundColor: RealtimeUiTokens.appleDanger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.call_end_rounded, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}
