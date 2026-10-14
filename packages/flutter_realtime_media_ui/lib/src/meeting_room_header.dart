import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';
import 'dart:async';
import 'media_room_layout_mode.dart';

class MeetingRoomHeader extends StatelessWidget {
  const MeetingRoomHeader({
    super.key,
    required this.snapshot,
    required this.compact,
    required this.roomCode,
    required this.copied,
    required this.onCopy,
    required this.providerBadge,
    required this.layoutMode,
    required this.onLayoutMode,
    required this.hasContentControls,
    required this.onLeave,
  });
  final MediaSnapshot snapshot;
  final bool compact;
  final String roomCode;
  final bool copied;
  final VoidCallback onCopy;
  final Widget? providerBadge;
  final MediaRoomLayoutMode layoutMode;
  final ValueChanged<MediaRoomLayoutMode> onLayoutMode;
  final bool hasContentControls;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);

    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .92,
      child: Row(
        children: [
          // Room title & quick copy pill
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!compact) ...[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: style.primarySubtle,
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.compactRadius,
                            ),
                          ),
                          child: Icon(
                            Icons.videocam_rounded,
                            size: 16,
                            color: style.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!compact)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      strings.meeting,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: style.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    copied
                                        ? Icons.check_circle_rounded
                                        : Icons.copy_rounded,
                                    size: 13,
                                    color: copied
                                        ? style.success
                                        : style.textMuted,
                                  ),
                                ],
                              ),
                            Text(
                              roomCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: style.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Meeting duration timer
          if (!compact) ...[
            Container(height: 22, width: 1, color: style.border),
            const SizedBox(width: 10),
            _MeetingDurationTimer(isDark: style.isDark),
            const SizedBox(width: 10),
            () {
              final activeSpeaker = snapshot.participants
                  .where((p) => p.isSpeaking)
                  .firstOrNull;
              if (activeSpeaker != null) {
                final speakerName = activeSpeaker.displayName.isEmpty
                    ? strings.participant
                    : activeSpeaker.displayName;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RealtimePill(
                    label: speakerName,
                    icon: Icons.record_voice_over_rounded,
                    foreground: const Color(0xFF059669),
                    background: const Color(0xFF10B981).withValues(alpha: 0.16),
                    borderColor: const Color(
                      0xFF10B981,
                    ).withValues(alpha: 0.35),
                  ),
                );
              }
              return RealtimePill(
                label: strings.encryptedMeeting,
                icon: Icons.lock_rounded,
                foreground: const Color(0xFF059669),
                background: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
              );
            }(),
          ],

          // Provider Badge if configured
          if ((providerBadge != null) && !compact) ...[
            providerBadge!,
            const SizedBox(width: 8),
          ],

          // Layout Mode switcher
          if (!compact) ...[
            PopupMenuButton<MediaRoomLayoutMode>(
              tooltip: strings.layoutMode,
              color: style.surface.withValues(alpha: 0.96),
              elevation: 6,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                side: BorderSide(color: style.border),
              ),
              icon: Icon(
                switch (layoutMode) {
                  MediaRoomLayoutMode.grid => Icons.grid_view_rounded,
                  MediaRoomLayoutMode.speaker => Icons.person_pin_rounded,
                  MediaRoomLayoutMode.presentation =>
                    Icons.present_to_all_rounded,
                },
                size: 20,
                color: style.text,
              ),
              onSelected: onLayoutMode,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: MediaRoomLayoutMode.grid,
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 18,
                        color: style.text,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.gridMode,
                        style: TextStyle(color: style.text),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: MediaRoomLayoutMode.speaker,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_pin_rounded,
                        size: 18,
                        color: style.text,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.speakerMode,
                        style: TextStyle(color: style.text),
                      ),
                    ],
                  ),
                ),
                if (!hasContentControls)
                  PopupMenuItem(
                    value: MediaRoomLayoutMode.presentation,
                    child: Row(
                      children: [
                        Icon(
                          Icons.present_to_all_rounded,
                          size: 18,
                          color: style.text,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.presentationMode,
                          style: TextStyle(color: style.text),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
          ],

          // Professional Leave Button (Red Accent)
          InkWell(
            onTap: onLeave,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.call_end_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    strings.leaveMeeting,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Meeting Elapsed Duration Timer ticking upward.
class _MeetingDurationTimer extends StatefulWidget {
  const _MeetingDurationTimer({this.isDark = false});

  final bool isDark;

  @override
  State<_MeetingDurationTimer> createState() => _MeetingDurationTimerState();
}

class _MeetingDurationTimerState extends State<_MeetingDurationTimer> {
  late final DateTime _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: 6),
        Text(
          _format(_elapsed),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            color: widget.isDark ? Colors.white70 : const Color(0xFF334155),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// Professional conference bottom dock with icon + text label underneath.
