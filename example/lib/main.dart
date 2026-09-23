import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart';
import 'package:flutter_aws_chime/models/join_info.model.dart';
import 'package:flutter_aws_chime/views/meeting.view.dart';

import 'device_check_page.dart';
import 'join_link.dart';
import 'widgets/glass_widgets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
}

/// Room-number demo: create a room or join one by its number.
/// Server maps roomCode -> Chime meeting; credentials come from /rooms API.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<ChimeEvent> _eventsSubscription;
  late final TabController _tabs;
  CameraPosition _cameraPosition = CameraPosition.front;

  final _serverController =
      TextEditingController(text: 'http://192.168.31.8:3000');
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
        debugPrint(
            'Attendee ${event.attendeeId} volume: ${event.volumeLevel.name}');
      case AttendeeSignalStrengthEvent():
        debugPrint(
            'Attendee ${event.attendeeId} signal: ${event.signalStrength.name}');
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
    if (wantCode != null &&
        !RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(wantCode)) {
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
      final session =
          await backend.joinRoom(roomCode: code, nickname: nickname);
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
    final requested = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    final ok = await MeetingModel().switchCamera(requested);
    if (!mounted) return;
    if (ok) {
      setState(() => _cameraPosition = requested);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('摄像头: ${requested == CameraPosition.front ? '前置' : '后置'}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('切换摄像头失败。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildHeroHeader(),
                const SizedBox(height: 24),
                _buildServerCard(),
                const SizedBox(height: 20),
                _buildMainTabCard(),
                if (_error != null) _buildErrorBanner(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Chime Live',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '低延迟多流互动直播 · 音视频会议',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField(
            controller: _serverController,
            label: '后台服务器地址 (Mac 局域网 IP)',
            hintText: 'http://192.168.31.8:3000',
            prefixIcon: Icons.dns_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DeviceCheckPage(server: _server),
            )),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.health_and_safety_rounded,
                    color: Color(0xFF34D399),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '设备就绪自检（摄像头/麦克风/连通性）',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF34D399).withValues(alpha: 0.7),
                    size: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabCard() {
    return GlassContainer(
      borderRadius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: '加入房间'), Tab(text: '创建房间')],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 270,
            child: TabBarView(
              controller: _tabs,
              children: [_joinTab(), _createTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassTextField(
          controller: _joinCodeController,
          label: '房间号',
          hintText: '如 482913',
          prefixIcon: Icons.tag_rounded,
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: _joinNameController,
          label: '我的昵称 (可选)',
          hintText: '观众-1',
          prefixIcon: Icons.person_rounded,
        ),
        const SizedBox(height: 18),
        GlassGradientButton(
          onPressed: _busy ? null : _joinRoom,
          isLoading: _busy,
          icon: Icons.login_rounded,
          child: const Text('进入房间'),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '输入房主分享的 4~12 位房间号即可快速接入',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _createTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassTextField(
          controller: _createCodeController,
          label: '期望房间号 (可选，4-12位)',
          hintText: '不填则系统随机分配',
          prefixIcon: Icons.add_circle_outline_rounded,
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: _createNameController,
          label: '主播昵称 (可选)',
          hintText: '主播',
          prefixIcon: Icons.badge_rounded,
        ),
        const SizedBox(height: 18),
        GlassGradientButton(
          onPressed: _busy ? null : _createAndJoin,
          isLoading: _busy,
          icon: Icons.video_call_rounded,
          child: const Text('创建并开始直播'),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '创建房间后可直接将房间号分享给观众',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFDA4AF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFDA4AF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MeetingView(widget.joinInfo,
                onLeave: (_) => Navigator.of(context).pop()),
            // Top Left Floating Room Code Pill
            Positioned(
              top: 66,
              left: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor:
                                const Color(0xFF1E293B).withValues(alpha: 0.95),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Text('房间号 ${widget.roomCode} 已复制到剪贴板'),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              color: Color(0xFF818CF8),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '房号 ${widget.roomCode}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Top Right Floating Camera Switch Button
            Positioned(
              top: 66,
              right: 14,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onSwitchCamera,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
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
}
