import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';

typedef MediaParticipantBuilder =
    Widget Function(
      BuildContext context,
      MediaParticipant participant,
      MediaTrackRenderer renderer,
    );

class MediaRoomViewConfig {
  const MediaRoomViewConfig({
    this.showProvider = true,
    this.showChat = true,
    this.showRtcDataMessages = false,
    this.confirmBeforeLeave = true,
  });
  final bool showProvider;
  final bool showChat;
  final bool showRtcDataMessages;
  final bool confirmBeforeLeave;
}

class MediaRoomView extends StatefulWidget {
  const MediaRoomView({
    super.key,
    required this.room,
    required this.renderer,
    this.chatSession,
    this.config = const MediaRoomViewConfig(),
    this.participantBuilder,
    this.onLeave,
  });
  final MediaRoomSession room;
  final MediaTrackRenderer renderer;
  final ChatSession? chatSession;
  final MediaRoomViewConfig config;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;
  @override
  State<MediaRoomView> createState() => _MediaRoomViewState();
}

class _MediaRoomViewState extends State<MediaRoomView> {
  final _message = TextEditingController();
  final _rtcDataMessage = TextEditingController();
  Timer? _timer;
  int _seconds = 0;
  bool _chatOpen = false;
  bool _rtcDataOpen = false;
  bool _copied = false;
  String? _error;
  MediaSession get session => widget.room.session;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _message.dispose();
    _rtcDataMessage.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _leave() async {
    var leave = true;
    if (widget.config.confirmBeforeLeave) {
      leave =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Leave Meeting?'),
              content: const Text('Are you sure you want to disconnect?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Leave'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!leave) return;
    await widget.chatSession?.dispose();
    await widget.room.dispose();
    widget.onLeave?.call();
    if (widget.onLeave == null && mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaSnapshot>(
    stream: session.snapshots,
    initialData: session.snapshot,
    builder: (context, snap) {
      final value = snap.data ?? session.snapshot;
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _topBar(value),
              if (_error != null) _errorView(),
              Expanded(
                child: value.participants.isEmpty ? _waiting() : _grid(value),
              ),
              if (value.contentShareTrack != null) _screenShare(value),
              if (_chatOpen) _chat(),
              if (_rtcDataOpen) _rtcData(),
              _controls(value),
            ],
          ),
        ),
      );
    },
  );

  Widget _topBar(MediaSnapshot value) {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _iconButton(Icons.arrow_back_ios_new_rounded, _leave),
          const SizedBox(width: 10),
          InkWell(
            onTap: _copyCode,
            child: _badge(
              widget.room.roomCode,
              _copied ? Icons.check_rounded : Icons.copy_rounded,
            ),
          ),
          if (widget.config.showProvider) ...[
            const SizedBox(width: 8),
            _providerBadge(widget.room.providerId),
          ],
          const Spacer(),
          _badge('$mm:$ss', Icons.circle),
          const SizedBox(width: 8),
          _badge('${value.participants.length}', Icons.people_outline_rounded),
        ],
      ),
    );
  }

  Widget _providerBadge(String id) {
    final label = mediaProviderDisplayName(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4F46E5),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _badge(String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 5),
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
      ],
    ),
  );

  Widget _errorView() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
        ),
      ],
    ),
  );

  Widget _waiting() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEEF2FF),
          ),
          child: const Icon(
            Icons.wifi_tethering_rounded,
            size: 34,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "You're the only one here",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Share the room code to start streaming',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _copyCode,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? 'Copied' : 'Copy ${widget.room.roomCode}'),
        ),
      ],
    ),
  );

  Widget _grid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final count = value.participants.length;
      final columns = constraints.maxWidth > 900
          ? (count <= 4 ? 2 : 3)
          : constraints.maxWidth > 600
          ? (count <= 2 ? 2 : 3)
          : (count == 1 ? 1 : 2);
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: count == 1 ? 4 / 3 : 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final participant = value.participants[index];
          return widget.participantBuilder?.call(
                context,
                participant,
                widget.renderer,
              ) ??
              MediaParticipantTile(
                participant: participant,
                renderer: widget.renderer,
              );
        },
      );
    },
  );

  Widget _screenShare(MediaSnapshot value) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    height: 160,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: MediaTrackView(
        renderer: widget.renderer,
        track: value.contentShareTrack,
      ),
    ),
  );

  Widget _chat() {
    final chat = widget.chatSession;
    if (chat != null) return _productChat(chat);
    return const SizedBox.shrink();
  }

  Widget _productChat(ChatSession chat) => StreamBuilder<ChatConnectionState>(
    stream: chat.states,
    initialData: chat.state,
    builder: (context, stateSnapshot) {
      final connectionState = stateSnapshot.data ?? chat.state;
      return StreamBuilder<List<ChatMessage>>(
        stream: chat.messageSnapshots,
        initialData: chat.messages,
        builder: (context, messageSnapshot) {
          final messages = messageSnapshot.data ?? chat.messages;
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      connectionState.name,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: connectionState.isConnected
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (messages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 132),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: '${message.displayName}: ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: message.message),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        enabled: connectionState.isConnected,
                        decoration: InputDecoration(
                          hintText: connectionState.isConnected
                              ? 'Type a message…'
                              : 'Chat is ${connectionState.name}',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendChat(chat),
                      ),
                    ),
                    IconButton(
                      onPressed: connectionState.isConnected
                          ? () => _sendChat(chat)
                          : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  void _sendChat(ChatSession chat) {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _run(() => chat.sendMessage(text)).then((_) {
      if (mounted && _error == null) _message.clear();
    });
  }

  Widget _rtcData() {
    final messenger = session is MediaDataMessenger
        ? session as MediaDataMessenger
        : null;
    if (messenger == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              'RTC Data',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _rtcDataMessage,
              decoration: const InputDecoration(
                hintText: 'Debug data payload…',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendRtcData(messenger),
            ),
          ),
          IconButton(
            onPressed: () => _sendRtcData(messenger),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  void _sendRtcData(MediaDataMessenger messenger) {
    final text = _rtcDataMessage.text.trim();
    if (text.isEmpty) return;
    _run(() => messenger.sendMessage(text, topic: 'debug')).then((_) {
      if (mounted && _error == null) _rtcDataMessage.clear();
    });
  }

  Widget _controls(MediaSnapshot value) {
    final interactive = session is InteractiveMediaSession
        ? session as InteractiveMediaSession
        : null;
    final caps = value.capabilities;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (interactive != null && caps.canPublishAudio)
              _control(
                value.localMuted
                    ? Icons.mic_off_outlined
                    : Icons.mic_none_rounded,
                () => _run(interactive.toggleMute),
                active: !value.localMuted,
              ),
            if (interactive != null && caps.canPublishVideo) ...[
              const SizedBox(width: 8),
              _control(
                value.localVideoEnabled
                    ? Icons.videocam_outlined
                    : Icons.videocam_off_outlined,
                () => _run(
                  () => interactive.setVideoEnabled(!value.localVideoEnabled),
                ),
                active: value.localVideoEnabled,
              ),
            ],
            if (interactive != null && caps.canSwitchCamera) ...[
              const SizedBox(width: 8),
              _control(
                Icons.cameraswitch_outlined,
                () => _run(
                  () => interactive.switchCamera(MediaCameraPosition.back),
                ),
              ),
            ],
            if (interactive != null && caps.canScreenShare) ...[
              const SizedBox(width: 8),
              _control(
                Icons.screen_share_outlined,
                () => _run(() => interactive.setScreenShareEnabled(true)),
              ),
            ],
            if (widget.config.showChat && widget.chatSession != null) ...[
              const SizedBox(width: 8),
              _control(
                Icons.chat_bubble_outline_rounded,
                () => setState(() => _chatOpen = !_chatOpen),
                active: _chatOpen,
              ),
            ],
            if (widget.config.showRtcDataMessages &&
                session is MediaDataMessenger &&
                caps.canSendData) ...[
              const SizedBox(width: 8),
              _control(
                Icons.data_object_rounded,
                () => setState(() => _rtcDataOpen = !_rtcDataOpen),
                active: _rtcDataOpen,
              ),
            ],
            const SizedBox(width: 10),
            _control(Icons.call_end_rounded, _leave, endCall: true),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback action) =>
      _control(icon, action);

  Widget _control(
    IconData icon,
    VoidCallback action, {
    bool active = false,
    bool endCall = false,
  }) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: endCall
            ? const Color(0xFFDC2626)
            : active
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        size: 19,
        color: endCall
            ? Colors.white
            : active
            ? const Color(0xFF4F46E5)
            : const Color(0xFF475569),
      ),
    ),
  );
}

class MediaParticipantTile extends StatelessWidget {
  const MediaParticipantTile({
    super.key,
    required this.participant,
    required this.renderer,
  });
  final MediaParticipant participant;
  final MediaTrackRenderer renderer;

  @override
  Widget build(BuildContext context) {
    final name = participant.displayName.isEmpty
        ? 'Participant'
        : participant.displayName;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: participant.isSpeaking
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: participant.isSpeaking ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant.videoTrack != null)
              MediaTrackView(renderer: renderer, track: participant.videoTrack)
            else
              Container(
                color: const Color(0xFFF8FAFC),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name${participant.isLocal ? ' (you)' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      participant.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 14,
                      color: participant.isMuted
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
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
}
