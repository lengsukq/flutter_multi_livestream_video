import 'dart:async';
import 'package:flutter/material.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Elapsed-time badge for the meeting dock (tabular figures, dot + text).
class RealtimeMeetingTimerBadge extends StatefulWidget {
  const RealtimeMeetingTimerBadge({super.key, this.startedAt});

  final DateTime? startedAt;

  @override
  State<RealtimeMeetingTimerBadge> createState() =>
      _RealtimeMeetingTimerBadgeState();
}

class _RealtimeMeetingTimerBadgeState extends State<RealtimeMeetingTimerBadge> {
  late DateTime _startTime;
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = widget.startedAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(_startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant RealtimeMeetingTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startedAt != oldWidget.startedAt) {
      _startTime = widget.startedAt ?? DateTime.now();
      _elapsed = DateTime.now().difference(_startTime);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String m = _elapsed.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String s = _elapsed.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final int h = _elapsed.inHours;
    final String timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';

    return Semantics(
      label: RealtimeStrings.of(context).isZh
          ? '已进行 $timeStr'
          : 'Elapsed time $timeStr',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: RealtimeStyle.of(context).surfaceSubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: RealtimeUiTokens.appleSuccess,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
