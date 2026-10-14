import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Side-panel selection for the Demo meeting layout.
///
/// Extracted from the monolithic meeting page so the stage, dock and panel
/// evolve independently. Wide screens show it as a trailing column (reference
/// layout right column); narrow screens use a bottom sheet instead.
enum DemoMeetingPanel { closed, chat, participants, classroom }

/// Trailing side panel: classroom tools or chat/participants sidebar.
///
/// Must be built under a [RealtimeRoomUiScope].
class DemoMeetingSidePanel extends StatelessWidget {
  const DemoMeetingSidePanel({
    super.key,
    required this.panel,
    required this.classroomTab,
    required this.classroomPanelVisit,
    required this.onClose,
  });

  final DemoMeetingPanel panel;
  final int classroomTab;
  final int classroomPanelVisit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final RealtimeStrings strings = RealtimeStrings.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RealtimeRoomUiController controller = RealtimeRoomUiScope.of(context);

    if (panel == DemoMeetingPanel.classroom) {
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        child: RealtimeCardSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1D1F).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.classroom,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: strings.closePanel,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: RealtimeClassroomPanel(
                  key: ValueKey<int>(classroomPanelVisit),
                  showHeader: false,
                  initialTab: classroomTab,
                  onClose: onClose,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<RealtimeMeetingMemberItem> members = controller
        .snapshot
        .participants
        .map(
          (p) => RealtimeMeetingMemberItem(
            id: p.id,
            avatarUrl: p.avatarUrl,
            name: p.displayName.isNotEmpty ? p.displayName : p.id,
            roleTitle: p.isLocal ? (strings.isZh ? '我' : 'You') : null,
            isMuted: p.isMuted,
            isVideoOff: !p.isVideoEnabled,
          ),
        )
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        child: RealtimeMeetingSidebar(
          members: members,
          initialTab: panel == DemoMeetingPanel.participants ? 1 : 0,
          chatWidget: const RealtimeChatPanel(),
          membersWidget: const RealtimeManagedParticipantList(),
          onClose: onClose,
        ),
      ),
    );
  }
}

/// Elapsed-time badge for the meeting dock (tabular figures, dot + text).
class DemoMeetingTimerBadge extends StatefulWidget {
  const DemoMeetingTimerBadge({super.key});

  @override
  State<DemoMeetingTimerBadge> createState() => _DemoMeetingTimerBadgeState();
}

class _DemoMeetingTimerBadgeState extends State<DemoMeetingTimerBadge> {
  late final DateTime _startTime;
  late final Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
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
