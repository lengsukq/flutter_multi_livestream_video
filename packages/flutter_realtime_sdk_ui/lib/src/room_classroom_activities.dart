import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';

/// Read-only classroom engagement counters; the app places its own badge.
class RealtimeClassroomEngagement extends StatelessWidget {
  const RealtimeClassroomEngagement({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stats = controller.classroomState?.stats;
        if (stats == null) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.pan_tool_alt_outlined, size: 16),
              label: Text('${stats.handsRaised}'),
            ),
            Chip(
              avatar: const Icon(Icons.question_answer_outlined, size: 16),
              label: Text('${stats.pendingQuestions}'),
            ),
            Chip(
              avatar: const Icon(Icons.people_outline, size: 16),
              label: Text('${stats.onlineCount}'),
            ),
          ],
        );
      },
    );
  }
}

/// Student voting/quiz choices and teacher close action without a fixed panel.
class RealtimeClassroomActivityList extends StatelessWidget {
  const RealtimeClassroomActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        final tools = state?.tools;
        if (tools == null) {
          return RealtimeEmptyState(
            icon: Icons.quiz_outlined,
            title: strings.activitiesUnavailable,
          );
        }
        if (tools.activities.isEmpty) {
          return RealtimeEmptyState(
            icon: Icons.assignment_outlined,
            title: strings.noActivitiesYet,
          );
        }
        final busy = controller.isPending(RealtimeRoomUiAction.classroom);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: tools.activities.length,
          itemBuilder: (context, index) {
            final activity = tools.activities[index];
            final canVote =
                !state!.isTeacher &&
                !activity.closed &&
                activity.selfAnswer == null;
            final kindLabel = strings.isZh
                ? (activity.kind.name == 'quiz' ? '随堂测验' : '互动投票')
                : (activity.kind.name == 'quiz' ? 'Quiz' : 'Poll');
            final totalVotes = activity.counts?.fold(0, (a, b) => a + b) ?? 0;

            return Container(
              key: ValueKey(activity.id),
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: style.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: style.primarySubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: style.primaryBorder),
                        ),
                        child: Text(
                          kindLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: style.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activity.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: style.text,
                          ),
                        ),
                      ),
                      if (state.isTeacher && !activity.closed)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => unawaited(
                                  _action(
                                    context,
                                    () => controller.closeClassroomActivity(
                                      activity.id,
                                    ),
                                  ),
                                ),
                          style: TextButton.styleFrom(
                            foregroundColor: style.danger,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(strings.close),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        strings.activityResponses(activity.responseCount),
                        style: TextStyle(fontSize: 12, color: style.textMuted),
                      ),
                      if (activity.closed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            strings.activityClosed,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (
                    var option = 0;
                    option < activity.options.length;
                    option++
                  ) ...[
                    Builder(
                      builder: (context) {
                        final count =
                            activity.counts != null &&
                                option < activity.counts!.length
                            ? activity.counts![option]
                            : 0;
                        final percent = totalVotes > 0
                            ? (count / totalVotes)
                            : 0.0;
                        final isSelected = activity.selfAnswer == option;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: canVote && !busy
                                  ? () => unawaited(
                                      _action(
                                        context,
                                        () =>
                                            controller.answerClassroomActivity(
                                              activity.id,
                                              option,
                                            ),
                                      ),
                                    )
                                  : null,
                              child: Stack(
                                children: [
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: style.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? style.primary
                                            : style.border,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                  ),
                                  if (percent > 0)
                                    FractionallySizedBox(
                                      widthFactor: percent.clamp(0.0, 1.0),
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? style.primarySubtle
                                              : (style.isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.07,
                                                      )
                                                    : Colors.black.withValues(
                                                        alpha: 0.04,
                                                      )),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          size: 16,
                                          color: isSelected
                                              ? style.primary
                                              : style.textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            activity.options[option],
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: style.text,
                                            ),
                                          ),
                                        ),
                                        if (activity.counts != null &&
                                            option < activity.counts!.length)
                                          Text(
                                            '$count (${(percent * 100).toInt()}%)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: style.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _action(
  BuildContext context,
  Future<void> Function() command,
) async {
  try {
    await command();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
