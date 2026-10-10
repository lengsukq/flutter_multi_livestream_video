import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_ui/flutter_realtime_classroom_ui.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';

/// Student hand-raise action that can live in any toolbar.
class RealtimeRaiseHandButton extends StatelessWidget {
  const RealtimeRaiseHandButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null || !controller.canRaiseHand) {
          return const SizedBox.shrink();
        }
        final raised = state.students.any(
          (student) => student.userId == state.selfUserId && student.handRaised,
        );
        final strings = RealtimeStrings.of(context);
        return OutlinedButton.icon(
          onPressed: controller.isPending(RealtimeRoomUiAction.classroom)
              ? null
              : () => _runClassroomAction(
                  context,
                  () => controller.setHandRaised(!raised),
                ),
          icon: Icon(raised ? Icons.pan_tool_alt : Icons.pan_tool_outlined),
          label: Text(raised ? strings.lowerHand : strings.raiseHand),
        );
      },
    );
  }
}

/// Teacher hand queue and speaking approvals, independently placeable.
class RealtimeClassroomHandQueue extends StatelessWidget {
  const RealtimeClassroomHandQueue({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = controller.isPending(RealtimeRoomUiAction.classroom);
        final students = state.students
            .where((student) => student.handRaised || student.canSpeak)
            .toList(growable: false);
        if (students.isEmpty) {
          return const Center(child: Text('No raised hands'));
        }
        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              key: ValueKey(student.userId),
              title: Text(student.displayName),
              subtitle: Text(
                student.canSpeak ? 'Speaking permitted' : 'Hand raised',
              ),
              trailing: controller.canGrantSpeak
                  ? TextButton(
                      onPressed: pending
                          ? null
                          : () => _runClassroomAction(
                              context,
                              () => controller.setStudentCanSpeak(
                                student.userId,
                                canSpeak: !student.canSpeak,
                              ),
                            ),
                      child: Text(student.canSpeak ? 'Revoke' : 'Allow'),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Class roster does not depend on the whole ClassroomPanel.
class RealtimeClassroomRoster extends StatelessWidget {
  const RealtimeClassroomRoster({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.canViewClassroomRoster) {
          return const Center(child: Text('Roster unavailable'));
        }
        return ListView.builder(
          itemCount: state.students.length,
          itemBuilder: (context, index) {
            final member = state.students[index];
            return ListTile(
              key: ValueKey(member.userId),
              leading: Icon(
                member.online ? Icons.circle : Icons.circle_outlined,
                color: member.online ? Colors.green : Colors.grey,
                size: 16,
              ),
              title: Text(member.displayName),
              subtitle: Text(
                member.canSpeak
                    ? 'Can speak'
                    : member.handRaised
                    ? 'Hand raised'
                    : 'Listening',
              ),
              trailing: member.microphoneOn == null
                  ? null
                  : Icon(
                      member.microphoneOn! ? Icons.mic : Icons.mic_off,
                      size: 18,
                    ),
            );
          },
        );
      },
    );
  }
}

/// Q&A timeline with teacher answering/resolving, no fixed panel layout.
class RealtimeClassroomQuestions extends StatelessWidget {
  const RealtimeClassroomQuestions({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          itemCount: state.questions.length,
          itemBuilder: (context, index) {
            final question = state.questions[index];
            return ListTile(
              key: ValueKey(question.id),
              title: Text(question.text),
              subtitle: Text(
                [
                  question.displayName,
                  question.status.name,
                  if (question.answer != null) question.answer!,
                ].join(' · '),
              ),
              trailing: controller.canManageQuestions
                  ? PopupMenuButton<String>(
                      tooltip: 'Manage question',
                      enabled: !controller.isPending(
                        RealtimeRoomUiAction.classroom,
                      ),
                      onSelected: (action) async {
                        if (action == 'resolve') {
                          await _runClassroomAction(
                            context,
                            () => controller.resolveClassroomQuestion(
                              question.id,
                            ),
                          );
                        } else if (action == 'answer') {
                          final answer = await _askText(
                            context,
                            title: 'Answer question',
                            initialValue: question.answer ?? '',
                          );
                          if (answer != null && context.mounted) {
                            await _runClassroomAction(
                              context,
                              () => controller.answerClassroomQuestion(
                                question.id,
                                answer,
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'answer',
                          child: Text('Answer'),
                        ),
                        if (question.status != ClassroomQuestionStatus.resolved)
                          const PopupMenuItem(
                            value: 'resolve',
                            child: Text('Resolve'),
                          ),
                      ],
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Independent Q&A input can be placed above or below the questions list.
class RealtimeClassroomQuestionComposer extends StatefulWidget {
  const RealtimeClassroomQuestionComposer({super.key});
  @override
  State<RealtimeClassroomQuestionComposer> createState() =>
      _RealtimeClassroomQuestionComposerState();
}

class _RealtimeClassroomQuestionComposerState
    extends State<RealtimeClassroomQuestionComposer> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(RealtimeRoomUiController controller) async {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    if (await _runClassroomAction(
      context,
      () => controller.askClassroomQuestion(value),
    )) {
      if (mounted) _text.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              enabled:
                  controller.canAskQuestion &&
                  !controller.isPending(RealtimeRoomUiAction.classroom),
              maxLength: 500,
              onSubmitted: (_) => unawaited(_submit(controller)),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Ask a question',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ask question',
            onPressed:
                controller.canAskQuestion &&
                    !controller.isPending(RealtimeRoomUiAction.classroom)
                ? () => unawaited(_submit(controller))
                : null,
            icon: const Icon(Icons.send_outlined),
          ),
        ],
      ),
    );
  }
}

/// Quick student feedback independent of Q&A, attendance or teacher tools.
class RealtimeClassroomFeedbackButton extends StatelessWidget {
  const RealtimeClassroomFeedbackButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          controller.classroomState?.capabilities.canSendFeedback != true
          ? const SizedBox.shrink()
          : PopupMenuButton<ClassroomFeedbackKind>(
              tooltip: 'Classroom feedback',
              enabled: !controller.isPending(RealtimeRoomUiAction.classroom),
              icon: const Icon(Icons.emoji_emotions_outlined),
              onSelected: (kind) => _runClassroomAction(
                context,
                () => controller.sendClassroomFeedback(kind),
              ),
              itemBuilder: (_) => [
                for (final kind in ClassroomFeedbackKind.values)
                  PopupMenuItem(value: kind, child: Text(kind.name)),
              ],
            ),
    );
  }
}

/// Exposes the existing feature-complete tools panel as an independent widget.
class RealtimeClassroomToolsButton extends StatelessWidget {
  const RealtimeClassroomToolsButton({super.key});
  @override
  Widget build(BuildContext context) {
    final classroom = RealtimeRoomUiScope.of(context).room.classroom;
    if (classroom == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: RealtimeRoomUiScope.of(context),
      builder: (context, _) {
        final state = classroom.state;
        if (state?.capabilities.canUseTools != true) {
          return const SizedBox.shrink();
        }
        final zh = RealtimeStrings.of(context).isZh;
        return IconButton(
          tooltip: zh ? '课堂工具（公告、作业、倒计时）' : 'Classroom tools',
          icon: const Icon(Icons.build_outlined),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: ClassroomToolsPanel(classroom: classroom),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<bool> _runClassroomAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return false;
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, maxLines: 3, maxLength: 500),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
