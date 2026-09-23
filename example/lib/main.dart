import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';

import 'join_link.dart';
import 'widgets/glass_widgets.dart';

void main() => runApp(const ChimeExampleApp());

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

/// Demonstrates the app-backend boundary: the backend creates the room and
/// attendee, then this client passes the returned join information to v3.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _serverController = TextEditingController(
    text: 'http://192.168.31.8:3000',
  );
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

  String get _server => _serverController.text.trim().isEmpty
      ? 'http://192.168.31.8:3000'
      : _serverController.text.trim();

  String _nickname(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? RoomLink.defaultNickname()
      : controller.text.trim();

  Future<void> _createRoom() async {
    final requestedCode = _createCodeController.text.trim();
    if (requestedCode.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(requestedCode)) {
      setState(() => _error = 'Room code must be 4–12 letters or digits.');
      return;
    }
    final backend = DemoBackend(_server);
    await _run(() async {
      final room = await backend.createRoom(
        roomCode: requestedCode.isEmpty ? null : requestedCode,
        nickname: _nickname(_createNameController),
      );
      await _joinMeeting(room, backend);
    }, backend);
  }

  Future<void> _joinRoom() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a room code first.');
      return;
    }
    final backend = DemoBackend(_server);
    await _run(() async {
      final room = await backend.joinRoom(
        roomCode: code,
        nickname: _nickname(_joinNameController),
      );
      await _joinMeeting(room, backend);
    }, backend);
  }

  Future<void> _run(Future<void> Function() action, DemoBackend backend) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      backend.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinMeeting(RoomSession room, DemoBackend backend) async {
    final attendeeJson = room.attendee;
    if (attendeeJson == null) throw 'Backend did not return attendee data.';
    final joinInfo = JoinInfo(
      meeting: MeetingInfo.fromJson(room.meeting),
      attendee: AttendeeInfo.fromJson(attendeeJson),
    );
    final meeting = ChimeMeetingSession();
    try {
      await meeting.join(joinInfo);
      if (!mounted) {
        await meeting.dispose();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MeetingRoomPage(
            roomCode: room.roomCode,
            server: _server,
            attendeeId: attendeeJson['AttendeeId']?.toString(),
            session: meeting,
          ),
        ),
      );
    } catch (_) {
      await meeting.dispose();
      rethrow;
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
                'AWS Chime meeting example',
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
                  hintText: 'http://192.168.1.10:3000',
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
    required this.roomCode,
    required this.server,
    required this.session,
    this.attendeeId,
  });

  final String roomCode;
  final String server;
  final String? attendeeId;
  final ChimeMeetingSession session;

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  late final DemoBackend _backend;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    _backend = DemoBackend(widget.server);
    _backend.heartbeat(widget.roomCode);
    _heartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _backend.heartbeat(widget.roomCode),
    );
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _backend.leave(widget.roomCode, attendeeId: widget.attendeeId);
    _backend.dispose();
    unawaited(widget.session.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        ChimeMeetingView(
          session: widget.session,
          title: 'Room ${widget.roomCode}',
          onLeave: () => Navigator.of(context).pop(),
        ),
        Positioned(
          top: 68,
          left: 14,
          child: IconButton.filledTonal(
            tooltip: 'Copy room code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Room code ${widget.roomCode} copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ),
      ],
    ),
  );
}
