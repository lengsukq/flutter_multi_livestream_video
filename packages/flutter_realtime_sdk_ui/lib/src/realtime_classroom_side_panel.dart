import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'realtime_classroom_workspace.dart';
import 'realtime_classroom_notes_panel.dart';
import 'room_chat_components.dart';
import 'room_classroom_interactions.dart';
import 'room_ui_controller.dart';

/// Reference workspace side panel: flat underline tabs.
///
/// Chat/People are capability-driven. A classroom consolidates hands, Q&A and
/// polls under one tab. Recording and persisted Notes are only shown when
/// their corresponding real components are supplied by the host.
class RealtimeClassroomSidePanel extends StatefulWidget {
  const RealtimeClassroomSidePanel({
    super.key,
    this.initialTab = 0,
    this.initialTabLabel,
    this.pinnedMessage,
    this.onClose,
    this.recordingPanel,
    this.notesPanel,
    this.initialTabId,
    this.initialClassroomSection,
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

  /// Optional host-persisted notes content; no synthetic local notes.
  final Widget? notesPanel;
  final RealtimeWorkspaceTab? initialTabId;
  final RealtimeClassroomSection? initialClassroomSection;

  @override
  State<RealtimeClassroomSidePanel> createState() =>
      _RealtimeClassroomSidePanelState();
}

/// Stable navigation identity independent of the translated label or
/// the presence of chat and recording capabilities.
enum RealtimeWorkspaceTab { chat, people, classroom, recording, notes }

class _RealtimeClassroomSidePanelState
    extends State<RealtimeClassroomSidePanel> {
  RealtimeWorkspaceTab? _userSelected;

  @override
  void didUpdateWidget(covariant RealtimeClassroomSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialTabLabel != widget.initialTabLabel ||
        oldWidget.initialTabId != widget.initialTabId) {
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
        final notesAvailable =
            classroom?.isTeacher == true &&
            (widget.notesPanel != null || classroom?.notes != null);
        final hasChat = controller.room.chat != null;
        final pending = classroom?.stats.pendingQuestions ?? 0;
        final online = classroom?.stats.onlineCount ?? 0;
        final hands = controller.canGrantSpeak
            ? classroom?.raisedHands.length ?? 0
            : 0;
        final tabs = <({RealtimeWorkspaceTab id, String label, int? badge})>[
          if (hasChat)
            (id: RealtimeWorkspaceTab.chat, label: strings.chat, badge: null),
          (
            id: RealtimeWorkspaceTab.people,
            label: strings.isZh ? '成员' : 'People',
            badge: online > 0 ? online : null,
          ),
          if (classroom != null)
            (
              id: RealtimeWorkspaceTab.classroom,
              label: strings.isZh ? '课堂' : 'Classroom',
              badge: hands + pending > 0 ? hands + pending : null,
            ),
          if (widget.recordingPanel != null)
            (
              id: RealtimeWorkspaceTab.recording,
              label: strings.isZh ? '录制' : 'Recording',
              badge: null,
            ),
          if (notesAvailable)
            (
              id: RealtimeWorkspaceTab.notes,
              label: strings.isZh ? '笔记' : 'Notes',
              badge: null,
            ),
        ];

        final ids = tabs.map((tab) => tab.id).toList(growable: false);
        final selectedId = _resolveSelected(ids);
        final selected = ids.indexOf(selectedId);
        final pages = <Widget>[
          if (hasChat)
            _ChatTab(pinnedMessage: widget.pinnedMessage, strings: strings),
          const _PeopleTab(),
          if (classroom != null)
            RealtimeClassroomWorkspace(
              initialSection: _initialClassroomSection(strings),
            ),
          if (widget.recordingPanel != null) widget.recordingPanel!,
          if (notesAvailable)
            widget.notesPanel ?? const RealtimeClassroomNotesPanel(),
        ];
        return ColoredBox(
          color: style.surface,
          child: Column(
            children: [
              _UnderlineTabs(
                tabs: [
                  for (final tab in tabs)
                    (
                      label: tab.label,
                      badge: tab.badge,
                      icon: switch (tab.id) {
                        RealtimeWorkspaceTab.chat =>
                          Icons.chat_bubble_outline_rounded,
                        RealtimeWorkspaceTab.people =>
                          Icons.people_outline_rounded,
                        RealtimeWorkspaceTab.classroom => Icons.school_outlined,
                        RealtimeWorkspaceTab.recording =>
                          Icons.radio_button_checked_rounded,
                        RealtimeWorkspaceTab.notes => Icons.notes_rounded,
                      },
                    ),
                ],
                selected: selected,
                onSelected: (index) =>
                    setState(() => _userSelected = ids[index]),
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

  RealtimeWorkspaceTab _resolveSelected(List<RealtimeWorkspaceTab> ids) {
    if (_userSelected != null && ids.contains(_userSelected)) {
      return _userSelected!;
    }
    if (widget.initialTabId case final id? when ids.contains(id)) {
      return id;
    }
    final label = widget.initialTabLabel;
    final mapped = switch (label) {
      'Hands' || '举手' || 'Q&A' || '问答' => RealtimeWorkspaceTab.classroom,
      'People' || '成员' => RealtimeWorkspaceTab.people,
      'Chat' || '聊天' => RealtimeWorkspaceTab.chat,
      'Recording' || '录制' => RealtimeWorkspaceTab.recording,
      'Notes' || '笔记' => RealtimeWorkspaceTab.notes,
      _ => null,
    };
    if (mapped != null && ids.contains(mapped)) return mapped;
    return ids[widget.initialTab.clamp(0, ids.length - 1)];
  }

  RealtimeClassroomSection _initialClassroomSection(RealtimeStrings strings) {
    if (widget.initialClassroomSection case final section?) return section;
    final label = widget.initialTabLabel;
    if (label == strings.classroomHands || label == 'Hands' || label == '举手') {
      return RealtimeClassroomSection.hands;
    }
    if (label == 'Q&A' || label == '问答') {
      return RealtimeClassroomSection.questions;
    }
    return RealtimeClassroomSection.overview;
  }
}

class _UnderlineTabs extends StatefulWidget {
  const _UnderlineTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.onClose,
  });

  final List<({String label, int? badge, IconData icon})> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback? onClose;

  @override
  State<_UnderlineTabs> createState() => _UnderlineTabsState();
}

class _UnderlineTabsState extends State<_UnderlineTabs> {
  final _scroll = ScrollController();
  final _anchors = <GlobalKey>[];
  bool _hasPrevious = false;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_refresh);
    _scheduleSelectedVisibility();
  }

  @override
  void didUpdateWidget(covariant _UnderlineTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected ||
        widget.tabs.length != oldWidget.tabs.length) {
      _scheduleSelectedVisibility();
    }
  }

  void _scheduleSelectedVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selected >= _anchors.length) return;
      final target = _anchors[widget.selected].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: RealtimeUiTokens.animFast,
          curve: Curves.easeOutCubic,
        );
      }
      _refresh();
    });
  }

  void _refresh() {
    if (!mounted) return;
    final previous = _ready && _scroll.offset > 1;
    final next =
        _ready && _scroll.offset < _scroll.position.maxScrollExtent - 1;
    if (previous == _hasPrevious && next == _hasNext) return;
    setState(() {
      _hasPrevious = previous;
      _hasNext = next;
    });
  }

  bool get _ready =>
      _scroll.hasClients && _scroll.position.hasContentDimensions;

  void _move(int sign) {
    if (!_ready) return;
    final position = _scroll.position;
    _scroll.animateTo(
      (_scroll.offset + sign * 150).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: RealtimeUiTokens.animFast,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.removeListener(_refresh);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    while (_anchors.length < widget.tabs.length) {
      _anchors.add(GlobalKey());
    }
    if (_anchors.length > widget.tabs.length) {
      _anchors.removeRange(widget.tabs.length, _anchors.length);
    }
    final style = RealtimeStyle.of(context);
    final zh = RealtimeStrings.of(context).isZh;
    final left = _hasPrevious;
    final right = _hasNext;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: style.border)),
      ),
      child: Row(
        children: [
          if (left)
            IconButton(
              tooltip: zh ? '上一组标签' : 'Previous sidebar tabs',
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left_rounded, size: 19),
              constraints: const BoxConstraints.tightFor(width: 27, height: 38),
              padding: EdgeInsets.zero,
            ),
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.tabs.length; i++)
                      _UnderlineTabButton(
                        key: _anchors[i],
                        label: widget.tabs[i].label,
                        icon: widget.tabs[i].icon,
                        badge: widget.tabs[i].badge,
                        selected: i == widget.selected,
                        onTap: () => widget.onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (right)
            IconButton(
              tooltip: zh ? '下一组标签' : 'Next sidebar tabs',
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right_rounded, size: 19),
              constraints: const BoxConstraints.tightFor(width: 27, height: 38),
              padding: EdgeInsets.zero,
            ),
          if (widget.onClose != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: zh ? '关闭侧边栏' : 'Close Sidebar',
                onPressed: widget.onClose,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnderlineTabButton extends StatelessWidget {
  const _UnderlineTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: RealtimeUiTokens.animFast,
          curve: Curves.easeOutCubic,
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? style.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? style.text : style.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
