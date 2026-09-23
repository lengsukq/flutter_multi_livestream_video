import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';
import 'package:flutter_aws_chime/models/join_info.model.dart';
import 'package:flutter_aws_chime/views/meeting.view.dart';

import 'join_link.dart';
import 'device_check_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: JoinScreen());
  }
}

/// Room-number demo: create a room or join one by its number.
/// Server maps roomCode -> Chime meeting; credentials come from /rooms API.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with SingleTickerProviderStateMixin {
  late final StreamSubscription<ChimeEvent> _eventsSubscription;
  late final TabController _tabs;
  CameraPosition _cameraPosition = CameraPosition.front;

  final _serverController = TextEditingController(text: 'http://192.168.31.8:3000');
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
    _eventsSubscription = MeetingModel().events.listen(_logEvent);
  }

  void _logEvent(ChimeEvent event) {
    switch (event) {
      case MeetingSessionEvent():
        debugPrint(
          'Meeting session: ${event.kind.name}, '
          'reconnecting=${event.reconnecting}, status=${event.statusCode}',
        );
      case ConnectionQualityEvent():
        debugPrint('Connection quality: ${event.quality.name}');
      case CameraAvailabilityEvent():
        debugPrint('Camera available: ${event.available}');
      case AttendeeVolumeEvent():
        debugPrint('Attendee ${event.attendeeId} volume: ${event.volumeLevel.name}');
      case AttendeeSignalStrengthEvent():
        debugPrint('Attendee ${event.attendeeId} signal: ${event.signalStrength.name}');
      case VideoTileEvent():
        debugPrint('Video tile ${event.videoTile.tileId}: ${event.kind.name}');
    }
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
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

  String _nickname(TextEditingController c) =>
      c.text.trim().isEmpty ? RoomLink.defaultNickname() : c.text.trim();

  Future<void> _createAndJoin() async {
    final parsed = RoomLink.parse(_createCodeController.text,
        fallbackServer: _serverController.text);
    final wantCode = _createCodeController.text.trim().isEmpty
        ? null
        : (parsed?.roomCode ?? _createCodeController.text.trim());
    final nickname = _nickname(_createNameController);
    if (wantCode != null && !RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(wantCode)) {
      setState(() => _error = '房间号用4-12位字母/数字，不填则随机分配。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = DemoBackend(_server);
    try {
      final gate = await backend.enterGate();
      if (gate != null) throw gate;
      final session =
          await backend.createRoom(roomCode: wantCode, nickname: nickname);
      await _enterRoom(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    } finally {
      backend.dispose();
    }
  }

  Future<void> _joinRoom() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '先填房间号。');
      return;
    }
    final nickname = _nickname(_joinNameController);
    setState(() {
      _busy = true;
      _error = null;
    });
    final backend = DemoBackend(_server);
    try {
      final gate = await backend.enterGate();
      if (gate != null) throw gate;
      final session = await backend.joinRoom(roomCode: code, nickname: nickname);
      await _enterRoom(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    } finally {
      backend.dispose();
    }
  }

  Future<void> _enterRoom(RoomSession session) async {
    if (session.attendee == null) throw '服务器没返回入会凭证。';
    final joinInfo = JoinInfo(
      MeetingInfo.fromJson(session.meeting),
      AttendeeInfo.fromJson(session.attendee!),
    );
    final server = _server;
    final attendeeId = (session.attendee!['AttendeeId'] ?? '').toString();
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MeetingRoomPage(
        roomCode: session.roomCode,
        server: server,
        attendeeId: attendeeId.isEmpty ? null : attendeeId,
        joinInfo: joinInfo,
        onSwitchCamera: _switchCamera,
      ),
    ));
  }

  Future<void> _switchCamera() async {
    final requested =
        _cameraPosition == CameraPosition.front ? CameraPosition.back : CameraPosition.front;
    final ok = await MeetingModel().switchCamera(requested);
    if (!mounted) return;
    if (ok) {
      setState(() => _cameraPosition = requested);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('摄像头: ${requested == CameraPosition.front ? '前置' : '后置'}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('切换摄像头失败。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('视频房间'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: '加入房间'), Tab(text: '创建房间')],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _serverController,
                decoration: const InputDecoration(
                  labelText: '服务器 (Mac 局域网 IP)',
                  hintText: 'http://192.168.31.8:3000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DeviceCheckPage(server: _server),
                )),
                icon: const Icon(Icons.health_and_safety),
                label: const Text('先做设备自检（摄像头/语音/服务器）'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 320,
                child: TabBarView(
                  controller: _tabs,
                  children: [_joinTab(), _createTab()],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _joinTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _joinCodeController,
          decoration: const InputDecoration(
            labelText: '房间号',
            hintText: '如 482913',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.none,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _joinNameController,
          decoration: const InputDecoration(
            labelText: '昵称 (可选)',
            hintText: '观众-1',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _joinRoom,
          icon: const Icon(Icons.login),
          label: Text(_busy ? '加入中…' : '加入房间'),
        ),
        const SizedBox(height: 8),
        const Text('房主把6位房间号告诉你，填入即可开看。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _createTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _createCodeController,
          decoration: const InputDecoration(
            labelText: '房间号 (可选，不填随机)',
            hintText: '如 888888',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.none,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _createNameController,
          decoration: const InputDecoration(
            labelText: '昵称 (可选)',
            hintText: '主播',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _createAndJoin,
          icon: const Icon(Icons.add),
          label: Text(_busy ? '创建中…' : '创建并加入'),
        ),
        const SizedBox(height: 8),
        const Text('创建后把房间号发给观众即可，不用复制长链接。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class MeetingRoomPage extends StatefulWidget {
  final String roomCode;
  final String server;
  final String? attendeeId;
  final JoinInfo joinInfo;
  final Future<void> Function() onSwitchCamera;

  const MeetingRoomPage({
    super.key,
    required this.roomCode,
    required this.server,
    this.attendeeId,
    required this.joinInfo,
    required this.onSwitchCamera,
  });

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
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _backend.heartbeat(widget.roomCode);
    });
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    // Best-effort leave notice; auto-close covers process kills.
    _backend.leave(widget.roomCode, attendeeId: widget.attendeeId);
    _backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            MeetingView(widget.joinInfo,
                onLeave: (_) => Navigator.of(context).pop()),
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('房间号 ${widget.roomCode} 已复制')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('房间 ${widget.roomCode} · 点我复制',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: '切换摄像头',
                onPressed: widget.onSwitchCamera,
                icon: const Icon(Icons.flip_camera_android),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
