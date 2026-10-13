import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';

class ClassroomHomeworkCard extends StatelessWidget {
  const ClassroomHomeworkCard({super.key, required this.homework});
  final ClassroomHomework homework;
  @override
  Widget build(BuildContext context) {
    final s = ClassroomStrings.of(context);
    final style = RealtimeStyle.of(context);
    return RealtimeCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: RealtimeUiTokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.iosGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(
                    color: RealtimeUiTokens.iosGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 17,
                  color: RealtimeUiTokens.iosGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  homework.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
              ),
              if (homework.dueAt != null)
                RealtimePill(
                  label:
                      '${homework.dueAt!.toLocal().month}/${homework.dueAt!.toLocal().day}',
                  leadingDotColor: style.warning,
                  foreground: style.warning,
                  background: style.warningSubtle,
                  borderColor: style.warning.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: style.surfaceSubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(color: style.border),
            ),
            child: SelectableText(
              '${homework.instructions}${homework.dueAt == null ? '' : '\n\n${s.chinese ? '截止时间' : 'Due'}: ${homework.dueAt!.toLocal()}'}',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: style.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
