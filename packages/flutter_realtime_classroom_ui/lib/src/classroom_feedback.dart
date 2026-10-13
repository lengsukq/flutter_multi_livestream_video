import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_feedback_presentation.dart';
class ClassroomFeedbackPanel extends StatefulWidget {
 const ClassroomFeedbackPanel({super.key, required this.classroom, required this.snapshot, this.onActionError});
 final ClassroomSession classroom;
 final ClassroomState snapshot;
 final void Function(RealtimeException error)? onActionError;
 @override State<ClassroomFeedbackPanel> createState() => _ClassroomFeedbackPanelState();
}
class _ClassroomFeedbackPanelState extends State<ClassroomFeedbackPanel> {

@override void dispose() {   super.dispose(); }
@override Widget build(BuildContext context) => _feedback(widget.snapshot);

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
