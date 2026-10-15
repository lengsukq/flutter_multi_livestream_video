import 'package:flutter/material.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Side-panel selection for the built-in meeting layout.
///
/// Wide screens show a trailing column; narrow screens use a bottom sheet.
enum RealtimeMeetingPanel { closed, chat, participants, classroom }

/// Trailing side panel: classroom tools or chat/participants sidebar.
///
/// Must be built under a [RealtimeRoomUiScope].
class RealtimeMeetingSidePanel extends StatelessWidget {
  const RealtimeMeetingSidePanel({
    super.key,
    required this.panel,
    required this.classroomTab,
    required this.classroomPanelVisit,
    required this.onClose,
  });

  final RealtimeMeetingPanel panel;
  final int classroomTab;
  final int classroomPanelVisit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final RealtimeStrings strings = RealtimeStrings.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RealtimeRoomUiController controller = RealtimeRoomUiScope.of(context);

    if (panel == RealtimeMeetingPanel.classroom) {
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
          initialTab: panel == RealtimeMeetingPanel.participants ? 1 : 0,
          chatWidget: const RealtimeChatPanel(),
          membersWidget: const RealtimeManagedParticipantList(),
          onClose: onClose,
        ),
      ),
    );
  }
}
