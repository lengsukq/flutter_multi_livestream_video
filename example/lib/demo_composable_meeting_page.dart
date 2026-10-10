import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'demo_background.dart';

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

enum _DemoSidePanel {
  closed,
  chat,
  participants,
  questions,
  hands,
  roster,
  activities,
}

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
                            SizedBox(width: 310, child: _sidePanel()),
                        ],
                      ),
                    ),
                    if (!wide && _panel != _DemoSidePanel.closed)
                      SizedBox(height: 220, child: _sidePanel()),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const RealtimeMicrophoneButton(),
                          const RealtimeCameraButton(),
                          const RealtimeSwitchCameraButton(),
                          const RealtimeAudioOutputButton(),
                          FutureBuilder<List<MediaBackgroundImagePreset>>(
                            future: DemoBackground.presets,
                            builder: (context, snapshot) =>
                                RealtimeBackgroundEffectsButton(
                                  imagePresets: snapshot.data ?? const [],
                                ),
                          ),
                          if (widget.room.sharedContent == null)
                            const RealtimeScreenShareButton(),
                          if (widget.room.classroom != null) ...[
                            const RealtimeClassroomButton(),
                            const RealtimeRaiseHandButton(),
                            const RealtimeClassroomFeedbackButton(),
                            const RealtimeClassroomToolsButton(),
                            if (wide) const RealtimeClassroomEngagement(),
                            const RealtimeSharedContentButton(),
                            IconButton(
                              tooltip: 'Classroom questions',
                              icon: const Icon(Icons.question_answer_outlined),
                              onPressed: () =>
                                  _toggle(_DemoSidePanel.questions),
                            ),
                            IconButton(
                              tooltip: 'Raised hands',
                              icon: const Icon(Icons.pan_tool_alt_outlined),
                              onPressed: () => _toggle(_DemoSidePanel.hands),
                            ),
                            IconButton(
                              tooltip: 'Classroom roster',
                              icon: const Icon(Icons.school_outlined),
                              onPressed: () => _toggle(_DemoSidePanel.roster),
                            ),
                            IconButton(
                              tooltip: 'Classroom activities',
                              icon: const Icon(Icons.quiz_outlined),
                              onPressed: () =>
                                  _toggle(_DemoSidePanel.activities),
                            ),
                          ],
                          if (widget.room.chat != null)
                            IconButton(
                              tooltip: 'Chat',
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () => _toggle(_DemoSidePanel.chat),
                            ),
                          IconButton(
                            tooltip: 'Participants',
                            icon: const Icon(Icons.people_outline),
                            onPressed: () =>
                                _toggle(_DemoSidePanel.participants),
                          ),
                        ],
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

  Widget _sidePanel() => Card(
    margin: const EdgeInsets.all(8),
    child: Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(switch (_panel) {
                _DemoSidePanel.chat => 'Chat',
                _DemoSidePanel.questions => 'Questions',
                _DemoSidePanel.hands => 'Raised hands',
                _DemoSidePanel.roster => 'Classroom roster',
                _DemoSidePanel.activities => 'Polls and quizzes',
                _ => 'Participants',
              }),
            ),
            IconButton(
              tooltip: 'Close panel',
              onPressed: () => setState(() => _panel = _DemoSidePanel.closed),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Expanded(
          child: switch (_panel) {
            _DemoSidePanel.chat => const RealtimeChatPanel(),
            _DemoSidePanel.questions => const Column(
              children: [
                Expanded(child: RealtimeClassroomQuestions()),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: RealtimeClassroomQuestionComposer(),
                ),
              ],
            ),
            _DemoSidePanel.hands => const RealtimeClassroomHandQueue(),
            _DemoSidePanel.roster => const RealtimeClassroomRoster(),
            _DemoSidePanel.activities => const RealtimeClassroomActivityList(),
            _ => const RealtimeParticipantList(),
          },
        ),
      ],
    ),
  );
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
