part of 'media_room_view.dart';

// ignore: unused_element
class _RoomControls extends StatelessWidget {
  const _RoomControls({required this.host, required this.snapshot});
  final _MediaRoomViewState host;
  final MediaSnapshot snapshot;
  @override
  Widget build(BuildContext context) => RoomRegion(
    revision: host._controlRevision,
    builder: (_) => host._buildControls(snapshot),
  );
}

extension _RoomControlRendering on _MediaRoomViewState {
  Widget _buildControls(MediaSnapshot value) {
    final interactive = session is InteractiveMediaSession
        ? session as InteractiveMediaSession
        : null;
    final caps = value.capabilities;
    final strings = RealtimeStrings.of(context);
    final showLabels = MediaQuery.sizeOf(context).width >= 760;
    final controls = <Widget>[];
    if (interactive != null && caps.canPublishAudio) {
      controls.add(
        _control(
          value.localMuted ? Icons.mic_off_outlined : Icons.mic_none_rounded,
          strings.microphone,
          () {
            if (value.localMuted &&
                widget.canEnableMicrophone?.call() == false) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.awaitPermissionToSpeak)),
              );
              return;
            }
            observeDetached(_run(interactive.toggleMute));
          },
          active: !value.localMuted,
          showLabel: showLabels,
        ),
      );
    }
    if (interactive != null && caps.canPublishVideo) {
      controls.add(
        _control(
          value.localVideoEnabled
              ? Icons.videocam_outlined
              : Icons.videocam_off_outlined,
          strings.camera,
          () =>
              _run(() => interactive.setVideoEnabled(!value.localVideoEnabled)),
          active: value.localVideoEnabled,
          showLabel: showLabels,
        ),
      );
    }
    if (interactive != null && caps.canSwitchCamera) {
      controls.add(
        _control(
          Icons.cameraswitch_outlined,
          strings.switchCamera,
          () => _run(() => interactive.switchCamera(MediaCameraPosition.back)),
          showLabel: showLabels,
        ),
      );
    }
    if (caps.canPublishVideo &&
        _backgroundEffects.backgroundCapabilities.isSupported) {
      controls.add(
        _control(
          Icons.blur_on_outlined,
          strings.virtualBackground,
          _openBackgroundEffects,
          active: _backgroundEffects.backgroundEffect.enabled,
          showLabel: showLabels,
        ),
      );
    }
    final contentControls = widget.contentControlsBuilder?.call(context);
    if (contentControls != null) {
      controls.add(contentControls);
    } else if (interactive != null && caps.canScreenShare) {
      controls.add(
        _control(
          value.localScreenShareEnabled
              ? Icons.stop_screen_share_outlined
              : Icons.screen_share_outlined,
          strings.screenShare,
          () => _run(
            () => interactive.setScreenShareEnabled(
              !value.localScreenShareEnabled,
            ),
          ),
          active: value.localScreenShareEnabled,
          showLabel: showLabels,
        ),
      );
    }
    final extraControls = widget.extraControlsBuilder?.call(context);
    if (extraControls != null && extraControls.isNotEmpty) {
      controls.addAll(extraControls);
    }
    controls.add(
      _control(
        Icons.people_outline_rounded,
        strings.participants,
        _openParticipants,
        active: _participantsOpen,
        badgeCount: value.participants.length,
        showLabel: showLabels,
      ),
    );
    if (widget.config.showChat && widget.chatSession != null) {
      controls.add(
        _control(
          Icons.chat_bubble_outline_rounded,
          strings.chat,
          _toggleChat,
          active: _chatOpen,
          badgeCount: _unreadChatCount,
          showLabel: showLabels,
        ),
      );
    }
    if (widget.config.showRtcDataMessages && caps.canSendData) {
      controls.add(
        _control(
          Icons.data_object_rounded,
          strings.rtcData,
          () => _updateRoom(() => _rtcDataOpen = !_rtcDataOpen),
          active: _rtcDataOpen,
          showLabel: showLabels,
        ),
      );
    }
    final isLive = widget.room.role != MediaRole.participant;
    if (isLive && widget.liveLikes != null) {
      controls.add(
        _control(
          Icons.favorite_rounded,
          '${strings.totalLikes} $_likeCount',
          _sendLike,
          showLabel: showLabels,
        ),
      );
    }
    if (isLive) {
      controls.add(
        _control(
          _cleanScreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          _cleanScreen ? strings.exitCleanScreen : strings.cleanScreen,
          _toggleCleanScreen,
          active: _cleanScreen,
          showLabel: showLabels,
        ),
      );
    }
    controls.add(
      _control(
        Icons.call_end_rounded,
        widget.room.role == MediaRole.host &&
                widget.room.managementCapabilities.closeRoom.supported
            ? strings.endLiveRoom
            : widget.room.role == MediaRole.participant
            ? strings.leave
            : strings.leaveLiveRoom,
        _leave,
        endCall: true,
        showLabel: showLabels,
      ),
    );
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .96,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: showLabels ? 16 : 4,
        runSpacing: 2,
        children: controls,
      ),
    );
  }

  Widget _control(
    IconData icon,
    String label,
    VoidCallback action, {
    bool active = false,
    bool endCall = false,
    int badgeCount = 0,
    bool showLabel = false,
  }) => Semantics(
    label: label,
    button: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RealtimeGlassIconButton(
          tooltip: label,
          icon: icon,
          onPressed: action,
          active: active,
          danger: endCall,
          badgeCount: badgeCount,
          size: 46,
          radius: RealtimeUiTokens.controlRadius,
        ),
        if (showLabel) ...[
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: endCall
                  ? RealtimeUiTokens.danger
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : RealtimeUiTokens.text),
            ),
          ),
        ],
      ],
    ),
  );
}
