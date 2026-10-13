import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';

class ClassroomNoticeCard extends StatelessWidget {
  const ClassroomNoticeCard({super.key, required this.notice});
  final ClassroomNotice notice;
  @override
  Widget build(BuildContext context) {
    final s = ClassroomStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isFocus = notice.isFocusReminder;
    final fgColor = isFocus
        ? (style.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
        : style.primary;
    final bgColor = isFocus
        ? (style.isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
        : style.primarySubtle;
    final borderColor = isFocus
        ? (style.isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE))
        : style.primaryBorder;
    final icon = isFocus ? Icons.center_focus_strong : Icons.campaign_outlined;

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
                  color: bgColor,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 17, color: fgColor),
              ),
              const SizedBox(width: 10),
              RealtimePill(
                label: s.t(isFocus ? 'focus' : 'announcement'),
                foreground: fgColor,
                background: bgColor,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            notice.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: style.text,
            ),
          ),
        ],
      ),
    );
  }
}
