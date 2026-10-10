import 'dart:async';

import 'package:flutter/material.dart';

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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        final tools = state?.tools;
        if (tools == null) {
          return const Center(child: Text('Activities unavailable'));
        }
        if (tools.activities.isEmpty) {
          return const Center(child: Text('No activities yet'));
        }
        final busy = controller.isPending(RealtimeRoomUiAction.classroom);
        return ListView.builder(
          itemCount: tools.activities.length,
          itemBuilder: (context, index) {
            final activity = tools.activities[index];
            final canVote =
                !state!.isTeacher &&
                !activity.closed &&
                activity.selfAnswer == null;
            return Card(
              key: ValueKey(activity.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(activity.title),
                    subtitle: Text(
                      '${activity.kind.name} · ${activity.responseCount} responses'
                      '${activity.closed ? ' · closed' : ''}',
                    ),
                    trailing: state.isTeacher && !activity.closed
                        ? TextButton(
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
                            child: const Text('Close'),
                          )
                        : null,
                  ),
                  for (
                    var option = 0;
                    option < activity.options.length;
                    option++
                  )
                    ListTile(
                      dense: true,
                      leading: Icon(
                        activity.selfAnswer == option
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(activity.options[option]),
                      trailing:
                          activity.counts != null &&
                              option < activity.counts!.length
                          ? Text('${activity.counts![option]}')
                          : null,
                      enabled: canVote && !busy,
                      onTap: canVote && !busy
                          ? () => unawaited(
                              _action(
                                context,
                                () => controller.answerClassroomActivity(
                                  activity.id,
                                  option,
                                ),
                              ),
                            )
                          : null,
                    ),
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
