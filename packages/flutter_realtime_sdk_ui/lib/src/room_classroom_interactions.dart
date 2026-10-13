import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart' show RealtimeRoomUiAction;
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_ui/flutter_realtime_classroom_ui.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'meeting_dock.dart';
import 'room_ui_controller.dart';

/// Student hand-raise action that can live in any toolbar.
class RealtimeRaiseHandButton extends StatelessWidget {
  const RealtimeRaiseHandButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);
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
        return OutlinedButton.icon(
          onPressed: controller.isPending(RealtimeRoomUiAction.classroom)
              ? null
              : () => _runClassroomAction(
                  context,
                  () => controller.setHandRaised(!raised),
                ),
          style: OutlinedButton.styleFrom(
            backgroundColor: raised
                ? RealtimeUiTokens.iosOrange.withValues(alpha: 0.16)
                : style.surfaceSubtle,
            foregroundColor: raised ? RealtimeUiTokens.iosOrange : style.text,
            side: BorderSide(
              color: raised
                  ? RealtimeUiTokens.iosOrange.withValues(alpha: 0.5)
                  : style.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
            ),
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
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
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
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: style.primarySubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: style.primaryBorder),
                    ),
                    child: Icon(
                      Icons.pan_tool_outlined,
                      size: 28,
                      color: style.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.noRaisedHands,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: style.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.noRaisedHandsDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: style.textMuted),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            final statusColor = student.canSpeak ? Colors.green : Colors.orange;
            final statusText = student.canSpeak
                ? strings.speakingPermitted
                : strings.handRaisedStatus;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: style.border),
              ),
              child: Row(
                children: [
                  RealtimeAvatar(name: student.displayName, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: style.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: style.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (controller.canGrantSpeak)
                    FilledButton.tonal(
                      onPressed: pending
                          ? null
                          : () => _runClassroomAction(
                              context,
                              () => controller.setStudentCanSpeak(
                                student.userId,
                                canSpeak: !student.canSpeak,
                              ),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: student.canSpeak
                            ? style.danger.withValues(alpha: 0.15)
                            : style.primary.withValues(alpha: 0.15),
                        foregroundColor: student.canSpeak
                            ? style.danger
                            : style.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        student.canSpeak ? strings.revoke : strings.allow,
                      ),
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

/// Class roster does not depend on the whole ClassroomPanel.
class RealtimeClassroomRoster extends StatelessWidget {
  const RealtimeClassroomRoster({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.canViewClassroomRoster) {
          return Center(
            child: Text(
              strings.rosterUnavailable,
              style: TextStyle(color: style.textMuted),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: state.students.length,
          itemBuilder: (context, index) {
            final member = state.students[index];
            final statusText = member.canSpeak
                ? strings.canSpeak
                : member.handRaised
                ? strings.handRaisedStatus
                : strings.listening;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: style.border),
              ),
              child: Row(
                children: [
                  RealtimeAvatar(
                    name: member.displayName,
                    size: 36,
                    isOnline: member.online,
                    showOnlineDot: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: style.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: style.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (member.microphoneOn != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: member.microphoneOn!
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        member.microphoneOn! ? Icons.mic : Icons.mic_off,
                        size: 16,
                        color: member.microphoneOn!
                            ? Colors.green
                            : Colors.grey,
                      ),
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

/// Q&A timeline with teacher answering/resolving, no fixed panel layout.
class RealtimeClassroomQuestions extends StatelessWidget {
  const RealtimeClassroomQuestions({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.questions.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: style.primarySubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: style.primaryBorder),
                    ),
                    child: Icon(
                      Icons.forum_outlined,
                      size: 28,
                      color: style.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.noQuestionsYet,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: style.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.canAskQuestion
                        ? strings.noQuestionsDesc
                        : strings.noQuestionsDescTeacher,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: style.textMuted),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: state.questions.length,
          itemBuilder: (context, index) {
            final question = state.questions[index];
            final statusColor = switch (question.status) {
              ClassroomQuestionStatus.pending => Colors.orange,
              ClassroomQuestionStatus.answered => Colors.green,
              ClassroomQuestionStatus.resolved => Colors.grey,
            };
            final statusLabel = switch (question.status) {
              ClassroomQuestionStatus.pending => strings.questionPending,
              ClassroomQuestionStatus.answered => strings.questionAnswered,
              ClassroomQuestionStatus.resolved => strings.questionResolved,
            };

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: style.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RealtimeAvatar(name: question.displayName, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: style.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (controller.canManageQuestions) ...[
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: strings.manageQuestion,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: style.textMuted,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: style.surface,
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
                                title: strings.answerQuestion,
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
                            PopupMenuItem(
                              value: 'answer',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.reply_rounded,
                                    size: 16,
                                    color: style.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(strings.answer),
                                ],
                              ),
                            ),
                            if (question.status !=
                                ClassroomQuestionStatus.resolved)
                              PopupMenuItem(
                                value: 'resolve',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(strings.resolve),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: style.text,
                      height: 1.35,
                    ),
                  ),
                  if (question.answer != null &&
                      question.answer!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: style.primarySubtle.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: style.primary, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.school_rounded,
                                size: 14,
                                color: style.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                strings.teacherAnswerBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: style.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            question.answer!,
                            style: TextStyle(
                              fontSize: 13,
                              color: style.text,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      final has = _text.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

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
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);

    if (!controller.canAskQuestion) {
      return const SizedBox.shrink();
    }

    final canAsk = !controller.isPending(RealtimeRoomUiAction.classroom);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        decoration: BoxDecoration(
          color: style.surfaceSubtle,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: style.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                enabled: canAsk,
                maxLength: 500,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                onSubmitted: (_) => unawaited(_submit(controller)),
                style: TextStyle(fontSize: 14, color: style.text),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  hintText: strings.askQuestionHint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: style.textMuted.withValues(alpha: 0.7),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 2,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: strings.askQuestionTooltip,
              onPressed: canAsk ? () => unawaited(_submit(controller)) : null,
              style: IconButton.styleFrom(
                backgroundColor: _hasText ? style.primary : Colors.transparent,
                foregroundColor: _hasText ? Colors.white : style.textMuted,
                padding: const EdgeInsets.all(7),
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
          ],
        ),
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
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          controller.classroomState?.capabilities.canSendFeedback != true
          ? const SizedBox.shrink()
          : PopupMenuButton<ClassroomFeedbackKind>(
              tooltip: strings.classroomFeedback,
              enabled: !controller.isPending(RealtimeRoomUiAction.classroom),
              icon: Icon(Icons.emoji_emotions_outlined, color: style.text),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: style.border),
              ),
              color: style.surface,
              onSelected: (kind) => _runClassroomAction(
                context,
                () => controller.sendClassroomFeedback(kind),
              ),
              itemBuilder: (_) => [
                for (final kind in ClassroomFeedbackKind.values)
                  PopupMenuItem(
                    value: kind,
                    child: Text(
                      strings.isZh
                          ? switch (kind) {
                              ClassroomFeedbackKind.understood => '听懂了 👍',
                              ClassroomFeedbackKind.great => '太棒了 🔥',
                              ClassroomFeedbackKind.idea => '有想法 💡',
                              ClassroomFeedbackKind.question => '没听懂 ❓',
                              ClassroomFeedbackKind.clap => '鼓掌 👏',
                            }
                          : kind.name,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Exposes the existing feature-complete tools panel as an independent widget.
///
/// Renders as a [RealtimeDockItem] so it matches the meeting dock; pass
/// [showLabel] when it sits inside a labeled dock, leave it off for bare
/// icon rows such as the composable template.
class RealtimeClassroomToolsButton extends StatelessWidget {
  const RealtimeClassroomToolsButton({super.key, this.showLabel = false});

  final bool showLabel;

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
        final strings = RealtimeStrings.of(context);
        return RealtimeDockItem(
          icon: Icons.build_outlined,
          label: strings.classroomTools,
          tooltip: strings.classroomToolsDescription,
          showLabel: showLabel,
          onPressed: () => showRealtimeGlassBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (sheetContext) => SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.75,
              child: ClassroomToolsPanel(
                classroom: classroom,
                showHeader: true,
                onClose: () => Navigator.maybeOf(sheetContext)?.pop(),
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
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) =>
        _ClassroomPromptTextDialog(title: title, initialValue: initialValue),
  );
}

class _ClassroomPromptTextDialog extends StatefulWidget {
  const _ClassroomPromptTextDialog({
    required this.title,
    this.initialValue = '',
  });

  final String title;
  final String initialValue;

  @override
  State<_ClassroomPromptTextDialog> createState() =>
      _ClassroomPromptTextDialogState();
}

class _ClassroomPromptTextDialogState
    extends State<_ClassroomPromptTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return RealtimeGlassDialog(
      title: Text(widget.title),
      icon: Icons.edit_note_rounded,
      content: TextField(
        controller: _controller,
        maxLines: 3,
        maxLength: 500,
        autofocus: true,
        style: TextStyle(fontSize: 14, color: style.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: strings.askQuestionHint,
          hintStyle: TextStyle(fontSize: 13, color: style.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            borderSide: BorderSide(color: style.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            borderSide: BorderSide(color: style.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            borderSide: BorderSide(color: style.primary, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: style.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
            ),
          ),
          child: Text(strings.submit),
        ),
      ],
    );
  }
}
