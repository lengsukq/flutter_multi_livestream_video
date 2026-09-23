import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chime_exception.dart';
import '../models/chime_meeting_session.dart';
import '../models/meeting_event.model.dart';
import '../models/meeting_snapshot.dart';
import 'video_tile.view.dart';

/// Optional meeting surface. The caller owns joining, leaving, and disposing
/// [session]; removing this widget does not stop the native meeting.
class ChimeMeetingView extends StatefulWidget {
  const ChimeMeetingView({
    super.key,
    required this.session,
    this.title = 'Live meeting',
    this.onLeave,
  });

  final ChimeMeetingSession session;
  final String title;
  final FutureOr<void> Function()? onLeave;

  @override
  State<ChimeMeetingView> createState() => _ChimeMeetingViewState();
}

class _ChimeMeetingViewState extends State<ChimeMeetingView> {
  late final PageController _pageController;
  int _page = 0;
  CameraPosition _cameraPosition = CameraPosition.front;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MeetingSnapshot>(
    stream: widget.session.snapshots,
    initialData: widget.session.snapshot,
    builder: (context, stream) {
      final snapshot = stream.data ?? widget.session.snapshot;
      final attendeePages = (snapshot.attendees.length / 6).ceil();
      final pageCount =
          attendeePages + (snapshot.isReceivingScreenShare ? 1 : 0);
      final safePage = pageCount == 0
          ? 0
          : _page.clamp(0, pageCount - 1).toInt();
      if (safePage != _page && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(safePage);
          }
        });
      }

      return Material(
        color: const Color(0xFF090D16),
        child: SafeArea(
          child: Column(
            children: [
              _header(snapshot),
              Expanded(child: _meetingContent(snapshot, pageCount)),
              if (pageCount > 1) _pageIndicator(pageCount, safePage),
              _controls(snapshot),
            ],
          ),
        ),
      );
    },
  );

  Widget _header(MeetingSnapshot snapshot) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_stateLabel(snapshot.state)} · ${snapshot.attendees.length} participants',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Leave meeting',
          onPressed: _leave,
          icon: const Icon(Icons.call_end_rounded, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
        ),
      ],
    ),
  );

  Widget _meetingContent(MeetingSnapshot snapshot, int pageCount) {
    if (pageCount == 0) {
      final message = switch (snapshot.state) {
        MeetingState.idle => 'Call session.join(joinInfo) to join a meeting.',
        MeetingState.joining || MeetingState.connecting => 'Connecting…',
        MeetingState.reconnecting => 'Reconnecting…',
        MeetingState.failed => 'The meeting could not be joined.',
        MeetingState.ended => 'The meeting has ended.',
        MeetingState.leaving => 'Leaving meeting…',
        MeetingState.connected => 'Waiting for participants…',
        MeetingState.disposed => 'This meeting session was disposed.',
      };
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: pageCount,
      onPageChanged: (value) => setState(() => _page = value),
      itemBuilder: (context, index) {
        if (snapshot.isReceivingScreenShare && index == 0) {
          final tile = snapshot.contentShareTile!;
          return Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MeetingVideoTileView(tile: tile),
            ),
          );
        }
        final attendeePage = index - (snapshot.isReceivingScreenShare ? 1 : 0);
        final start = attendeePage * 6;
        final end = (start + 6).clamp(0, snapshot.attendees.length);
        return _attendeeGrid(snapshot.attendees.sublist(start, end));
      },
    );
  }

  Widget _attendeeGrid(List<MeetingAttendee> attendees) {
    if (attendees.isEmpty) {
      return const Center(
        child: Text(
          'No participants yet',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }
    final columns = attendees.length == 1 ? 1 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: attendees.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: columns == 1 ? 1.25 : 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => _attendeeTile(attendees[index]),
    );
  }

  Widget _attendeeTile(MeetingAttendee attendee) {
    final tile = attendee.videoTile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tile != null)
            MeetingVideoTileView(tile: tile)
          else
            ColoredBox(
              color: const Color(0xFF1E293B),
              child: Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    attendee.externalUserId.isEmpty
                        ? '?'
                        : attendee.externalUserId.characters.first
                              .toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    attendee.externalUserId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                if (attendee.isMuted)
                  const Icon(
                    Icons.mic_off_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageIndicator(int pageCount, int currentPage) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => Container(
          width: index == currentPage ? 16 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == currentPage
                ? const Color(0xFF818CF8)
                : Colors.white38,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ),
  );

  Widget _controls(MeetingSnapshot snapshot) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _control(
          icon: snapshot.localMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: snapshot.localMuted ? 'Unmute' : 'Mute',
          onPressed: () => _run(() => widget.session.toggleMute()),
        ),
        _control(
          icon: snapshot.localVideoEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: snapshot.localVideoEnabled ? 'Stop video' : 'Start video',
          onPressed: () => _run(
            () => widget.session.setVideoEnabled(!snapshot.localVideoEnabled),
          ),
        ),
        _control(
          icon: Icons.flip_camera_ios_rounded,
          label: 'Switch camera',
          onPressed: () => _run(_switchCamera),
        ),
        _control(
          icon: Icons.headphones_rounded,
          label: 'Audio devices',
          onPressed: _showAudioDevices,
        ),
        _control(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Messages',
          onPressed: _showMessages,
        ),
      ],
    ),
  );

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    icon: Icon(icon, color: Colors.white),
    style: IconButton.styleFrom(backgroundColor: const Color(0xFF263247)),
  );

  Future<void> _switchCamera() async {
    final next = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    await widget.session.switchCamera(next);
    _cameraPosition = next;
  }

  Future<void> _showAudioDevices() async {
    final devices = await widget.session.listAudioDevices();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Audio output device')),
            for (final device in devices)
              ListTile(
                title: Text(device.label),
                trailing:
                    widget.session.snapshot.selectedAudioDevice?.label ==
                        device.label
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await _run(() => widget.session.selectAudioDevice(device));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessages() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Meeting messages'),
                SizedBox(
                  height: 240,
                  child: StreamBuilder<MeetingSnapshot>(
                    stream: widget.session.snapshots,
                    initialData: widget.session.snapshot,
                    builder: (context, stream) {
                      final messages = stream.data?.messages ?? const [];
                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - index - 1];
                          return ListTile(
                            dense: true,
                            title: Text(message.externalUserId),
                            subtitle: Text(message.message),
                          );
                        },
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: controller)),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        try {
                          await widget.session.sendMessage(text);
                          controller.clear();
                          setSheetState(() {});
                        } catch (error) {
                          if (context.mounted) _showError(error);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _leave() async {
    try {
      await widget.session.leave();
      await widget.onLeave?.call();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ChimeException ? error.message : error.toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _stateLabel(MeetingState state) => switch (state) {
    MeetingState.idle => 'Not joined',
    MeetingState.joining => 'Joining',
    MeetingState.connecting => 'Connecting',
    MeetingState.connected => 'Connected',
    MeetingState.reconnecting => 'Reconnecting',
    MeetingState.leaving => 'Leaving',
    MeetingState.ended => 'Ended',
    MeetingState.failed => 'Failed',
    MeetingState.disposed => 'Disposed',
  };
}
