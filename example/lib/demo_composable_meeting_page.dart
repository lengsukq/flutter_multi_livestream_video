import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'demo_background.dart';
import 'widgets/demo_recording_widgets.dart';

/// Demo-owned layout: the SDK supplies only stateful functional widgets.
///
/// This page intentionally does not use MediaRoomView or RealtimeRoomView.
/// Apps can replace any Row/Column/Stack here without touching the SDK.
class DemoComposableMeetingPage extends StatefulWidget {
  const DemoComposableMeetingPage({
    super.key,
    required this.room,
    required this.initialSettings,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  State<DemoComposableMeetingPage> createState() =>
      _DemoComposableMeetingPageState();
}

enum _DemoSidePanel { closed, chat, participants, classroom }

class _DemoComposableMeetingPageState extends State<DemoComposableMeetingPage> {
  late Future<void> _videoEffectsReady;
  _DemoSidePanel _panel = _DemoSidePanel.closed;

  @override
  void initState() {
    super.initState();
    _videoEffectsReady = _prepare();
  }

  Future<void> _prepare() async {
    await widget.room.prepareVideoEffects(widget.initialSettings);
    await widget.room.sharedContent?.start();
  }

  @override
  void didUpdateWidget(covariant DemoComposableMeetingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.initialSettings != widget.initialSettings) {
      _videoEffectsReady = _prepare();
      _panel = _DemoSidePanel.closed;
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(zh ? '离开会议' : 'Leave meeting'),
            content: Text(zh ? '确定离开当前房间吗？' : 'Leave this room?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(zh ? '取消' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(zh ? '离开' : 'Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _onLeft() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _openEffects(BuildContext context) async {
    final presets = await DemoBackground.presets;
    if (!context.mounted) return;
    final controller = RealtimeRoomUiScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BackgroundEffectSelector(
              capabilities: controller.room.backgroundCapabilities,
              effect: controller.room.backgroundEffect,
              imagePresets: presets,
              busy: controller.isPending(RealtimeRoomUiAction.backgroundEffect),
              onChanged: (effect) async {
                try {
                  await controller.setBackgroundEffect(effect);
                  if (sheetContext.mounted) updateSheet(() {});
                } catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.maybeOf(
                      sheetContext,
                    )?.showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _videoEffectsReady,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: () => setState(() {
                    _videoEffectsReady = _prepare();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      return RealtimeRoomUiScope(
        room: widget.room,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final zh = Localizations.localeOf(context).languageCode == 'zh';
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.meeting_room_outlined),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: RealtimeRoomInfo(),
                            ),
                          ),
                          DemoRecordingBadge(room: widget.room),
                          if (wide) ...[
                            const SizedBox(width: 12),
                            const RealtimeConnectionIndicator(),
                          ],
                          RealtimeLeaveButton(
                            onConfirm: _confirmLeave,
                            onLeft: _onLeft,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Expanded(child: _DemoMeetingStage()),
                          if (wide && _panel != _DemoSidePanel.closed)
                            SizedBox(width: 320, child: _sidePanel()),
                        ],
                      ),
                    ),
                    if (!wide && _panel != _DemoSidePanel.closed)
                      SizedBox(height: 230, child: _sidePanel()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: RealtimeMeetingDock(
                        showLabels: wide,
                        mediaGroup: [
                          RealtimeDockMicrophoneButton(showLabel: wide),
                          RealtimeDockCameraButton(showLabel: wide),
                          RealtimeRoomActionButton(
                            action: RealtimeRoomUiAction.switchCamera,
                            builder: (context, onPressed, active, pending) =>
                                RealtimeDockItem(
                                  icon: Icons.cameraswitch_rounded,
                                  label: zh ? '翻转' : 'Flip',
                                  isLoading: pending,
                                  onPressed: onPressed,
                                  showLabel: wide,
                                ),
                          ),
                          RealtimeDockItem(
                            icon: Icons.blur_on_rounded,
                            label: zh ? '背景' : 'Effects',
                            onPressed: () => _openEffects(context),
                            showLabel: wide,
                          ),
                          DemoRecordingButton(room: widget.room),
                        ],
                        collaborationGroup: [
                          RealtimeDockSharedContentButton(showLabel: wide),
                          if (widget.room.classroom != null) ...[
                            const RealtimeRaiseHandButton(),
                            const RealtimeClassroomFeedbackButton(),
                            if (wide) const RealtimeClassroomEngagement(),
                          ],
                        ],
                        panelsGroup: [
                          if (widget.room.chat != null)
                            RealtimeDockItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: zh ? '聊天' : 'Chat',
                              isActive: _panel == _DemoSidePanel.chat,
                              onPressed: () => _toggle(_DemoSidePanel.chat),
                              showLabel: wide,
                            ),
                          RealtimeDockItem(
                            icon: Icons.people_outline_rounded,
                            label: zh ? '成员' : 'Members',
                            isActive: _panel == _DemoSidePanel.participants,
                            onPressed: () =>
                                _toggle(_DemoSidePanel.participants),
                            showLabel: wide,
                          ),
                          if (widget.room.classroom != null)
                            RealtimeDockItem(
                              icon: Icons.school_outlined,
                              label: zh ? '课堂管理' : 'Classroom',
                              isActive: _panel == _DemoSidePanel.classroom,
                              onPressed: () =>
                                  _toggle(_DemoSidePanel.classroom),
                              showLabel: wide,
                            ),
                        ],
                        exitAction: RealtimeDockItem(
                          icon: Icons.call_end_rounded,
                          label: zh ? '离开' : 'Leave',
                          isDanger: true,
                          onPressed: () async {
                            if (await _confirmLeave(context)) {
                              if (context.mounted) {
                                final controller = RealtimeRoomUiScope.of(
                                  context,
                                );
                                await controller.leave();
                                _onLeft();
                              }
                            }
                          },
                          showLabel: wide,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );

  void _toggle(_DemoSidePanel panel) => setState(() {
    _panel = _panel == panel ? _DemoSidePanel.closed : panel;
  });

  Widget _sidePanel() {
    if (_panel == _DemoSidePanel.classroom) {
      return _ClassroomSidePanel(
        onClose: () => setState(() => _panel = _DemoSidePanel.closed),
      );
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(switch (_panel) {
                  _DemoSidePanel.chat => zh ? '实时聊天' : 'Chat',
                  _ => zh ? '参会成员' : 'Participants',
                }, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: zh ? '关闭面板' : 'Close panel',
                onPressed: () => setState(() => _panel = _DemoSidePanel.closed),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (_panel) {
              _DemoSidePanel.chat => const RealtimeChatPanel(),
              _ => const RealtimeManagedParticipantList(),
            },
          ),
        ],
      ),
    );
  }
}

class _ClassroomSidePanel extends StatefulWidget {
  const _ClassroomSidePanel({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_ClassroomSidePanel> createState() => _ClassroomSidePanelState();
}

class _ClassroomSidePanelState extends State<_ClassroomSidePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  tabs: [
                    Tab(text: zh ? '提问' : 'Questions'),
                    Tab(text: zh ? '举手' : 'Hands'),
                    Tab(text: zh ? '花名册' : 'Roster'),
                    Tab(text: zh ? '测验' : 'Activities'),
                  ],
                ),
              ),
              IconButton(
                tooltip: zh ? '关闭面板' : 'Close panel',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                Column(
                  children: [
                    Expanded(child: RealtimeClassroomQuestions()),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: RealtimeClassroomQuestionComposer(),
                    ),
                  ],
                ),
                RealtimeClassroomHandQueue(),
                RealtimeClassroomRoster(),
                RealtimeClassroomActivityList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoMeetingStage extends StatelessWidget {
  const _DemoMeetingStage();

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => RealtimeSharedContentStage(
        members: controller.snapshot.contentShareTrack != null
            ? const RealtimeScreenShareStage()
            : const RealtimeVideoGrid(),
      ),
    );
  }
}
