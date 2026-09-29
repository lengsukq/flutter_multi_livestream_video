import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/chime_exception.dart';
import '../models/chime_meeting_session.dart';
import '../models/meeting_event.model.dart';
import '../models/meeting_snapshot.dart';
import 'video_tile.view.dart';

/// Optional meeting surface with large-radius frosted glass styling.
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
  static const _sheetRadius = 32.0;
  static const _dockRadius = 30.0;
  static const _cardRadius = 28.0;
  static const _controlRadius = 22.0;
  static const _compactRadius = 16.0;
  static const _blur = 24.0;

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
        color: const Color(0xFFF4F7FB),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              left: -110,
              top: -130,
              child: _ChimeAmbientOrb(size: 360, color: Color(0xFFD9E2FF)),
            ),
            const Positioned(
              right: -120,
              bottom: -140,
              child: _ChimeAmbientOrb(size: 380, color: Color(0xFFDBEAFE)),
            ),
            SafeArea(
              child: Column(
                children: [
                  _header(snapshot),
                  Expanded(child: _meetingContent(snapshot, pageCount)),
                  if (pageCount > 1) _pageIndicator(pageCount, safePage),
                  _controls(snapshot),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _glassBox({
    required Widget child,
    required double radius,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double opacity = 0.86,
  }) => Padding(
    padding: margin ?? EdgeInsets.zero,
    child: RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    ),
  );

  Widget _header(MeetingSnapshot snapshot) => _glassBox(
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    radius: _dockRadius,
    child: Row(
      children: [
        Tooltip(
          message: 'Leave meeting',
          child: InkWell(
            onTap: _confirmLeave,
            borderRadius: BorderRadius.circular(_compactRadius),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(_compactRadius),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_stateLabel(snapshot.state)} · ${snapshot.attendees.length} participants',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _callSeconds.isEven
                      ? const Color(0xFF10B981)
                      : const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formattedDuration,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
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
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.34),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: _glassBox(
          radius: _sheetRadius,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          opacity: 0.92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Leave Meeting?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure you want to disconnect from this meeting?',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_controlRadius),
                      ),
                    ),
                    child: const Text('Leave'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          child: _glassBox(
            radius: _sheetRadius,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            opacity: 0.84,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEEF2FF),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Icon(
                    Icons.wifi_tethering_rounded,
                    color: Color(0xFF4F46E5),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_cardRadius - 2),
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
          padding: const EdgeInsets.all(12),
          itemCount: attendees.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => _attendeeTile(attendees[index]),
        );
      },
    );
  }

  Widget _attendeeTile(MeetingAttendee attendee) {
    final tile = attendee.videoTile;
    final name = attendee.externalUserId.isEmpty
        ? 'Participant'
        : attendee.externalUserId;
    final initial = name.characters.first.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tile != null)
              MeetingVideoTileView(tile: tile)
            else
              Container(
                color: const Color(0xFFF4F7FB),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
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
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(_compactRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (attendee.isMuted)
                          const Icon(
                            Icons.mic_off_rounded,
                            color: Color(0xFFDC2626),
                            size: 15,
                          ),
                      ],
                    ),
                  ),
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
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: index == currentPage ? 18 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == currentPage
                ? const Color(0xFF4F46E5)
                : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    ),
  );

  Widget _controls(MeetingSnapshot snapshot) => _glassBox(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    radius: _dockRadius,
    opacity: 0.88,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _control(
            icon: snapshot.localMuted
                ? Icons.mic_off_outlined
                : Icons.mic_none_rounded,
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
              borderRadius: BorderRadius.circular(_controlRadius),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(_controlRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
    final bg = isDanger
        ? const Color(0xFFFEF2F2)
        : isActive
        ? const Color(0xFFEEF2FF)
        : Colors.white.withValues(alpha: 0.78);
    final fg = isDanger
        ? const Color(0xFFDC2626)
        : isActive
        ? const Color(0xFF4F46E5)
        : const Color(0xFF475569);
    final border = isDanger
        ? const Color(0xFFFECDD3)
        : isActive
        ? const Color(0xFFC7D2FE)
        : const Color(0xFFE2E8F0);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_controlRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_controlRadius),
            border: Border.all(color: border, width: 1.1),
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => RepaintBoundary(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_sheetRadius),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_sheetRadius),
              ),
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
            ),
            child: SafeArea(
              top: false,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Audio Output Device',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  for (final device in devices)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_controlRadius),
                      ),
                      title: Text(
                        device.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing:
                          widget.session.snapshot.selectedAudioDevice?.label ==
                              device.label
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF4F46E5),
                            )
                          : null,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _run(
                          () => widget.session.selectAudioDevice(device),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessages() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      elevation: 0,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => RepaintBoundary(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_sheetRadius),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_sheetRadius),
                ),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 18,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Meeting Messages',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(_controlRadius),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: StreamBuilder<MeetingSnapshot>(
                          stream: widget.session.snapshots,
                          initialData: widget.session.snapshot,
                          builder: (context, stream) {
                            final messages = stream.data?.messages ?? const [];
                            if (messages.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No messages yet',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.all(10),
                              reverse: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message =
                                    messages[messages.length - index - 1];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      _compactRadius,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.externalUserId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.5,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        message.message,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
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
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    _controlRadius,
                                  ),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    _controlRadius,
                                  ),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  _controlRadius,
                                ),
                              ),
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

class _ChimeAmbientOrb extends StatelessWidget {
  const _ChimeAmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: 0.65), color.withValues(alpha: 0)],
      ),
    ),
  );
}
