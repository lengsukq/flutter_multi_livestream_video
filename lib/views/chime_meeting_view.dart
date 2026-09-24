import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chime_exception.dart';
import '../models/chime_meeting_session.dart';
import '../models/meeting_event.model.dart';
import '../models/meeting_snapshot.dart';
import 'video_tile.view.dart';

/// Optional meeting surface with modern clean minimalist styling.
/// The caller owns joining, leaving, and disposing [session]; removing this widget
/// does not stop the native meeting.
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

  Timer? _durationTimer;
  int _callSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String get _formattedDuration {
    final mins = _callSeconds ~/ 60;
    final secs = _callSeconds % 60;
    final mStr = mins.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');
    return '$mStr:$sStr';
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
        color: const Color(0xFFF8FAFC),
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

  Widget _header(MeetingSnapshot snapshot) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: Row(
      children: [
        // Back / Leave button
        Tooltip(
          message: 'Leave meeting',
          child: InkWell(
            onTap: _confirmLeave,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_stateLabel(snapshot.state)} · ${snapshot.attendees.length} participants',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
              ),
            ],
          ),
        ),
        // Duration timer pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _formattedDuration,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Leave Meeting?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        content: const Text(
          'Are you sure you want to disconnect from this meeting?',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await _leave();
    }
  }

  Widget _meetingContent(MeetingSnapshot snapshot, int pageCount) {
    if (pageCount == 0) {
      final message = switch (snapshot.state) {
        MeetingState.idle => 'Call session.join(joinInfo) to join a meeting.',
        MeetingState.joining || MeetingState.connecting => 'Connecting…',
        MeetingState.reconnecting => 'Reconnecting…',
        MeetingState.failed => 'The meeting could not be joined.',
        MeetingState.ended => 'The meeting has ended.',
        MeetingState.leaving => 'Leaving meeting…',
        MeetingState.connected => 'Waiting for participants to join…',
        MeetingState.disposed => 'This meeting session was disposed.',
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEEF2FF),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF4F46E5), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: MeetingVideoTileView(tile: tile),
              ),
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
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns;
        double aspectRatio;

        if (width > 800) {
          columns = attendees.length <= 2 ? 2 : 3;
          aspectRatio = 16 / 10;
        } else if (width > 500) {
          columns = attendees.length == 1 ? 1 : 2;
          aspectRatio = 4 / 3;
        } else {
          columns = attendees.length == 1 ? 1 : 2;
          aspectRatio = attendees.length == 1 ? 4 / 3 : 1.0;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: attendees.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => _attendeeTile(attendees[index]),
        );
      },
    );
  }

  Widget _attendeeTile(MeetingAttendee attendee) {
    final tile = attendee.videoTile;
    final name = attendee.externalUserId.isEmpty ? 'Participant' : attendee.externalUserId;
    final initial = name.characters.first.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tile != null)
              MeetingVideoTileView(tile: tile)
            else
              Container(
                color: const Color(0xFFF8FAFC),
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (attendee.isMuted)
                      const Icon(
                        Icons.mic_off_rounded,
                        color: Color(0xFFDC2626),
                        size: 14,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          width: index == currentPage ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == currentPage
                ? const Color(0xFF4F46E5)
                : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    ),
  );

  Widget _controls(MeetingSnapshot snapshot) => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 18,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _control(
            icon: snapshot.localMuted ? Icons.mic_off_outlined : Icons.mic_none_rounded,
            label: snapshot.localMuted ? 'Unmute' : 'Mute',
            isActive: !snapshot.localMuted,
            isDanger: snapshot.localMuted,
            onPressed: () => _run(() => widget.session.toggleMute()),
          ),
          const SizedBox(width: 8),
          _control(
            icon: snapshot.localVideoEnabled
                ? Icons.videocam_outlined
                : Icons.videocam_off_outlined,
            label: snapshot.localVideoEnabled ? 'Stop video' : 'Start video',
            isActive: snapshot.localVideoEnabled,
            onPressed: () => _run(
              () => widget.session.setVideoEnabled(!snapshot.localVideoEnabled),
            ),
          ),
          const SizedBox(width: 8),
          _control(
            icon: Icons.flip_camera_ios_outlined,
            label: 'Switch camera',
            onPressed: () => _run(_switchCamera),
          ),
          const SizedBox(width: 8),
          _control(
            icon: Icons.headphones_outlined,
            label: 'Audio devices',
            onPressed: _showAudioDevices,
          ),
          const SizedBox(width: 8),
          _control(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            onPressed: _showMessages,
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Leave Meeting',
            child: InkWell(
              onTap: _confirmLeave,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    bool isDanger = false,
  }) {
    Color bg;
    Color fg;
    Color border;

    if (isDanger) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      border = const Color(0xFFFECDD3);
    } else if (isActive) {
      bg = const Color(0xFFEEF2FF);
      fg = const Color(0xFF4F46E5);
      border = const Color(0xFFC7D2FE);
    } else {
      bg = const Color(0xFFF8FAFC);
      fg = const Color(0xFF475569);
      border = const Color(0xFFE2E8F0);
    }

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: fg, size: 19),
        ),
      ),
    );
  }

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Audio Output Device',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final device in devices)
              ListTile(
                title: Text(device.label),
                trailing:
                    widget.session.snapshot.selectedAudioDevice?.label ==
                        device.label
                    ? const Icon(Icons.check_rounded, color: Color(0xFF4F46E5))
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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Meeting Messages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: StreamBuilder<MeetingSnapshot>(
                    stream: widget.session.snapshots,
                    initialData: widget.session.snapshot,
                    builder: (context, stream) {
                      final messages = stream.data?.messages ?? const [];
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text('No messages yet', style: TextStyle(color: Color(0xFF94A3B8))),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - index - 1];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.externalUserId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.message,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
