import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

import 'room_chat_components.dart';
import 'room_classroom_components.dart';
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

class _RealtimeComposableRoomTemplateState
    extends State<RealtimeComposableRoomTemplate> {
  bool _chatOpen = false;

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
                      const Expanded(child: RealtimeRoomInfo()),
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
                      if (wide && _chatOpen)
                        const SizedBox(width: 320, child: RealtimeChatPanel()),
                    ],
                  ),
                ),
                if (!wide && _chatOpen)
                  const SizedBox(height: 210, child: RealtimeChatPanel()),
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
                        if (widget.room.sharedContent != null)
                          const RealtimeSharedContentButton()
                        else
                          const RealtimeScreenShareButton(),
                      ],
                      if (widget.isLive) ...[
                        const RealtimeLiveLikeButton(),
                        const RealtimeLiveGiftButton(),
                      ],
                      if (widget.room.classroom != null)
                        const RealtimeClassroomButton(),
                      if (widget.room.chat != null)
                        IconButton(
                          tooltip: 'Chat',
                          icon: Icon(_chatOpen ? Icons.close : Icons.chat),
                          onPressed: () =>
                              setState(() => _chatOpen = !_chatOpen),
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
