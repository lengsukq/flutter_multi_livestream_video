import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tool_command_builder.dart';

class ClassroomTimerCard extends StatefulWidget {
  const ClassroomTimerCard({
    super.key,
    required this.timer,
    required this.state,
    required this.classroom,
    this.onActionError,
  });
  final ClassroomTimer timer;
  final ClassroomState state;
  final ClassroomSession classroom;
  final ValueChanged<RealtimeException>? onActionError;

  @override
  State<ClassroomTimerCard> createState() => _ClassroomTimerCardState();
}

class _ClassroomTimerCardState extends State<ClassroomTimerCard> {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _restartClock();
  }

  void _restartClock() {
    _clock?.cancel();
    if (widget.timer.remaining() == Duration.zero) return;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.timer.remaining() == Duration.zero) _clock?.cancel();
    });
  }

  @override
  void didUpdateWidget(covariant ClassroomTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timer.endsAt != widget.timer.endsAt) _restartClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final state = widget.state;
    final classroom = widget.classroom;
    final onActionError = widget.onActionError;
    final s = ClassroomStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ClassroomToolCommandBuilder(
      onActionError: onActionError,
      builder: (context, run, pending) {
        final remaining = timer.remaining();
        final isEnded = remaining.inSeconds == 0;
        final minutes = remaining.inMinutes;
        final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        final formatted = '$minutes:$seconds';

        return RealtimeCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          radius: RealtimeUiTokens.cardRadius,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.iosOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(
                    color: RealtimeUiTokens.iosOrange.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: RealtimeUiTokens.iosOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timer.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: style.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isEnded)
                          RealtimePill(
                            label: s.t('ended'),
                            foreground: style.danger,
                            background: style.dangerSubtle,
                            borderColor: style.danger.withValues(alpha: 0.3),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: style.warningSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: style.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.alarm_on_rounded,
                                  size: 13,
                                  color: style.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formatted,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: style.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (state.isTeacher)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: style.danger,
                    side: BorderSide(
                      color: style.danger.withValues(alpha: 0.35),
                    ),
                    backgroundColor: style.dangerSubtle,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: Text(
                    s.t('stopTimer'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: pending ? null : () => run(classroom.stopTimer),
                ),
            ],
          ),
        );
      },
    );
  }
}
