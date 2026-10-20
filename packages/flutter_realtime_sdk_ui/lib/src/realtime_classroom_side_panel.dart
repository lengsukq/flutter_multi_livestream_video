import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_chat_components.dart';
import 'room_classroom_interactions.dart';
import 'room_ui_controller.dart';

/// Reference workspace side panel: flat underline tabs.
///
/// Non-classroom rooms show Chat and People; classroom rooms add Q&A. When the
/// room has a configured recorder, an extra Recording tab is appended. Every
/// tab reuses an SDK component, so the panel never keeps a private copy of
/// room state.
class RealtimeClassroomSidePanel extends StatefulWidget {
  const RealtimeClassroomSidePanel({
    super.key,
    this.initialTab = 0,
    this.initialTabLabel,
    this.pinnedMessage,
    this.onClose,
    this.recordingPanel,
  });

  final int initialTab;

  /// Optional semantic target resolved after the tab list is known, so the
  /// hand queue stays directly reachable when chat is absent.
  final String? initialTabLabel;

  /// Host-provided message pinned above the chat stream.
  final String? pinnedMessage;
  final VoidCallback? onClose;

  /// Optional recording view shown as a trailing tab.
  final Widget? recordingPanel;

  @override
  State<RealtimeClassroomSidePanel> createState() =>
      _RealtimeClassroomSidePanelState();
}

class _RealtimeClassroomSidePanelState
    extends State<RealtimeClassroomSidePanel> {
  int? _userSelected;

  @override
  void didUpdateWidget(covariant RealtimeClassroomSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialTabLabel != widget.initialTabLabel) {
      _userSelected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final classroom = controller.classroomState;
        final state = classroom;
        final hasChat = controller.room.chat != null;
        final pending =
            state?.questions
                .where((q) => q.status == ClassroomQuestionStatus.pending)
                .length ??
            0;
        final online = state?.stats.onlineCount ?? 0;
        final hands = controller.canGrantSpeak
            ? state?.raisedHands.length ?? 0
            : 0;

        final tabs = <({String label, int? badge})>[
          if (hasChat) (label: strings.chat, badge: null),
          (
            label: strings.isZh ? '成员' : 'People',
            badge: online > 0 ? online : null,
          ),
          if (controller.canGrantSpeak)
            (label: strings.classroomHands, badge: hands > 0 ? hands : null),
          if (classroom != null)
            (
              label: strings.isZh ? '问答' : 'Q&A',
              badge: pending > 0 ? pending : null,
            ),
          if (widget.recordingPanel != null)
            (label: strings.isZh ? '录制' : 'Recording', badge: null),
        ];
        final selected = _resolveSelected(tabs);

        final pages = <Widget>[
          if (hasChat)
            _ChatTab(pinnedMessage: widget.pinnedMessage, strings: strings),
          const _PeopleTab(),
          if (controller.canGrantSpeak) const RealtimeClassroomHandQueue(),
          if (classroom != null) _QuestionsTab(strings: strings),
          if (widget.recordingPanel != null) widget.recordingPanel!,
        ];

        return ColoredBox(
          color: style.surface,
          child: Column(
            children: [
              _UnderlineTabs(
                tabs: tabs,
                selected: selected,
                onSelected: (index) => setState(() => _userSelected = index),
                onClose: widget.onClose,
              ),
              Expanded(
                child: IndexedStack(index: selected, children: pages),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Resolves the opening tab against the tabs actually rendered. Chat and
  /// the teacher hand queue are optional, so raw indexes drift between rooms;
  /// a user tap always wins afterwards.
  int _resolveSelected(List<({String label, int? badge})> tabs) {
    if (_userSelected case final index?) {
      return index.clamp(0, tabs.length - 1);
    }
    final label = widget.initialTabLabel;
    if (label != null) {
      for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].label == label) return i;
      }
    }
    return widget.initialTab.clamp(0, tabs.length - 1);
  }
}

class _UnderlineTabs extends StatelessWidget {
  const _UnderlineTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.onClose,
  });

  final List<({String label, int? badge})> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: style.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _UnderlineTabButton(
                      label: tabs[i].label,
                      badge: tabs[i].badge,
                      selected: i == selected,
                      onTap: () => onSelected(i),
                    ),
                ],
              ),
            ),
          ),
          if (onClose != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Close Sidebar',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnderlineTabButton extends StatelessWidget {
  const _UnderlineTabButton({
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: RealtimeUiTokens.animFast,
          height: 51,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? style.text : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? style.text : style.textMuted,
                ),
              ),
              if (badge case final badge?) ...[
                const SizedBox(width: 4),
                RealtimeBadge(
                  text: '$badge',
                  fontSize: 10,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({required this.pinnedMessage, required this.strings});
  final String? pinnedMessage;
  final RealtimeStrings strings;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    if (pinnedMessage == null) {
      return const RealtimeChatPanel(timelineStyle: true);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: style.accentSoft,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.push_pin_outlined, size: 16, color: style.text),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.isZh ? '置顶消息' : 'Pinned message',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: style.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pinnedMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: style.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Expanded(child: RealtimeChatPanel(timelineStyle: true)),
      ],
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  const _QuestionsTab({required this.strings});
  final RealtimeStrings strings;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          const Expanded(child: RealtimeClassroomQuestions()),
          if (controller.canAskQuestion)
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: RealtimeClassroomQuestionComposer(),
            ),
        ],
      ),
    );
  }
}

/// People tab: the classroom roster when the plugin is present, otherwise the
/// managed RTC/chat directory so plain meetings still list members.
class _PeopleTab extends StatelessWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context) {
    final classroom = RealtimeRoomUiScope.of(context).classroomState;
    return classroom == null
        ? const RealtimeManagedParticipantList()
        : const RealtimeClassroomRoster();
  }
}
