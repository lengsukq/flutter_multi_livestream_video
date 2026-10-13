import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';

extension ClassroomFeedbackPresentation on ClassroomFeedbackKind {
  String get emoji => switch (this) {
    ClassroomFeedbackKind.understood => '👍',
    ClassroomFeedbackKind.great => '👏',
    ClassroomFeedbackKind.idea => '💡',
    ClassroomFeedbackKind.question => '❓',
    ClassroomFeedbackKind.clap => '🎉',
  };

  String label(ClassroomStrings strings) => strings.t(switch (this) {
    ClassroomFeedbackKind.understood => 'quickUnderstood',
    ClassroomFeedbackKind.great => 'quickGreat',
    ClassroomFeedbackKind.idea => 'quickIdea',
    ClassroomFeedbackKind.question => 'quickQuestion',
    ClassroomFeedbackKind.clap => 'quickClap',
  });
}

class ClassroomFeedbackBubble {
  OverlayEntry? _entry;
  Timer? _timer;

  void show(
    BuildContext context,
    ClassroomNotification notification, {
    VoidCallback? onView,
  }) {
    if (notification.kind != ClassroomNotificationKind.feedbackReceived ||
        notification.feedback.isEmpty) {
      return;
    }
    final overlay = Overlay.maybeOf(context);
    final anchor = context.findRenderObject();
    if (overlay == null || anchor is! RenderBox || !anchor.hasSize) return;
    dismiss();
    final strings = ClassroomStrings.of(context);
    final latest = notification.feedback.last;
    final name = latest.displayName.isEmpty
        ? latest.userId
        : latest.displayName;
    final extra = notification.feedback.length - 1;
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 24).clamp(0.0, 300.0);
    final position = anchor.localToGlobal(Offset.zero);
    final left = (position.dx + anchor.size.width / 2 - width / 2).clamp(
      12.0,
      size.width - width - 12,
    );
    final above = position.dy > 140;
    final style = RealtimeStyle.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        width: width,
        top: above ? null : position.dy + anchor.size.height + 10,
        bottom: above ? size.height - position.dy + 10 : null,
        child: Semantics(
          liveRegion: true,
          child: Material(
            color: Colors.transparent,
            child: RealtimeGlassSurface(
              radius: RealtimeUiTokens.compactRadius,
              fillColor: style.surface.withValues(alpha: .96),
              borderColor: style.primary.withValues(alpha: .3),
              padding: const EdgeInsets.all(12),
              onTap: onView == null
                  ? null
                  : () {
                      dismiss();
                      onView();
                    },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(latest.kind.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$name ${strings.t('feedbackDid')} ${latest.kind.label(strings)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: style.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (extra > 0)
                          Text(
                            '+$extra ${strings.t('feedbackMore')}',
                            style: TextStyle(
                              color: style.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        if (onView != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            strings.t('feedbackView'),
                            style: TextStyle(
                              color: style.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 4), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}
