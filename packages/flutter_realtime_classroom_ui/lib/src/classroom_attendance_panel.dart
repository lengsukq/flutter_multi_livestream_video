import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';

class ClassroomAttendancePanel extends StatelessWidget {
  const ClassroomAttendancePanel({super.key, required this.state});
  final ClassroomState state;
  @override
  Widget build(BuildContext context) {
    final s = ClassroomStrings.of(context);
    final style = RealtimeStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.how_to_reg_rounded, size: 16, color: style.textMuted),
            const SizedBox(width: 6),
            Text(
              s.t('attendance'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: style.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            RealtimePill(
              label: '${state.attendance.length}',
              foreground: style.primary,
              background: style.primarySubtle,
              borderColor: style.primaryBorder,
            ),
          ],
        ),
        const SizedBox(height: 10),
        RealtimeCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          radius: RealtimeUiTokens.cardRadius,
          child: Column(
            children: [
              for (var i = 0; i < state.attendance.length; i++) ...[
                if (i > 0) Divider(color: style.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      RealtimeAvatar(
                        name: state.attendance[i].displayName,
                        avatarUrl: state.attendance[i].avatarUrl,
                        size: 32,
                        isOnline: state.attendance[i].online,
                        showOnlineDot: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.attendance[i].displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: style.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.t('firstJoined')}: ${state.attendance[i].firstJoinedAt?.toLocal().toString().split('.').first ?? '—'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: style.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RealtimePill(
                        label:
                            '${state.attendance[i].onlineDuration.inMinutes} ${s.t('minutes')}',
                        leadingDotColor: state.attendance[i].online
                            ? style.success
                            : style.textMuted,
                        foreground: state.attendance[i].online
                            ? style.success
                            : style.textMuted,
                        background: state.attendance[i].online
                            ? style.successSubtle
                            : style.surfaceSubtle,
                        borderColor: state.attendance[i].online
                            ? style.success.withValues(alpha: 0.35)
                            : style.border,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
