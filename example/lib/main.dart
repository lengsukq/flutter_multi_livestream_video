import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_chime/flutter_realtime_media_chime.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';

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
          fontSize: 17,
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
  late final TabController _tabs;
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _serverController.text = _defaultBackendUrl;
    _testConnection();
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

  Future<void> _testConnection() async {
    final url = _server;
    if (url.isEmpty) {
      setState(() {
        _serverOnline = false;
        _serverProviderInfo = 'No URL specified';
      });
      return;
    }
    setState(() => _testingServer = true);
    try {
      final uri = Uri.parse(url.endsWith('/') ? '${url}health' : '$url/health');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final active = json['activeProvider'] as String? ?? 'ready';
        if (mounted) {
          setState(() {
            _serverOnline = true;
            _serverProviderInfo = 'Engine: $active';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _serverOnline = false;
            _serverProviderInfo = 'HTTP ${resp.statusCode}';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverOnline = false;
          _serverProviderInfo = 'Unreachable';
        });
      }
    } finally {
      if (mounted) setState(() => _testingServer = false);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive horizontal padding: wide screens center the card, small screens use responsive edges
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
        'Chime Live',
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
                      _serverProviderInfo ?? (_testingServer ? 'Checking…' : 'Check'),
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
          prefixIcon: Icons.dns_rounded,
          keyboardType: TextInputType.url,
          onChanged: (_) {
            setState(() {
              _serverOnline = null;
              _serverProviderInfo = null;
            });
          },
        ),
        const SizedBox(height: 10),
        // Quick preset chips for rapid dev testing
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
        // Pill-style segmented TabBar
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
        // Adaptive tab body without hardcoded 280px constraint
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
                    Text('Random', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        prefixIcon: Icons.person_rounded,
      ),
      const SizedBox(height: 18),
      GlassGradientButton(
        onPressed: _busy ? null : action,
        isLoading: _busy,
        icon: isCreate ? Icons.add_circle_outline_rounded : Icons.login_rounded,
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
        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
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
          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB91C1C)),
          onPressed: () => setState(() => _error = null),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}

/// Meeting Room Page with responsive adaptive grid and modern controls.
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

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Meeting?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to leave the room? Your camera and mic will be disconnected.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code ${widget.room.roomCode} copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      final isLiveKit = widget.room.providerId == 'livekit';

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Leave',
            onPressed: _confirmLeave,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InkWell(
                  onTap: _copyRoomCode,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Room ${widget.room.roomCode}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Provider Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLiveKit ? const Color(0xFFF0F9FF) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLiveKit ? const Color(0xFFBAE6FD) : const Color(0xFFFED7AA),
                  ),
                ),
                child: Text(
                  isLiveKit ? 'LiveKit' : 'Chime',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLiveKit ? const Color(0xFF0284C7) : const Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Participants count chip
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF475569)),
                  const SizedBox(width: 5),
                  Text(
                    '${value.participants.length}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Color(0xFFB91C1C)),
                        onPressed: () => setState(() => _error = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              // Main video / media area
              Expanded(
                child: value.participants.isEmpty
                    ? _buildWaitingRoom(value)
                    : _buildAdaptiveVideoGrid(value),
              ),
              // Screen share preview if present
              if (value.contentShareTrack != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: MediaTrackView(
                      renderer: widget.renderer,
                      track: value.contentShareTrack,
                    ),
                  ),
                ),
              // Chat panel drawer if expanded
              if (_showChatPanel) _buildChatDrawer(session),
              // Bottom controls bar
              _RoomControls(
                session: session,
                snapshot: value,
                isChatOpen: _showChatPanel,
                onToggleChat: () => setState(() => _showChatPanel = !_showChatPanel),
                onLeave: _confirmLeave,
                run: _run,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildWaitingRoom(MediaSnapshot value) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                Icons.sensors_rounded,
                size: 32,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Room is Ready',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Status: ${value.state.name}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _copyRoomCode,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text('Share Room Code (${widget.room.roomCode})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildAdaptiveVideoGrid(MediaSnapshot value) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final count = value.participants.length;

      // Smart adaptive column computation based on width and participant count
      int crossAxisCount;
      double aspectRatio;

      if (width > 900) {
        crossAxisCount = count <= 2 ? 2 : count <= 4 ? 2 : count <= 6 ? 3 : 4;
        aspectRatio = 16 / 10;
      } else if (width > 600) {
        crossAxisCount = count <= 2 ? 2 : 3;
        aspectRatio = 4 / 3;
      } else {
        // Mobile portrait or narrow screen
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

  Widget _buildChatDrawer(MediaSession session) {
    final messenger = session is MediaDataMessenger ? session as MediaDataMessenger : null;
    if (messenger == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                hintText: 'Send message to room…',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) => _sendDataMessage(messenger),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            onPressed: () => _sendDataMessage(messenger),
            icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5), size: 20),
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
        const SnackBar(
          content: Text('Message sent'),
          duration: Duration(milliseconds: 1500),
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
    final displayName = participant.displayName.isEmpty ? 'Participant' : participant.displayName;
    final initial = displayName.characters.first.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: participant.isSpeaking ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: participant.isSpeaking ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              MediaTrackView(
                renderer: renderer,
                track: participant.videoTrack,
              )
            else
              // Clean light avatar placeholder
              Container(
                color: const Color(0xFFF8FAFC),
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEEF2FF),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Floating bottom info pill
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
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
                    const SizedBox(width: 4),
                    Icon(
                      participant.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 15,
                      color: participant.isMuted
                          ? const Color(0xFFDC2626)
                          : participant.isSpeaking
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

class _RoomControls extends StatelessWidget {
  const _RoomControls({
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
    final canSendData = session is MediaDataMessenger && snapshot.capabilities.canSendData;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
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
              _controlButton(
                tooltip: snapshot.localMuted ? 'Unmute' : 'Mute',
                onPressed: () => run(interactive.toggleMute),
                icon: snapshot.localMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                isDanger: snapshot.localMuted,
                isActive: !snapshot.localMuted,
              ),
              const SizedBox(width: 8),
              // Camera Toggle (Start / Stop)
              _controlButton(
                tooltip: snapshot.localVideoEnabled ? 'Stop camera' : 'Start camera',
                onPressed: () => run(
                  () => interactive.setVideoEnabled(!snapshot.localVideoEnabled),
                ),
                icon: snapshot.localVideoEnabled
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                isActive: snapshot.localVideoEnabled,
              ),
              if (snapshot.capabilities.canSwitchCamera) ...[
                const SizedBox(width: 8),
                _controlButton(
                  tooltip: 'Switch camera',
                  onPressed: () => run(
                    () => interactive.switchCamera(MediaCameraPosition.back),
                  ),
                  icon: Icons.cameraswitch_rounded,
                ),
              ],
            ],
            if (canSendData) ...[
              const SizedBox(width: 8),
              _controlButton(
                tooltip: 'Chat messages',
                onPressed: onToggleChat,
                icon: Icons.chat_bubble_outline_rounded,
                isActive: isChatOpen,
              ),
            ],
            const SizedBox(width: 12),
            // End call button
            InkWell(
              onTap: onLeave,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: fg, size: 20),
        ),
      ),
    );
  }
}
