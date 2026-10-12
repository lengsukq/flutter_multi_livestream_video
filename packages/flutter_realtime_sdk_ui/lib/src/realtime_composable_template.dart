import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

import 'room_chat_components.dart';
import 'room_classroom_components.dart';
import 'room_classroom_interactions.dart';
import 'room_classroom_activities.dart';
import 'room_control_components.dart';
import 'room_live_components.dart';
import 'room_media_components.dart';
import 'room_ui_controller.dart';

/// Optional quick-start room page that uses only publicly exported components.
/// The application can instead place the same widgets in any layout.
class RealtimeComposableRoomTemplate extends StatefulWidget {
  const RealtimeComposableRoomTemplate({
    super.key,
    required this.room,
    this.isLive = false,
    this.onLeft,
  });
  final RealtimeRoom room;
  final bool isLive;
  final VoidCallback? onLeft;

  @override
  State<RealtimeComposableRoomTemplate> createState() =>
      _RealtimeComposableRoomTemplateState();
}

enum _TemplatePanel { closed, chat, members, questions, hands, activities }

class _RealtimeComposableRoomTemplateState
    extends State<RealtimeComposableRoomTemplate> {
  _TemplatePanel _panel = _TemplatePanel.closed;

  void _toggle(_TemplatePanel panel) =>
      setState(() => _panel = _panel == panel ? _TemplatePanel.closed : panel);

  Widget _sidebar() => switch (_panel) {
    _TemplatePanel.chat => const RealtimeChatPanel(),
    _TemplatePanel.members => const RealtimeManagedParticipantList(),
    _TemplatePanel.questions => const Column(
      children: [
        Expanded(child: RealtimeClassroomQuestions()),
        RealtimeClassroomQuestionComposer(),
      ],
    ),
    _TemplatePanel.hands => const RealtimeClassroomHandQueue(),
    _TemplatePanel.activities => const RealtimeClassroomActivityList(),
    _TemplatePanel.closed => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) => RealtimeRoomUiScope(
    room: widget.room,
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final isViewer = widget.room.media.role == MediaRole.viewer;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const RealtimeRoomInfo(),
                      if (wide) ...[
                        const SizedBox(width: 8),
                        const RealtimeConnectionIndicator(),
                      ],
                      const Spacer(),
                      if (widget.isLive) const RealtimeLiveStatus(),
                      RealtimeLeaveButton(onLeft: widget.onLeft),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: widget.isLive
                            ? const RealtimeLiveVideoStage()
                            : const RealtimeSharedContentStage(
                                members: RealtimeVideoGrid(),
                              ),
                      ),
                      if (wide && _panel != _TemplatePanel.closed)
                        SizedBox(width: 320, child: _sidebar()),
                    ],
                  ),
                ),
                if (!wide && _panel != _TemplatePanel.closed)
                  SizedBox(height: 210, child: _sidebar()),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!isViewer) ...[
                        const RealtimeMicrophoneButton(),
                        const RealtimeCameraButton(),
                        const RealtimeSwitchCameraButton(),
                        const RealtimeMediaDevicePicker(
                          kind: MediaDeviceKind.microphone,
                        ),
                        const RealtimeMediaDevicePicker(
                          kind: MediaDeviceKind.camera,
                        ),
                        if (widget.room.sharedContent != null)
                          const RealtimeSharedContentButton()
                        else
                          const RealtimeScreenShareButton(),
                      ],
                      if (widget.isLive) ...[
                        const RealtimeLiveLikeButton(),
                        const RealtimeLiveGiftButton(),
                      ],
                      if (widget.room.classroom != null) ...[
                        const RealtimeClassroomButton(),
                        const RealtimeRaiseHandButton(),
                        const RealtimeClassroomFeedbackButton(),
                        const RealtimeClassroomToolsButton(),
                        IconButton(
                          tooltip: 'Questions',
                          icon: const Icon(Icons.question_answer_outlined),
                          onPressed: () => _toggle(_TemplatePanel.questions),
                        ),
                        IconButton(
                          tooltip: 'Raised hands',
                          icon: const Icon(Icons.pan_tool_outlined),
                          onPressed: () => _toggle(_TemplatePanel.hands),
                        ),
                        IconButton(
                          tooltip: 'Polls and quizzes',
                          icon: const Icon(Icons.quiz_outlined),
                          onPressed: () => _toggle(_TemplatePanel.activities),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Participants',
                        icon: const Icon(Icons.people_outline),
                        onPressed: () => _toggle(_TemplatePanel.members),
                      ),
                      if (widget.room.chat != null)
                        IconButton(
                          tooltip: 'Chat',
                          icon: Icon(
                            _panel == _TemplatePanel.chat
                                ? Icons.close
                                : Icons.chat,
                          ),
                          onPressed: () => _toggle(_TemplatePanel.chat),
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
}
