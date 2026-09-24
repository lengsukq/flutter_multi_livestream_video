import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multi_livestream_video_chime/flutter_multi_livestream_video_chime.dart';
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:flutter_multi_livestream_video_livekit/flutter_multi_livestream_video_livekit.dart';

import 'widgets/glass_widgets.dart';

void main() => runApp(const ChimeExampleApp());

final MediaRegistry _mediaRegistry = MediaRegistry([
  const LiveKitSessionFactory(),
  ChimeSessionFactory(),
]);

final Map<String, MediaTrackRenderer> _mediaRenderers = {
  'livekit': const LiveKitTrackRenderer(),
  'chime': const ChimeTrackRenderer(),
};

const String _defaultBackendUrl = String.fromEnvironment(
  'MEDIA_BACKEND_URL',
  defaultValue: 'http://192.168.31.8:3000',
);
const String _appToken = String.fromEnvironment('MEDIA_APP_TOKEN');

class ChimeExampleApp extends StatelessWidget {
  const ChimeExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chime Live',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF090D16),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        surface: Color(0xFF0F172A),
      ),
      useMaterial3: true,
    ),
    home: const JoinScreen(),
  );
}

/// Demonstrates the app-backend boundary. The app sends room/user intent only;
/// the backend selects LiveKit or Chime and Core resolves the returned adapter.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _serverController = TextEditingController();
  final _createCodeController = TextEditingController();
  final _createNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _joinNameController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _serverController.text = _defaultBackendUrl;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _serverController.dispose();
    _createCodeController.dispose();
    _createNameController.dispose();
    _joinCodeController.dispose();
    _joinNameController.dispose();
    super.dispose();
  }

  String get _server => _serverController.text.trim();

  String _nickname(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? 'user-${DateTime.now().millisecondsSinceEpoch % 100000}'
      : controller.text.trim();

  Future<void> _createRoom() async {
    if (_server.isEmpty) {
      setState(() => _error = 'Enter your backend URL first.');
      return;
    }
    final requestedCode = _createCodeController.text.trim();
    if (requestedCode.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(requestedCode)) {
      setState(() => _error = 'Room code must be 4–12 letters or digits.');
      return;
    }
    final client = _newClient();
    await _run(() async {
      final room = await client.createRoomAndJoin(
        roomCode: requestedCode.isEmpty ? null : requestedCode,
        nickname: _nickname(_createNameController),
        role: MediaRole.participant,
      );
      await _openMeeting(client, room);
    }, client);
  }

  Future<void> _joinRoom() async {
    if (_server.isEmpty) {
      setState(() => _error = 'Enter your backend URL first.');
      return;
    }
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a room code first.');
      return;
    }
    final client = _newClient();
    await _run(() async {
      final room = await client.joinRoom(
        roomCode: code,
        nickname: _nickname(_joinNameController),
        role: MediaRole.participant,
      );
      await _openMeeting(client, room);
    }, client);
  }

  MediaClient _newClient() => MediaClient(
    backendUrl: _server,
    registry: _mediaRegistry,
    tokenProvider: _appToken.trim().isEmpty ? null : () async => _appToken,
  );

  Future<void> _run(Future<void> Function() action, MediaClient client) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      client.dispose();
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMeeting(MediaClient client, MediaRoomSession room) async {
    final renderer = _mediaRenderers[room.providerId];
    if (renderer == null) {
      await room.dispose();
      client.dispose();
      throw StateError(
        'No renderer is registered for backend provider ${room.providerId}.',
      );
    }
    if (!mounted) {
      await room.dispose();
      client.dispose();
      return;
    }
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MeetingRoomPage(room: room, renderer: renderer),
        ),
      );
    } finally {
      await room.dispose();
      client.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AmbientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(
                Icons.videocam_rounded,
                size: 44,
                color: Color(0xFF818CF8),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chime Live',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Backend-selected media demo',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              GlassContainer(
                borderRadius: 22,
                padding: const EdgeInsets.all(16),
                child: GlassTextField(
                  controller: _serverController,
                  label: 'Demo backend URL',
                  hintText: 'http://192.168.31.8:3000',
                  prefixIcon: Icons.dns_rounded,
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(height: 18),
              GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabs,
                      tabs: const [
                        Tab(text: 'Join room'),
                        Tab(text: 'Create room'),
                      ],
                    ),
                    SizedBox(
                      height: 280,
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _roomForm(
                            code: _joinCodeController,
                            name: _joinNameController,
                            codeLabel: 'Room code',
                            actionLabel: 'Join room',
                            action: _joinRoom,
                          ),
                          _roomForm(
                            code: _createCodeController,
                            name: _createNameController,
                            codeLabel: 'Room code (optional)',
                            actionLabel: 'Create and join',
                            action: _createRoom,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Color(0xFFFDA4AF))),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _roomForm({
    required TextEditingController code,
    required TextEditingController name,
    required String codeLabel,
    required String actionLabel,
    required Future<void> Function() action,
  }) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      children: [
        GlassTextField(
          controller: code,
          label: codeLabel,
          hintText: '4–12 letters or digits',
          prefixIcon: Icons.tag_rounded,
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: name,
          label: 'Display name (optional)',
          hintText: 'Guest',
          prefixIcon: Icons.person_rounded,
        ),
        const SizedBox(height: 18),
        GlassGradientButton(
          onPressed: _busy ? null : action,
          isLoading: _busy,
          icon: Icons.login_rounded,
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

class MeetingRoomPage extends StatefulWidget {
  const MeetingRoomPage({
    super.key,
    required this.room,
    required this.renderer,
  });

  final MediaRoomSession room;
  final MediaTrackRenderer renderer;

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  final _messageController = TextEditingController();
  String? _error;

  MediaSession get session => widget.room.session;

  @override
  void dispose() {
    _messageController.dispose();
    unawaited(widget.room.dispose());
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
    await widget.room.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaSnapshot>(
    stream: session.snapshots,
    initialData: session.snapshot,
    builder: (context, snapshot) {
      final value = snapshot.data ?? session.snapshot;
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090D16),
          title: Text('Room ${widget.room.roomCode}'),
          actions: [
            IconButton(
              tooltip: 'Copy room code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.room.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Room code ${widget.room.roomCode} copied'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              tooltip: 'Leave',
              onPressed: _leave,
              icon: const Icon(Icons.call_end_rounded),
            ),
          ],
        ),
        body: AmbientBackground(
          child: Column(
            children: [
              Expanded(
                child: value.participants.isEmpty
                    ? Center(child: Text(value.state.name))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 420,
                              childAspectRatio: 4 / 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: value.participants.length,
                        itemBuilder: (context, index) => _ParticipantTile(
                          participant: value.participants[index],
                          renderer: widget.renderer,
                        ),
                      ),
              ),
              if (value.contentShareTrack != null)
                SizedBox(
                  height: 180,
                  child: MediaTrackView(
                    renderer: widget.renderer,
                    track: value.contentShareTrack,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFDA4AF)),
                  ),
                ),
              _RoomControls(
                session: session,
                snapshot: value,
                messageController: _messageController,
                run: _run,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, required this.renderer});

  final MediaParticipant participant;
  final MediaTrackRenderer renderer;

  @override
  Widget build(BuildContext context) => GlassContainer(
    borderRadius: 20,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: MediaTrackView(
            renderer: renderer,
            track: participant.videoTrack,
            placeholder: const ColoredBox(
              color: Color(0xFF111827),
              child: Center(
                child: Icon(
                  Icons.person_rounded,
                  size: 52,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.black54,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${participant.displayName}${participant.isLocal ? ' (you)' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  participant.isMuted
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                  size: 18,
                  color: participant.isSpeaking
                      ? Colors.greenAccent
                      : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoomControls extends StatelessWidget {
  const _RoomControls({
    required this.session,
    required this.snapshot,
    required this.messageController,
    required this.run,
  });

  final MediaSession session;
  final MediaSnapshot snapshot;
  final TextEditingController messageController;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final interactive = session is InteractiveMediaSession
        ? session as InteractiveMediaSession
        : null;
    final messenger = session is MediaDataMessenger
        ? session as MediaDataMessenger
        : null;
    return SafeArea(
      top: false,
      child: GlassContainer(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        padding: const EdgeInsets.all(10),
        borderRadius: 20,
        child: Column(
          children: [
            if (interactive != null)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  IconButton.filledTonal(
                    tooltip: snapshot.localMuted ? 'Unmute' : 'Mute',
                    onPressed: () => run(interactive.toggleMute),
                    icon: Icon(snapshot.localMuted ? Icons.mic_off : Icons.mic),
                  ),
                  IconButton.filledTonal(
                    tooltip: snapshot.localVideoEnabled
                        ? 'Stop camera'
                        : 'Start camera',
                    onPressed: () => run(
                      () => interactive.setVideoEnabled(
                        !snapshot.localVideoEnabled,
                      ),
                    ),
                    icon: Icon(
                      snapshot.localVideoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                    ),
                  ),
                  if (snapshot.capabilities.canSwitchCamera)
                    IconButton.filledTonal(
                      tooltip: 'Switch camera',
                      onPressed: () => run(
                        () =>
                            interactive.switchCamera(MediaCameraPosition.back),
                      ),
                      icon: const Icon(Icons.cameraswitch),
                    ),
                  if (snapshot.capabilities.canScreenShare)
                    IconButton.filledTonal(
                      tooltip: 'Start screen share',
                      onPressed: () =>
                          run(() => interactive.setScreenShareEnabled(true)),
                      icon: const Icon(Icons.screen_share),
                    ),
                ],
              ),
            if (messenger != null && snapshot.capabilities.canSendData) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: 'Data message',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: () {
                      final text = messageController.text.trim();
                      if (text.isEmpty) return;
                      run(() => messenger.sendMessage(text)).then((_) {
                        messageController.clear();
                      });
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
