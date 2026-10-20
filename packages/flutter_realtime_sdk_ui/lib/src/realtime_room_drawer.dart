import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Right-side sheet used on phones and tablets for chat, members and tools.
///
/// Replaces the previous 72% bottom sheet so a conversation keeps the full
/// viewport height and the keyboard only shrinks the composer area.
Future<T?> showRealtimeRoomDrawer<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  IconData? icon,
  double widthFactor = 0.92,
  double maxWidth = 400,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0xFF101828).withValues(alpha: .38),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) {
      final style = RealtimeStyle.of(dialogContext);
      final size = MediaQuery.sizeOf(dialogContext);
      final insets = MediaQuery.viewInsetsOf(dialogContext);
      final width = (size.width * widthFactor).clamp(240.0, maxWidth);
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: Material(
            color: style.surface,
            child: SizedBox(
              width: width,
              height: size.height,
              child: SafeArea(
                left: false,
                child: Column(
                  children: [
                    SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            if (icon != null) ...[
                              const SizedBox(width: 8),
                              Icon(icon, size: 18, color: style.textSecondary),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(
                                dialogContext,
                              ).closeButtonTooltip,
                              onPressed: () =>
                                  Navigator.maybeOf(dialogContext)?.pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: style.border),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
