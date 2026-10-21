import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';

import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';
import 'classroom_sidebar_visuals.dart';

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
        final canPublish = state?.capabilities.canPublishTools == true;
        if (tools.activities.isEmpty && !canPublish) {
          return RealtimeEmptyState(
            icon: Icons.assignment_outlined,
            title: strings.noActivitiesYet,
          );
        }
        final busy = controller.isPending(RealtimeRoomUiAction.classroom);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: tools.activities.length + (canPublish ? 1 : 0),
          itemBuilder: (context, index) {
            if (canPublish && index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
                child: OutlinedButton.icon(
                  key: const ValueKey('classroom-create-activity'),
                  onPressed: busy
                      ? null
                      : () => _createClassroomActivity(context, controller),
                  icon: const Icon(Icons.add_chart_rounded, size: 18),
                  label: Text(strings.isZh ? '创建投票或测验' : 'Create poll or quiz'),
                ),
              );
            }
            final activity = tools.activities[index - (canPublish ? 1 : 0)];
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
                color: style.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: style.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClassroomSidebarStatus(
                        label: kindLabel,
                        icon: activity.kind.name == 'quiz'
                            ? Icons.quiz_outlined
                            : Icons.poll_outlined,
                        color: style.textSecondary,
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

typedef _ActivityDraft = ({
  ClassroomActivityKind kind,
  String title,
  List<String> options,
  int? correctOption,
});

/// Composes a real classroom activity; submission goes through the same
/// authenticated classroom repository used for voting and closing activities.
Future<void> _createClassroomActivity(
  BuildContext context,
  RealtimeRoomUiController controller,
) async {
  if (controller.classroomState?.capabilities.canPublishTools != true) return;
  final zh = RealtimeStrings.of(context).isZh;
  var kind = ClassroomActivityKind.poll;
  var title = '';
  final options = <String>['', ''];
  var correct = 0;
  final draft = await showDialog<_ActivityDraft>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, update) {
        final clean = options.map((o) => o.trim()).toList();
        final valid =
            title.trim().isNotEmpty &&
            title.trim().length <= 500 &&
            clean.length >= 2 &&
            clean.every((s) => s.isNotEmpty && s.length <= 200) &&
            clean.toSet().length == clean.length;
        return AlertDialog(
          title: Text(zh ? '创建课堂互动' : 'Create classroom activity'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ClassroomActivityKind>(
                    segments: [
                      ButtonSegment(
                        value: ClassroomActivityKind.poll,
                        label: Text(zh ? '投票' : 'Poll'),
                        icon: const Icon(Icons.poll_outlined),
                      ),
                      ButtonSegment(
                        value: ClassroomActivityKind.quiz,
                        label: Text(zh ? '测验' : 'Quiz'),
                        icon: const Icon(Icons.quiz_outlined),
                      ),
                    ],
                    selected: {kind},
                    onSelectionChanged: (values) =>
                        update(() => kind = values.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('classroom-activity-title'),
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: zh ? '题目' : 'Question',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) => update(() => title = text),
                  ),
                  for (var i = 0; i < options.length; i++) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('classroom-activity-option-$i'),
                      initialValue: options[i],
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: '${zh ? '选项' : 'Option'} ${i + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (text) => update(() => options[i] = text),
                    ),
                  ],
                  if (options.length < 8)
                    TextButton.icon(
                      key: const ValueKey('classroom-activity-add-option'),
                      onPressed: () => update(() => options.add('')),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(zh ? '添加选项' : 'Add option'),
                    ),
                  if (options.length > 2)
                    TextButton.icon(
                      onPressed: () => update(() {
                        options.removeLast();
                        if (correct >= options.length) correct = 0;
                      }),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: Text(zh ? '删除最后一个选项' : 'Remove last option'),
                    ),
                  if (kind == ClassroomActivityKind.quiz) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: const ValueKey('classroom-activity-correct'),
                      initialValue: correct,
                      decoration: InputDecoration(
                        labelText: zh ? '正确答案' : 'Correct answer',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (var i = 0; i < options.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text('${zh ? '选项' : 'Option'} ${i + 1}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) update(() => correct = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(zh ? '取消' : 'Cancel'),
            ),
            FilledButton(
              key: const ValueKey('classroom-activity-publish'),
              onPressed: valid
                  ? () => Navigator.pop(dialog, (
                      kind: kind,
                      title: title.trim(),
                      options: clean,
                      correctOption: kind == ClassroomActivityKind.quiz
                          ? correct
                          : null,
                    ))
                  : null,
              child: Text(zh ? '发布' : 'Publish'),
            ),
          ],
        );
      },
    ),
  );
  if (draft == null || !context.mounted) return;
  await _action(
    context,
    () => controller.publishClassroomActivity(
      kind: draft.kind,
      title: draft.title,
      options: draft.options,
      correctOption: draft.correctOption,
    ),
  );
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
