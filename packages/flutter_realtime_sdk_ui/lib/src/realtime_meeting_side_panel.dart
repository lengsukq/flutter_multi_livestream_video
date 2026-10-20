import 'package:flutter/material.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Side-panel selection for the built-in meeting layout.
///
/// Wide screens show a trailing column; narrow screens use a right drawer.
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
    this.workspaceMode = false,
    this.pinnedMessage,
    this.recordingPanel,
  });

  final RealtimeMeetingPanel panel;
  final int classroomTab;
  final int classroomPanelVisit;
  final VoidCallback onClose;

  /// Rooms with the classroom plugin use the reference workspace panel:
  /// underlined Chat / People / Q&A tabs instead of the segmented sidebar.
  final bool workspaceMode;
  final String? pinnedMessage;
  final Widget? recordingPanel;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final controller = RealtimeRoomUiScope.of(context);

    if (panel == RealtimeMeetingPanel.classroom ||
        (workspaceMode && panel == RealtimeMeetingPanel.chat) ||
        (workspaceMode && panel == RealtimeMeetingPanel.participants)) {
      if (workspaceMode) {
        final hasChat = controller.room.chat != null;
        // The classroom panel targets Q&A and the hand queue by label, not by
        // index: chat is optional and the queue tab only exists for teachers.
        final initialTab = panel == RealtimeMeetingPanel.participants
            ? (hasChat ? 1 : 0)
            : 0;
        return Container(
          decoration: BoxDecoration(
            color: style.surface,
            border: Border(left: BorderSide(color: style.border)),
          ),
          child: RealtimeClassroomSidePanel(
            key: ValueKey<int>(classroomPanelVisit),
            initialTab: initialTab,
            initialTabLabel: switch (panel) {
              RealtimeMeetingPanel.participants =>
                strings.isZh ? '成员' : 'People',
              RealtimeMeetingPanel.closed => null,
              _ when classroomTab == 1 && controller.canGrantSpeak =>
                strings.classroomHands,
              _ => strings.isZh ? '问答' : 'Q&A',
            },
            pinnedMessage: pinnedMessage,
            recordingPanel: recordingPanel,
            onClose: onClose,
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: style.surface,
          border: Border(left: BorderSide(color: style.border)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: style.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.classroom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: style.text,
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
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: style.border),
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
      );
    }

    final members = controller.snapshot.participants
        .map(
          (p) => RealtimeMeetingMemberItem(
            id: p.id,
            avatarUrl: p.avatarUrl,
            name: p.displayName.isNotEmpty ? p.displayName : p.id,
            roleTitle: p.isLocal ? (strings.isZh ? '我' : 'You') : null,
            isMuted: p.isMuted,
            isVideoOff: !p.isVideoEnabled,
            isSpeaking: p.isSpeaking,
            handRaised:
                controller.classroomState?.students
                    .where((student) => student.handRaised)
                    .any((student) => student.displayName == p.displayName) ??
                false,
          ),
        )
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(left: BorderSide(color: style.border)),
      ),
      child: RealtimeMeetingSidebar(
        members: members,
        initialTab: panel == RealtimeMeetingPanel.participants ? 1 : 0,
        chatWidget: const RealtimeChatPanel(),
        membersWidget: const RealtimeManagedParticipantList(),
        onClose: onClose,
      ),
    );
  }
}
