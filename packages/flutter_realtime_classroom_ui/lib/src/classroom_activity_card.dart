import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tool_command_builder.dart';

class ClassroomActivityCard extends StatelessWidget {
  const ClassroomActivityCard({
    super.key,
    required this.activity,
    required this.state,
    required this.classroom,
    this.onActionError,
  });
  final ClassroomActivity activity;
  final ClassroomState state;
  final ClassroomSession classroom;
  final ValueChanged<RealtimeException>? onActionError;
  @override
  Widget build(BuildContext context) {
    final s = ClassroomStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ClassroomToolCommandBuilder(
      onActionError: onActionError,
      builder: (context, run, pending) {
        final isQuiz = activity.kind == ClassroomActivityKind.quiz;
        final totalVotes =
            activity.counts?.fold(0, (a, b) => a + b) ?? activity.responseCount;
        final fgColor = isQuiz
            ? (style.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
            : (style.isDark
                  ? const Color(0xFFF472B6)
                  : const Color(0xFFBE185D));
        final bgColor = isQuiz
            ? (style.isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
            : (style.isDark
                  ? const Color(0xFF831843)
                  : const Color(0xFFFDF2F8));
        final borderColor = isQuiz
            ? (style.isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE))
            : (style.isDark
                  ? const Color(0xFF9D174D)
                  : const Color(0xFFFBCFE8));

        return RealtimeCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          radius: RealtimeUiTokens.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      isQuiz ? Icons.quiz_outlined : Icons.poll_outlined,
                      size: 19,
                      color: fgColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RealtimePill(
                              label: s.chinese
                                  ? (isQuiz ? '随堂测验' : '互动投票')
                                  : (isQuiz ? 'Class Quiz' : 'Class Poll'),
                              foreground: fgColor,
                              background: bgColor,
                              borderColor: borderColor,
                            ),
                            const SizedBox(width: 6),
                            if (activity.closed)
                              RealtimePill(
                                label: s.t('ended'),
                                foreground: style.textMuted,
                                background: style.surfaceSubtle,
                                borderColor: style.border,
                              )
                            else
                              RealtimePill(
                                label: s.t('inProgress'),
                                leadingDotColor: style.success,
                                foreground: style.success,
                                background: style.successSubtle,
                                borderColor: style.success.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activity.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: style.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RealtimePill(
                    label: '${s.t('responses')}: ${activity.responseCount}',
                    foreground: style.textMuted,
                    background: style.surfaceSubtle,
                    borderColor: style.border,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < activity.options.length; i++)
                _buildOptionItem(
                  pending: pending,
                  run: run,
                  state: state,
                  activity: activity,
                  index: i,
                  s: s,
                  style: style,
                  totalVotes: totalVotes,
                ),
              if (state.isTeacher && activity.answers.isNotEmpty) ...[
                const SizedBox(height: 4),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 15,
                          color: style.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.t('studentAnswers'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: style.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      for (final answer in activity.answers.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              RealtimeAvatar(
                                name:
                                    state.students
                                        .where((st) => st.userId == answer.key)
                                        .firstOrNull
                                        ?.displayName ??
                                    answer.key,
                                size: 24,
                                fontSize: 10,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.students
                                          .where(
                                            (st) => st.userId == answer.key,
                                          )
                                          .firstOrNull
                                          ?.displayName ??
                                      answer.key,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: style.text,
                                  ),
                                ),
                              ),
                              RealtimePill(
                                label: activity.options[answer.value],
                                foreground: style.primary,
                                background: style.primarySubtle,
                                borderColor: style.primaryBorder,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (state.isTeacher && !activity.closed) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: style.danger,
                      side: BorderSide(
                        color: style.danger.withValues(alpha: 0.35),
                      ),
                      backgroundColor: style.dangerSubtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(
                      s.t('closeActivity'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: pending
                        ? null
                        : () => run(() => classroom.closeActivity(activity.id)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required bool pending,
    required ClassroomToolCommand run,
    required ClassroomState state,
    required ClassroomActivity activity,
    required int index,
    required ClassroomStrings s,
    required RealtimeStyle style,
    required int totalVotes,
  }) {
    final count = (activity.counts != null && index < activity.counts!.length)
        ? activity.counts![index]
        : 0;
    final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
    final isSelf = activity.selfAnswer == index;
    final isCorrect = activity.correctOption == index;
    final showCorrect =
        isCorrect && (activity.closed || state.isTeacher || isSelf);
    final canTap = !state.isTeacher && !activity.closed && !pending;

    final borderColor = showCorrect
        ? style.success.withValues(alpha: 0.35)
        : (isSelf ? style.primary : style.border);
    final bgColor = showCorrect
        ? style.successSubtle
        : (isSelf ? style.primarySubtle : style.surfaceSubtle);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: RealtimeGlassPressable(
        borderRadius: RealtimeUiTokens.compactRadius,
        onTap: canTap
            ? () => run(() => classroom.answerActivity(activity.id, index))
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            border: Border.all(
              color: borderColor,
              width: (isSelf || showCorrect) ? 1.4 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              if (percent > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            (showCorrect
                                    ? style.success
                                    : (isSelf
                                          ? style.primary
                                          : style.textMuted))
                                .withValues(alpha: style.isDark ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (showCorrect)
                      Icon(
                        Icons.check_circle_rounded,
                        color: style.success,
                        size: 18,
                      )
                    else if (isSelf)
                      Icon(
                        Icons.radio_button_checked,
                        color: style.primary,
                        size: 18,
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: style.borderStrong,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: style.textMuted,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activity.options[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isSelf || showCorrect)
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: style.text,
                        ),
                      ),
                    ),
                    if (showCorrect && !isSelf) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check, color: style.success, size: 16),
                    ],
                    if (activity.counts != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(percent * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: showCorrect
                              ? style.success
                              : (isSelf ? style.primary : style.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: style.textMuted,
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
    );
  }
}
