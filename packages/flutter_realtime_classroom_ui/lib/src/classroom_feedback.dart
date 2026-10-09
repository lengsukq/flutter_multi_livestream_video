part of 'classroom_panel.dart';

extension _FeedbackPresentation on ClassroomFeedbackKind {
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

class _ClassroomFeedbackBubble {
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

extension _ClassroomFeedbackPanel on _ClassroomPanelState {
  Widget _feedback(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    final recent = state.feedback.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('feedbackRecent'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: RealtimeUiTokens.text,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ClassroomFeedbackKind.values)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: kind == ClassroomFeedbackKind.question
                            ? RealtimeUiTokens.warningSubtle
                            : RealtimeUiTokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(color: RealtimeUiTokens.border),
                      ),
                      child: Text(
                        '${kind.emoji} ${kind.label(strings)}  '
                        '${recent.where((item) => item.kind == kind).length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.t('feedbackRetention'),
                style: const TextStyle(
                  fontSize: 11,
                  color: RealtimeUiTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: recent.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      strings.t('feedbackEmpty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: RealtimeUiTokens.textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: recent.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = recent[index];
                    final time = MaterialLocalizations.of(context)
                        .formatTimeOfDay(
                          TimeOfDay.fromDateTime(item.createdAt.toLocal()),
                        );
                    return Container(
                      key: ValueKey('classroom-feedback-${item.id}'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.surface,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(color: RealtimeUiTokens.border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            item.kind.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName.isEmpty
                                      ? item.userId
                                      : item.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.kind.label(strings),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: RealtimeUiTokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: RealtimeUiTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
