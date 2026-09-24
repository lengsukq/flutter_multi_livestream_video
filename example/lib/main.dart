import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_artc/flutter_realtime_media_artc.dart';
import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_chime/flutter_realtime_media_chime.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/glass_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ChimeExampleApp());
}

final MediaRegistry _mediaRegistry = MediaRegistry([
  const ArtcSessionFactory(),
  const AgoraSessionFactory(),
  const LiveKitSessionFactory(),
  ChimeSessionFactory(),
  const TrtcSessionFactory(),
]);

final Map<String, MediaTrackRenderer> _mediaRenderers = {
  'artc': const ArtcTrackRenderer(),
  'agora': const AgoraTrackRenderer(),
  'livekit': const LiveKitTrackRenderer(),
  'chime': const ChimeTrackRenderer(),
  'trtc': const TrtcTrackRenderer(),
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
    title: 'Realtime Media',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
        surfaceContainerHighest: Color(0xFFF1F5F9),
        outline: Color(0xFFE2E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      useMaterial3: true,
    ),
    home: const JoinScreen(),
  );
}

/// Adaptive and clean Join Screen.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen>
    with SingleTickerProviderStateMixin {
  static const _deviceIdPreferenceKey = 'realtime_media_demo_device_id';

  late final TabController _tabs;
  late final Future<String> _deviceIdFuture;
  final _serverController = TextEditingController();
  final _createCodeController = TextEditingController();
  final _createNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _joinNameController = TextEditingController();

  bool _busy = false;
  String? _error;

  // Backend connection status: null = untested, true = online, false = offline
  bool? _serverOnline;
  String? _serverProviderInfo;
  bool _testingServer = false;
  bool _serverStatusRequestInFlight = false;
  Timer? _serverStatusTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _deviceIdFuture = _loadOrCreateDeviceId();
    _serverController.text = _defaultBackendUrl;
    unawaited(_testConnection());
    _serverStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_testConnection(silent: true));
    });
  }

  @override
  void dispose() {
    _serverStatusTimer?.cancel();
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

  Future<String> _loadOrCreateDeviceId() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = preferences.getString(_deviceIdPreferenceKey)?.trim();
      if (existing != null && existing.isNotEmpty) return existing;
      final created = _generateDeviceId();
      await preferences.setString(_deviceIdPreferenceKey, created);
      return created;
    } catch (_) {
      return _generateDeviceId();
    }
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _testConnection({bool silent = false}) async {
    if (_serverStatusRequestInFlight) return;
    final url = _server;
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _serverOnline = false;
          _serverProviderInfo = 'No URL specified';
        });
      }
      return;
    }
    _serverStatusRequestInFlight = true;
    if (!silent && mounted) setState(() => _testingServer = true);
    HttpClient? client;
    try {
      final uri = Uri.parse(url.endsWith('/') ? '${url}health' : '$url/health');
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final active = json['activeProvider'] as String? ?? 'ready';
        if (mounted && _server == url) {
          setState(() {
            _serverOnline = true;
            _serverProviderInfo = 'Default: $active';
          });
        }
      } else {
        if (mounted && _server == url) {
          setState(() {
            _serverOnline = false;
            _serverProviderInfo = 'HTTP ${resp.statusCode}';
          });
        }
      }
    } catch (_) {
      if (mounted && _server == url) {
        setState(() {
          _serverOnline = false;
          _serverProviderInfo = 'Unreachable';
        });
      }
    } finally {
      client?.close(force: true);
      _serverStatusRequestInFlight = false;
      if (!silent && mounted) setState(() => _testingServer = false);
    }
  }

  void _generateRandomCreateCode() {
    final code = '${100000 + (DateTime.now().millisecondsSinceEpoch % 900000)}';
    setState(() {
      _createCodeController.text = code;
    });
  }

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
    final deviceId = await _deviceIdFuture;
    final displayName = _nickname(_createNameController);
    await _run(() async {
      final room = await client.createRoomAndJoinIdentity(
        roomCode: requestedCode.isEmpty ? null : requestedCode,
        identity: MediaIdentity(
          userId: deviceId,
          displayName: displayName,
          deviceId: deviceId,
        ),
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
    final deviceId = await _deviceIdFuture;
    final displayName = _nickname(_joinNameController);
    await _run(() async {
      final room = await client.joinRoomIdentity(
        roomCode: code,
        identity: MediaIdentity(
          userId: deviceId,
          displayName: displayName,
          deviceId: deviceId,
        ),
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
          builder: (_) => MediaRoomView(room: room, renderer: renderer),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 640;
            final contentWidth = isWide ? 560.0 : constraints.maxWidth;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                  vertical: 20,
                ),
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildServerCard(),
                      const SizedBox(height: 16),
                      _buildActionTabsCard(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _buildHeader() => Column(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC7D2FE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.videocam_rounded,
          size: 28,
          color: Color(0xFF4F46E5),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Realtime Media',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02,
          color: Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Multi-Provider Livestream & Video SDK',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _buildServerCard() => GlassContainer(
    borderRadius: 18,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Backend Service Endpoint',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            InkWell(
              onTap: _testingServer ? null : _testConnection,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    if (_testingServer)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _serverOnline == true
                              ? const Color(0xFF059669)
                              : _serverOnline == false
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _serverProviderInfo ??
                          (_testingServer ? 'Checking…' : 'Check'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _serverOnline == true
                            ? const Color(0xFF059669)
                            : _serverOnline == false
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassTextField(
          controller: _serverController,
          label: 'Demo Backend URL',
          hintText: 'http://192.168.31.8:3000',
          prefixIcon: Icons.dns_outlined,
          keyboardType: TextInputType.url,
          onChanged: (_) {
            setState(() {
              _serverOnline = null;
              _serverProviderInfo = null;
            });
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _serverPresetChip('Default', _defaultBackendUrl),
            _serverPresetChip('localhost:3000', 'http://localhost:3000'),
            _serverPresetChip('Android 10.0.2.2', 'http://10.0.2.2:3000'),
          ],
        ),
      ],
    ),
  );

  Widget _serverPresetChip(String label, String url) => InkWell(
    onTap: () {
      _serverController.text = url;
      _testConnection();
    },
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),
        ),
      ),
    ),
  );

  Widget _buildActionTabsCard() => GlassContainer(
    borderRadius: 20,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Join room'),
              Tab(text: 'Create room'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) {
            final isJoin = _tabs.index == 0;
            return isJoin
                ? _roomForm(
                    code: _joinCodeController,
                    name: _joinNameController,
                    codeLabel: 'Room code',
                    actionLabel: 'Join room',
                    action: _joinRoom,
                    isCreate: false,
                  )
                : _roomForm(
                    code: _createCodeController,
                    name: _createNameController,
                    codeLabel: 'Room code (optional)',
                    actionLabel: 'Create and join',
                    action: _createRoom,
                    isCreate: true,
                  );
          },
        ),
      ],
    ),
  );

  Widget _roomForm({
    required TextEditingController code,
    required TextEditingController name,
    required String codeLabel,
    required String actionLabel,
    required Future<void> Function() action,
    required bool isCreate,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GlassTextField(
              controller: code,
              label: codeLabel,
              hintText: '4–12 letters or digits',
              prefixIcon: Icons.tag_rounded,
            ),
          ),
          if (isCreate) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _generateRandomCreateCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF475569),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.casino_outlined, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Random',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      GlassTextField(
        controller: name,
        label: 'Display name (optional)',
        hintText: 'e.g. Alice / Bob',
        prefixIcon: Icons.person_outline_rounded,
      ),
      const SizedBox(height: 18),
      GlassGradientButton(
        onPressed: _busy ? null : action,
        isLoading: _busy,
        icon: isCreate ? Icons.add_rounded : Icons.arrow_forward_rounded,
        child: Text(actionLabel),
      ),
    ],
  );

  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFECDD3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFDC2626),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Color(0xFFB91C1C),
          ),
          onPressed: () => setState(() => _error = null),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}

/// Meeting Room Page with modern, clean, minimal floating aesthetics.
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
  bool _showChatPanel = false;
  bool _codeCopiedRecently = false;
  String? _error;

  Timer? _callDurationTimer;
  int _callSeconds = 0;

  MediaSession get session => widget.room.session;

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
  }

  void _startDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callSeconds++);
      }
    });
  }

  String get _formattedDuration {
    final mins = _callSeconds ~/ 60;
    final secs = _callSeconds % 60;
    final mStr = mins.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  @override
  void dispose() {
    _callDurationTimer?.cancel();
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

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Meeting?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Are you sure you want to disconnect? Your audio and video stream will stop immediately.',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await widget.room.dispose();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    setState(() => _codeCopiedRecently = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopiedRecently = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text('Room code ${widget.room.roomCode} copied'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaSnapshot>(
    stream: session.snapshots,
    initialData: session.snapshot,
    builder: (context, snapshot) {
      final value = snapshot.data ?? session.snapshot;

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(value, widget.room.providerId),
              if (_error != null) _buildInlineError(),
              Expanded(
                child: value.participants.isEmpty
                    ? _buildModernWaitingRoom(value)
                    : _buildAdaptiveVideoGrid(value),
              ),
              if (value.contentShareTrack != null)
                _buildScreenShareBanner(value),
              if (_showChatPanel) _buildChatDrawer(session),
              _ModernDockControls(
                session: session,
                snapshot: value,
                isChatOpen: _showChatPanel,
                onToggleChat: () =>
                    setState(() => _showChatPanel = !_showChatPanel),
                onLeave: _confirmLeave,
                run: _run,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildTopBar(MediaSnapshot value, String providerId) {
    final providerLabel = switch (providerId) {
      'artc' => 'Alibaba Cloud ARTC',
      'livekit' => 'LiveKit',
      'agora' => 'Agora',
      'trtc' => 'Tencent TRTC',
      _ => 'Chime',
    };
    final providerBackground = switch (providerId) {
      'artc' => const Color(0xFFF0FDF4),
      'livekit' => const Color(0xFFF0F9FF),
      'agora' => const Color(0xFFF5F3FF),
      'trtc' => const Color(0xFFFFF1F0),
      _ => const Color(0xFFFFF7ED),
    };
    final providerBorder = switch (providerId) {
      'artc' => const Color(0xFFBBF7D0),
      'livekit' => const Color(0xFFBAE6FD),
      'agora' => const Color(0xFFDDD6FE),
      'trtc' => const Color(0xFFFECACA),
      _ => const Color(0xFFFED7AA),
    };
    final providerColor = switch (providerId) {
      'artc' => const Color(0xFF16A34A),
      'livekit' => const Color(0xFF0284C7),
      'agora' => const Color(0xFF7C3AED),
      'trtc' => const Color(0xFFD94645),
      _ => const Color(0xFFEA580C),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Clean Back button
          Tooltip(
            message: 'Leave Meeting',
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
                  size: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Room Code Badge with Copy micro-interaction
          InkWell(
            onTap: _copyRoomCode,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.room.roomCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _codeCopiedRecently
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    size: 13,
                    color: _codeCopiedRecently
                        ? const Color(0xFF059669)
                        : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Provider Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: providerBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: providerBorder),
            ),
            child: Text(
              providerLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: providerColor,
              ),
            ),
          ),
          const Spacer(),
          // Live Call Timer Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                const SizedBox(width: 6),
                Text(
                  _formattedDuration,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Participant Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  '${value.participants.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFECDD3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: Color(0xFFDC2626),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            size: 14,
            color: Color(0xFFB91C1C),
          ),
          onPressed: () => setState(() => _error = null),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  Widget _buildModernWaitingRoom(MediaSnapshot value) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Concentric animated pulsing circle
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEEF2FF).withValues(alpha: 0.6),
                ),
              ),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEEF2FF),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "You're the only one here",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.01,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share the room code or invite link to start streaming',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          // Clean Room Code Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ROOM CODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.08,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      widget.room.roomCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _copyRoomCode,
                  icon: Icon(
                    _codeCopiedRecently
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    size: 15,
                  ),
                  label: Text(_codeCopiedRecently ? 'Copied' : 'Copy Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildAdaptiveVideoGrid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final count = value.participants.length;

      int crossAxisCount;
      double aspectRatio;

      if (width > 900) {
        crossAxisCount = count <= 2
            ? 2
            : count <= 4
            ? 2
            : count <= 6
            ? 3
            : 4;
        aspectRatio = 16 / 10;
      } else if (width > 600) {
        crossAxisCount = count <= 2 ? 2 : 3;
        aspectRatio = 4 / 3;
      } else {
        crossAxisCount = count == 1 ? 1 : 2;
        aspectRatio = count == 1 ? 4 / 3 : 1.0;
      }

      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: count,
        itemBuilder: (context, index) => _ParticipantTile(
          participant: value.participants[index],
          renderer: widget.renderer,
        ),
      );
    },
  );

  Widget _buildScreenShareBanner(MediaSnapshot value) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    height: 160,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: MediaTrackView(
            renderer: widget.renderer,
            track: value.contentShareTrack,
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.screen_share_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Screen Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildChatDrawer(MediaSession session) {
    final messenger = session is MediaDataMessenger
        ? session as MediaDataMessenger
        : null;
    if (messenger == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: 'Type a message to participants…',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: (_) => _sendDataMessage(messenger),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            onPressed: () => _sendDataMessage(messenger),
            icon: const Icon(
              Icons.arrow_upward_rounded,
              color: Color(0xFF4F46E5),
              size: 18,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFEEF2FF),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  void _sendDataMessage(MediaDataMessenger messenger) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _run(() => messenger.sendMessage(text)).then((_) {
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message sent'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    });
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, required this.renderer});

  final MediaParticipant participant;
  final MediaTrackRenderer renderer;

  @override
  Widget build(BuildContext context) {
    final hasVideo = participant.videoTrack != null;
    final displayName = participant.displayName.isEmpty
        ? 'Participant'
        : participant.displayName;
    final initial = displayName.characters.first.toUpperCase();
    final isSpeaking = participant.isSpeaking;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isSpeaking ? 2.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSpeaking
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0x06000000),
            blurRadius: isSpeaking ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              MediaTrackView(renderer: renderer, track: participant.videoTrack)
            else
              // Modern, minimalist avatar card
              Container(
                color: const Color(0xFFF8FAFC),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: isSpeaking
                            ? const Color(0xFF10B981)
                            : const Color(0xFFC7D2FE),
                        width: isSpeaking ? 2 : 1,
                      ),
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
            // Floating Frosted Glass Name Badge
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$displayName${participant.isLocal ? ' (you)' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      participant.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 14,
                      color: participant.isMuted
                          ? const Color(0xFFDC2626)
                          : isSpeaking
                          ? const Color(0xFF10B981)
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

/// Floating Island Control Dock with sleek rounded modern pills.
class _ModernDockControls extends StatelessWidget {
  const _ModernDockControls({
    required this.session,
    required this.snapshot,
    required this.isChatOpen,
    required this.onToggleChat,
    required this.onLeave,
    required this.run,
  });

  final MediaSession session;
  final MediaSnapshot snapshot;
  final bool isChatOpen;
  final VoidCallback onToggleChat;
  final VoidCallback onLeave;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final interactive = session is InteractiveMediaSession
        ? session as InteractiveMediaSession
        : null;
    final canSendData =
        session is MediaDataMessenger && snapshot.capabilities.canSendData;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            if (interactive != null) ...[
              // Audio Toggle (Mute / Unmute)
              _dockButton(
                tooltip: snapshot.localMuted
                    ? 'Unmute microphone'
                    : 'Mute microphone',
                onPressed: () => run(interactive.toggleMute),
                icon: snapshot.localMuted
                    ? Icons.mic_off_outlined
                    : Icons.mic_none_rounded,
                isDanger: snapshot.localMuted,
                isActive: !snapshot.localMuted,
              ),
              const SizedBox(width: 8),
              // Camera Toggle (Start / Stop)
              _dockButton(
                tooltip: snapshot.localVideoEnabled
                    ? 'Turn off camera'
                    : 'Turn on camera',
                onPressed: () => run(
                  () =>
                      interactive.setVideoEnabled(!snapshot.localVideoEnabled),
                ),
                icon: snapshot.localVideoEnabled
                    ? Icons.videocam_outlined
                    : Icons.videocam_off_outlined,
                isActive: snapshot.localVideoEnabled,
              ),
              if (snapshot.capabilities.canSwitchCamera) ...[
                const SizedBox(width: 8),
                _dockButton(
                  tooltip: 'Switch camera',
                  onPressed: () => run(
                    () => interactive.switchCamera(MediaCameraPosition.back),
                  ),
                  icon: Icons.cameraswitch_outlined,
                ),
              ],
            ],
            if (canSendData) ...[
              const SizedBox(width: 8),
              _dockButton(
                tooltip: 'Data message',
                onPressed: onToggleChat,
                icon: Icons.chat_bubble_outline_rounded,
                isActive: isChatOpen,
              ),
            ],
            const SizedBox(width: 10),
            // End call button
            Tooltip(
              message: 'Leave Meeting',
              child: InkWell(
                onTap: onLeave,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 44,
                  height: 44,
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
  }

  Widget _dockButton({
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
    bool isDanger = false,
    bool isActive = false,
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
      message: tooltip,
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
}
