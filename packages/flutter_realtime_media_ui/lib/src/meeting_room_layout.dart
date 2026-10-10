import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_room_layout_host.dart';
import 'media_room_view.dart';
import 'room_regions.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

/// Professional meeting layout mimicking Zoom, Tencent Meeting, and Microsoft Teams.
class MeetingRoomViewLayout extends StatelessWidget {
  const MeetingRoomViewLayout({
    required this.host,
    required this.snapshot,
    required this.constraints,
  });

  final MediaRoomLayoutHost host;
  final MediaSnapshot snapshot;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final wide = constraints.maxWidth >= 1200;
    final medium = constraints.maxWidth >= 760;
    final compact = constraints.maxWidth < 520;
    final panelOpen = host.chatOpen || host.participantsOpen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RealtimeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _MeetingTopBar(host: host, snapshot: snapshot, compact: compact),
              if (host.view.header != null) host.view.header!,
              if (snapshot.state == MediaSessionState.reconnecting ||
                  snapshot.state == MediaSessionState.failed ||
                  snapshot.state == MediaSessionState.ended)
                host.connectionBanner(snapshot.state),
              RoomRegion(
                revision: host.chatRevision,
                builder: (_) => host.error == null
                    ? const SizedBox.shrink()
                    : host.errorView(),
              ),
              Expanded(
                child: wide
                    ? _buildWideStage(panelOpen)
                    : medium
                    ? _buildMediumStage(panelOpen, constraints)
                    : _buildCompactStage(panelOpen, constraints),
              ),
              if (host.rtcDataOpen) host.rtcData(),
              RoomRegion(
                revision: host.controlRevision,
                builder: (_) => _MeetingBottomDock(
                  host: host,
                  snapshot: snapshot,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideStage(bool panelOpen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: host.mediaStage(snapshot)),
        if (panelOpen)
          SizedBox(
            key: ValueKey(
              host.participantsOpen
                  ? 'meeting-participants-wide'
                  : 'meeting-chat-wide',
            ),
            width: 340,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset((1 - progress) * 16, 0),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: host.sidePanel(snapshot),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediumStage(bool panelOpen, BoxConstraints constraints) {
    return Stack(
      fit: StackFit.expand,
      children: [
        host.mediaStage(snapshot),
        if (panelOpen)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              key: ValueKey(
                host.participantsOpen
                    ? 'meeting-participants-medium'
                    : 'meeting-chat-medium',
              ),
              width: math.min(360, constraints.maxWidth * .56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: host.sidePanel(snapshot),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactStage(bool panelOpen, BoxConstraints constraints) {
    final maxChatHeight = math.max(160.0, constraints.maxHeight - 140);
    final desiredChatHeight = (constraints.maxHeight * .45).clamp(180.0, 380.0);
    final chatHeight = math.min(desiredChatHeight, maxChatHeight);

    return Column(
      children: [
        Expanded(child: host.mediaStage(snapshot)),
        if (panelOpen)
          SizedBox(
            key: ValueKey(
              host.participantsOpen
                  ? 'meeting-participants-compact'
                  : 'meeting-chat-compact',
            ),
            height: chatHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 14),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: host.sidePanel(snapshot),
              ),
            ),
          ),
      ],
    );
  }
}

/// Meeting top status bar.
class _MeetingTopBar extends StatelessWidget {
  const _MeetingTopBar({
    required this.host,
    required this.snapshot,
    required this.compact,
  });

  final MediaRoomLayoutHost host;
  final MediaSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final roomCode = host.view.room.roomCode;
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
                onTap: host.copyCode,
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
                                    host.copied
                                        ? Icons.check_circle_rounded
                                        : Icons.copy_rounded,
                                    size: 13,
                                    color: host.copied
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
                    borderColor: const Color(0xFF10B981).withValues(alpha: 0.35),
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
          if (host.view.config.showProvider && !compact) ...[
            host.providerBadge(host.view.room.providerId),
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
                switch (host.layoutMode) {
                  MediaRoomLayoutMode.grid => Icons.grid_view_rounded,
                  MediaRoomLayoutMode.speaker => Icons.person_pin_rounded,
                  MediaRoomLayoutMode.presentation =>
                    Icons.present_to_all_rounded,
                },
                size: 20,
                color: style.text,
              ),
              onSelected: host.setLayoutMode,
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
                if (host.view.contentControlsBuilder?.call(context) == null)
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
            onTap: host.showMeetingLeaveConfirmation,
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
class _MeetingBottomDock extends StatelessWidget {
  const _MeetingBottomDock({
    required this.host,
    required this.snapshot,
    required this.compact,
  });

  final MediaRoomLayoutHost host;
  final MediaSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final interactive = host.session is InteractiveMediaSession
        ? host.session as InteractiveMediaSession
        : null;
    final caps = snapshot.capabilities;
    final strings = RealtimeStrings.of(context);
    final items = <Widget>[];

    // 1. Microphone
    if (interactive != null && caps.canPublishAudio) {
      items.add(
        _MeetingDockAction(
          icon: snapshot.localMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: snapshot.localMuted ? strings.unmute : strings.microphone,
          isActive: !snapshot.localMuted,
          isAlert: snapshot.localMuted,
          onTap: () {
            if (snapshot.localMuted &&
                host.view.canEnableMicrophone?.call() == false) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('请先举手，等待允许发言 / Await speaker permission'),
                ),
              );
              return;
            }
            observeDetached(host.runAction(interactive.toggleMute));
          },
        ),
      );
    }

    // 2. Camera
    if (interactive != null && caps.canPublishVideo) {
      items.add(
        _MeetingDockAction(
          icon: snapshot.localVideoEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: snapshot.localVideoEnabled
              ? strings.stopVideo
              : strings.startVideo,
          isActive: snapshot.localVideoEnabled,
          isAlert: !snapshot.localVideoEnabled,
          onTap: () => host.runAction(
            () => interactive.setVideoEnabled(!snapshot.localVideoEnabled),
          ),
        ),
      );
    }

    // 3. Screen Share
    final contentControls = host.view.contentControlsBuilder?.call(context);
    if (contentControls != null) {
      items.add(contentControls);
    } else if (interactive != null && caps.canScreenShare) {
      items.add(
        _MeetingDockAction(
          icon: snapshot.localScreenShareEnabled
              ? Icons.stop_screen_share_rounded
              : Icons.screen_share_rounded,
          label: strings.screenShare,
          isActive: snapshot.localScreenShareEnabled,
          highlightColor: const Color(0xFF10B981),
          onTap: () => host.runAction(
            () => interactive.setScreenShareEnabled(
              !snapshot.localScreenShareEnabled,
            ),
          ),
        ),
      );
    }

    // Extra controls from extensions
    final extraControls = host.view.extraControlsBuilder?.call(context);
    if (extraControls != null && extraControls.isNotEmpty) {
      items.addAll(extraControls);
    }

    // 4. Participants
    items.add(
      _MeetingDockAction(
        icon: Icons.people_alt_rounded,
        label: strings.participants,
        isActive: host.participantsOpen,
        badgeCount: snapshot.participants.length,
        onTap: host.openParticipants,
      ),
    );

    // 5. Chat
    if (host.view.config.showChat && host.view.chatSession != null) {
      items.add(
        _MeetingDockAction(
          icon: Icons.chat_bubble_rounded,
          label: strings.chat,
          isActive: host.chatOpen,
          badgeCount: host.unreadChatCount,
          onTap: host.toggleChat,
        ),
      );
    }

    // 6. More Settings (Virtual background, camera switch, rtc data)
    items.add(
      _MeetingDockAction(
        icon: Icons.more_horiz_rounded,
        label: strings.more,
        onTap: () => host.showMeetingMoreSheet(snapshot, interactive),
      ),
    );

    // 7. Leave Meeting
    items.add(
      _MeetingDockAction(
        icon: Icons.call_end_rounded,
        label: strings.leave,
        isDanger: true,
        onTap: host.showMeetingLeaveConfirmation,
      ),
    );

    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .94,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// Meeting dock action item with vertical icon + label layout.
class _MeetingDockAction extends StatelessWidget {
  const _MeetingDockAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isAlert = false,
    this.isDanger = false,
    this.highlightColor,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isAlert;
  final bool isDanger;
  final Color? highlightColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    final effectiveColor = isDanger
        ? const Color(0xFFEF4444)
        : isAlert
        ? const Color(0xFFEF4444)
        : highlightColor ??
              (isActive
                  ? (isDark ? const Color(0xFF818CF8) : style.primary)
                  : style.text);

    final effectiveBackground = isDanger
        ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12)
        : isActive
        ? (highlightColor ?? style.primary).withValues(
            alpha: isDark ? 0.25 : 0.12,
          )
        : isDark
        ? Colors.white.withValues(alpha: 0.12)
        : style.surfaceSubtle;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: effectiveBackground,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        border: Border.all(
                          color: isActive || isDanger
                              ? effectiveColor.withValues(alpha: 0.45)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : Colors.transparent),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 20, color: effectiveColor),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.pillRadius,
                            ),
                            border: Border.all(
                              color: style.surface,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '$badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? const Color(0xFFEF4444) : style.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
