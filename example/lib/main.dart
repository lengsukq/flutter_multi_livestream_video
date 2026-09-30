import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'standalone_chat_demo.dart';
import 'demo_strings.dart';
import 'demo_background.dart';

const _demoLocalePreferenceKey = 'realtime_media_demo_locale';
Locale? _initialDemoLocale;

enum _JoinFormError { backendMissing, roomCodeMissing, invalidRoomCode }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep native status bars aligned with the SDK's light surface on iOS and
  // Android, including screens that use custom headers instead of AppBar.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF4F7FB),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  final preferences = await SharedPreferences.getInstance();
  final savedLocale = preferences.getString(_demoLocalePreferenceKey);
  _initialDemoLocale = switch (savedLocale) {
    'zh' => const Locale('zh', 'CN'),
    'en' => const Locale('en'),
    _ => null,
  };
  runApp(const ChimeExampleApp());
}

const String _defaultBackendUrl = String.fromEnvironment(
  'MEDIA_BACKEND_URL',
  defaultValue: 'http://192.168.31.8:3000',
);
const String _appToken = String.fromEnvironment('MEDIA_APP_TOKEN');

class ChimeExampleApp extends StatefulWidget {
  const ChimeExampleApp({super.key});

  @override
  State<ChimeExampleApp> createState() => _ChimeExampleAppState();
}

class _ChimeExampleAppState extends State<ChimeExampleApp> {
  Locale? _locale = _initialDemoLocale;

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _demoLocalePreferenceKey,
      locale.languageCode == 'zh' ? 'zh' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Realtime Media',
    debugShowCheckedModeBanner: false,
    locale: _locale,
    supportedLocales: RealtimeStrings.supportedLocales,
    localizationsDelegates: RealtimeStrings.localizationsDelegates,
    theme: RealtimeUiTheme.light(),
    home: JoinScreen(onLocaleChanged: _setLocale),
  );
}

/// Adaptive and clean Join Screen directly reusing SDK built-in glass UI.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with TickerProviderStateMixin {
  static const _deviceIdPreferenceKey = 'realtime_media_demo_device_id';
  static const _displayNamePreferenceKey = 'realtime_media_demo_display_name';

  late final TabController _demoTabs;
  late final TabController _roomTabs;
  late final Future<String> _deviceIdFuture;
  final _serverController = TextEditingController();
  final _createCodeController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _busy = false;
  String? _error;
  _JoinFormError? _formError;
  MediaRoomMode _createRoomMode = MediaRoomMode.meeting;

  // Backend connection status: null = untested, true = online, false = offline
  bool? _serverOnline;
  String? _serverProviderInfo;
  String? _serverMediaProviderId;
  String? _serverChatProviderId;
  bool _testingServer = false;
  bool _serverStatusRequestInFlight = false;
  Timer? _serverStatusTimer;
  bool _roomListRequestInFlight = false;
  List<MediaRoomSummary> _availableRooms = const [];
  String? _roomListError;
  MediaRoomMode? _roomFilter;
  final Map<String, String> _roomOwnerCredentials = {};

  @override
  void initState() {
    super.initState();
    _demoTabs = TabController(length: 2, vsync: this);
    _roomTabs = TabController(length: 3, vsync: this);
    _deviceIdFuture = _loadOrCreateDeviceId();
    unawaited(_loadDisplayName());
    _serverController.text = _defaultBackendUrl;
    unawaited(_testConnection());
    unawaited(_refreshRooms(silent: true));
    _serverStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_testConnection(silent: true));
      if (_demoTabs.index == 0 && _roomTabs.index == 0 && !_busy) {
        unawaited(_refreshRooms(silent: true));
      }
    });
  }

  Future<void> _joinDiscoveredRoom(MediaRoomSummary room) async {
    _joinCodeController.text = room.roomCode;
    await _joinRoom(
      providerId: room.engineId ?? room.providerId,
      roomMode: room.roomMode,
    );
  }

  Future<void> _refreshRooms({bool silent = false}) async {
    if (_roomListRequestInFlight || _server.isEmpty) return;
    _roomListRequestInFlight = true;
    if (!silent && mounted) {
      setState(() => _roomListError = null);
    }
    try {
      final rooms = await _newRealtime().listRooms();
      if (!mounted) return;
      final changed =
          _availableRooms.length != rooms.length ||
          _roomListError != null ||
          !_availableRooms.every(
            (r) => rooms.any((nr) => nr.roomCode == r.roomCode),
          );
      if (changed) {
        setState(() {
          _availableRooms = rooms;
          _roomListError = null;
        });
      }
    } catch (error) {
      if (!silent && mounted) {
        setState(() => _roomListError = error.toString());
      }
    } finally {
      _roomListRequestInFlight = false;
      if (!silent && mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _serverStatusTimer?.cancel();
    _demoTabs.dispose();
    _roomTabs.dispose();
    _serverController.dispose();
    _createCodeController.dispose();
    _joinCodeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  String get _server => _serverController.text.trim();

  void _showFormError(_JoinFormError error) {
    setState(() {
      _formError = error;
      _error = null;
    });
  }

  String? _displayError(BuildContext context) {
    final strings = DemoStrings.of(context);
    return switch (_formError) {
      _JoinFormError.backendMissing => strings.enterBackendUrl,
      _JoinFormError.roomCodeMissing => strings.enterRoomCode,
      _JoinFormError.invalidRoomCode => strings.invalidRoomCode,
      null => _error,
    };
  }

  Future<void> _loadDisplayName() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_displayNamePreferenceKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        _displayNameController.text = saved;
      } else {
        final deviceId = await _deviceIdFuture;
        final generated = _defaultDisplayName(deviceId);
        _displayNameController.text = generated;
        await preferences.setString(_displayNamePreferenceKey, generated);
      }
      if (mounted) setState(() {});
    } catch (_) {
      final deviceId = await _deviceIdFuture;
      if (_displayNameController.text.trim().isEmpty) {
        _displayNameController.text = _defaultDisplayName(deviceId);
      }
      if (mounted) setState(() {});
    }
  }

  String _defaultDisplayName(String deviceId) {
    final compact = deviceId.replaceAll('-', '');
    final suffix = compact.length >= 6 ? compact.substring(0, 6) : compact;
    return 'user-$suffix';
  }

  Future<String> _resolveDisplayName(String deviceId) async {
    var value = _displayNameController.text.trim();
    if (value.isEmpty) {
      value = _defaultDisplayName(deviceId);
      _displayNameController.text = value;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_displayNamePreferenceKey, value);
    } catch (_) {
      // Persistence is a demo convenience; the identity remains usable.
    }
    return value;
  }

  Future<void> _persistDisplayName(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_displayNamePreferenceKey, normalized);
    } catch (_) {
      // Ignore persistence failures in the demo.
    }
  }

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
          _serverMediaProviderId = null;
          _serverChatProviderId = null;
        });
      }
      return;
    }
    _serverStatusRequestInFlight = true;
    if (!silent && mounted) setState(() => _testingServer = true);
    try {
      final report = await _newRealtime().diagnoseBackend();
      final backendCheck = report.checkById('backend');
      final online = backendCheck?.status != MediaDoctorStatus.fail;
      final newInfo = online
          ? backendCheck?.status == MediaDoctorStatus.warning
                ? 'Reachable (health unavailable)'
                : report.activeProvider == null
                ? 'Ready'
                : 'Default: ${mediaProviderDisplayName(report.activeProvider!)}'
          : report.backendReachable
          ? 'Health check failed'
          : 'Unreachable';
      if (mounted && _server == url) {
        final changed =
            _serverOnline != online ||
            _serverMediaProviderId != report.activeProvider ||
            _serverChatProviderId != report.activeChatProvider ||
            _serverProviderInfo != newInfo;
        if (changed) {
          setState(() {
            _serverOnline = online;
            _serverMediaProviderId = report.activeProvider;
            _serverChatProviderId = report.activeChatProvider;
            _serverProviderInfo = newInfo;
          });
        }
      }
    } catch (_) {
      if (mounted && _server == url) {
        if (_serverOnline != false || _serverProviderInfo != 'Unreachable') {
          setState(() {
            _serverOnline = false;
            _serverProviderInfo = 'Unreachable';
            _serverMediaProviderId = null;
            _serverChatProviderId = null;
          });
        }
      }
    } finally {
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

  Future<void> _pasteJoinCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _joinCodeController.text = text);
    }
  }

  Future<void> _createRoom() async {
    if (_server.isEmpty) {
      _showFormError(_JoinFormError.backendMissing);
      return;
    }
    final requestedCode = _createCodeController.text.trim();
    if (requestedCode.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(requestedCode)) {
      _showFormError(_JoinFormError.invalidRoomCode);
      return;
    }
    final roomLabel = requestedCode.isEmpty
        ? DemoStrings.of(context).createAndJoin
        : requestedCode;
    final realtime = _newRealtime();
    final role = _createRoomMode == MediaRoomMode.broadcast
        ? MediaRole.host
        : MediaRole.participant;
    final deviceId = await _deviceIdFuture;
    final displayName = await _resolveDisplayName(deviceId);
    final initialMediaSettings = await _runPreJoin(
      realtime,
      role: role,
      displayName: displayName,
      roomLabel: roomLabel,
    );
    if (initialMediaSettings == null) return;
    await _run(() async {
      final connection = await realtime.open(
        RealtimeRequest.create(
          type: _createRoomMode == MediaRoomMode.broadcast
              ? RealtimeExperience.live
              : RealtimeExperience.meeting,
          roomCode: requestedCode.isEmpty ? null : requestedCode,
          user: RealtimeUser(
            id: deviceId,
            name: displayName,
            deviceId: deviceId,
          ),
        ),
      );
      final room = connection.mediaRoom!;
      final ownerCredential = room.media.roomOwnerCredential;
      if (ownerCredential != null) {
        _roomOwnerCredentials[room.roomCode] = ownerCredential;
      }
      await _openMeeting(
        connection,
        initialMediaSettings: initialMediaSettings,
      );
    });
  }

  Future<void> _joinRoom({String? providerId, MediaRoomMode? roomMode}) async {
    if (_server.isEmpty) {
      _showFormError(_JoinFormError.backendMissing);
      return;
    }
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      _showFormError(_JoinFormError.roomCodeMissing);
      return;
    }
    final realtime = _newRealtime();
    final role = roomMode == MediaRoomMode.broadcast
        ? MediaRole.viewer
        : MediaRole.participant;
    final deviceId = await _deviceIdFuture;
    final displayName = await _resolveDisplayName(deviceId);
    final initialMediaSettings = await _runPreJoin(
      realtime,
      role: role,
      providerId: providerId,
      roomCode: code,
      displayName: displayName,
      roomLabel: code,
    );
    if (initialMediaSettings == null) return;
    await _run(() async {
      final connection = await realtime.open(
        RealtimeRequest.join(
          type: roomMode == MediaRoomMode.broadcast
              ? RealtimeExperience.live
              : RealtimeExperience.meeting,
          roomCode: code,
          roomOwnerCredential: _roomOwnerCredentials[code],
          user: RealtimeUser(
            id: deviceId,
            name: displayName,
            deviceId: deviceId,
          ),
        ),
      );
      final room = connection.mediaRoom!;
      final ownerCredential = room.media.roomOwnerCredential;
      if (ownerCredential != null) {
        _roomOwnerCredentials[room.roomCode] = ownerCredential;
      }
      await _openMeeting(
        connection,
        initialMediaSettings: initialMediaSettings,
      );
    });
  }

  Realtime _newRealtime() => Realtime.standard(
    backendUrl: _server,
    tokenProvider: _appToken.trim().isEmpty ? null : () async => _appToken,
  );

  Future<MediaLocalPreviewSettings?> _runPreJoin(
    Realtime realtime, {
    required MediaRole role,
    required String displayName,
    required String roomLabel,
    String? providerId,
    String? roomCode,
  }) async {
    final backgroundPresets = await DemoBackground.presets;
    if (!mounted) return null;
    return MediaPreJoinPage.show(
      context,
      runCheck: () => realtime.preJoin(
        role: role,
        providerId: providerId,
        roomCode: roomCode,
      ),
      openPreview: (providerId, previewRole) => realtime.createLocalPreview(
        providerId: providerId,
        role: previewRole,
      ),
      displayName: displayName,
      roomLabel: roomLabel,
      backendProviderId: _serverMediaProviderId ?? '',
      backgroundImagePresets: backgroundPresets,
      title: role == MediaRole.viewer
          ? DemoStrings.of(context).live
          : role == MediaRole.host
          ? DemoStrings.of(context).startLive
          : DemoStrings.of(context).meeting,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _formError = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMeeting(
    RealtimeConnection connection, {
    required MediaLocalPreviewSettings initialMediaSettings,
  }) async {
    final realtimeRoom = connection.mediaRoom!;
    if (!mounted) {
      await connection.dispose();
      return;
    }

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MeetingRoomPage(
            room: realtimeRoom,
            initialMediaSettings: initialMediaSettings,
          ),
        ),
      );
    } finally {
      await connection.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: RealtimeAmbientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 640;
              final contentWidth = isWide ? 560.0 : constraints.maxWidth;

              return Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    left: isWide ? 24 : 16,
                    right: isWide ? 24 : 16,
                    top: 20,
                    bottom: 20 + bottomInset,
                  ),
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RepaintBoundary(child: _buildTopBar()),
                        const SizedBox(height: 4),
                        RepaintBoundary(child: _buildHeader()),
                        const SizedBox(height: 12),
                        const SizedBox(height: 18),
                        RepaintBoundary(child: _buildDemoTabsCard()),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _demoTabs,
                          builder: (context, _) => RepaintBoundary(
                            child: Stack(
                              children: [
                                Offstage(
                                  offstage: _demoTabs.index != 0,
                                  child: _buildActionTabsCard(),
                                ),
                                Offstage(
                                  offstage: _demoTabs.index != 1,
                                  child: FutureBuilder<String>(
                                    future: _deviceIdFuture,
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox.shrink();
                                      }
                                      return StandaloneChatDemoPage(
                                        backendUrl: _server,
                                        realtime: _newRealtime(),
                                        userId: snapshot.data!,
                                        displayName:
                                            _displayNameController.text
                                                .trim()
                                                .isEmpty
                                            ? _defaultDisplayName(
                                                snapshot.data!,
                                              )
                                            : _displayNameController.text
                                                  .trim(),
                                        embedded: true,
                                        visible: _demoTabs.index == 1,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _demoTabs,
                          builder: (context, _) {
                            if (_demoTabs.index != 0 ||
                                (_error == null && _formError == null)) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildErrorBanner(),
                            );
                          },
                        ),
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
  }

  Widget _buildTopBar() {
    final strings = DemoStrings.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildLanguageMenu(),
        const SizedBox(width: 8),
        RealtimeGlassSurface(
          radius: RealtimeUiTokens.pillRadius,
          opacity: 0.80,
          shadow: false,
          child: Tooltip(
            message: strings.serverAndIdentitySettings,
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 20,
                color: RealtimeUiTokens.text,
              ),
              onPressed: _showServerAndIdentitySheet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageMenu() {
    final strings = RealtimeStrings.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.pillRadius,
      opacity: 0.80,
      shadow: false,
      child: PopupMenuButton<Locale>(
        tooltip: strings.language,
        icon: const Icon(
          Icons.language_rounded,
          size: 20,
          color: RealtimeUiTokens.text,
        ),
        onSelected: widget.onLocaleChanged,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: const Locale('en'),
            child: Text(strings.english),
          ),
          PopupMenuItem(
            value: const Locale('zh', 'CN'),
            child: Text(strings.chinese),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoTabsCard() => RealtimeGlassSurface(
    radius: RealtimeUiTokens.cardRadius,
    padding: const EdgeInsets.all(8),
    child: Container(
      decoration: BoxDecoration(
        color: RealtimeUiTokens.surfaceSubtle.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: Border.all(color: RealtimeUiTokens.border),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _demoTabs,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        labelColor: RealtimeUiTokens.text,
        unselectedLabelColor: RealtimeUiTokens.textMuted,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            icon: const Icon(Icons.videocam_rounded, size: 18),
            text: DemoStrings.of(context).videoTab,
          ),
          Tab(
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            text: DemoStrings.of(context).chatTab,
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader() => Column(
    children: [
      RealtimeGlassSurface(
        radius: RealtimeUiTokens.controlRadius,
        padding: const EdgeInsets.all(14),
        opacity: 0.88,
        borderColor: RealtimeUiTokens.primaryBorder,
        child: const Icon(
          Icons.videocam_rounded,
          size: 30,
          color: RealtimeUiTokens.primary,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Realtime Media',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: RealtimeUiTokens.text,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        DemoStrings.of(context).appSubtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: RealtimeUiTokens.textMuted,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          RealtimePill(
            label: DemoStrings.of(context).backendMediaProvider(
              _serverMediaProviderId == null
                  ? null
                  : mediaProviderDisplayName(_serverMediaProviderId!),
              checkingNow: _testingServer,
            ),
            icon: Icons.videocam_outlined,
            foreground: _serverMediaProviderId == null
                ? RealtimeUiTokens.textMuted
                : RealtimeUiTokens.primary,
            background: _serverMediaProviderId == null
                ? RealtimeUiTokens.surfaceSubtle
                : RealtimeUiTokens.primarySubtle,
            borderColor: _serverMediaProviderId == null
                ? RealtimeUiTokens.border
                : RealtimeUiTokens.primaryBorder,
          ),
          RealtimePill(
            label: DemoStrings.of(context).backendChatProvider(
              _serverChatProviderId == null
                  ? null
                  : DemoStrings.of(
                      context,
                    ).chatProviderDisplayName(_serverChatProviderId!),
              checkingNow: _testingServer,
            ),
            icon: Icons.chat_bubble_outline_rounded,
            foreground: _serverChatProviderId == null
                ? RealtimeUiTokens.textMuted
                : RealtimeUiTokens.primary,
            background: _serverChatProviderId == null
                ? RealtimeUiTokens.surfaceSubtle
                : RealtimeUiTokens.primarySubtle,
            borderColor: _serverChatProviderId == null
                ? RealtimeUiTokens.border
                : RealtimeUiTokens.primaryBorder,
          ),
        ],
      ),
    ],
  );

  void _showServerAndIdentitySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: RealtimeGlassSurface(
                  radius: RealtimeUiTokens.sheetRadius,
                  opacity: 0.94,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: RealtimeUiTokens.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DemoStrings.of(
                                    context,
                                  ).serverAndIdentitySettings,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: RealtimeUiTokens.text,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: RealtimeUiTokens.textMuted,
                                ),
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildServerSettingsSection(setSheetState),
                          const SizedBox(height: 12),
                          _buildIdentitySettingsSection(setSheetState),
                          const SizedBox(height: 16),
                          RealtimeGlassButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(DemoStrings.of(context).done),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServerSettingsSection([StateSetter? setSheetState]) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RealtimeUiTokens.surfaceSubtle.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
      border: Border.all(color: RealtimeUiTokens.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DemoStrings.of(context).backendServiceEndpoint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RealtimeUiTokens.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RealtimePill(
              label: DemoStrings.of(
                context,
              ).backendStatus(_serverProviderInfo, checkingNow: _testingServer),
              leadingDotColor: _testingServer
                  ? RealtimeUiTokens.primary
                  : _serverOnline == true
                  ? RealtimeUiTokens.success
                  : _serverOnline == false
                  ? RealtimeUiTokens.danger
                  : const Color(0xFF94A3B8),
              foreground: _serverOnline == true
                  ? RealtimeUiTokens.success
                  : _serverOnline == false
                  ? RealtimeUiTokens.danger
                  : RealtimeUiTokens.textMuted,
              background: _serverOnline == true
                  ? RealtimeUiTokens.successSubtle
                  : _serverOnline == false
                  ? RealtimeUiTokens.dangerSubtle
                  : RealtimeUiTokens.surfaceSubtle,
              borderColor: _serverOnline == true
                  ? RealtimeUiTokens.successBorder
                  : _serverOnline == false
                  ? RealtimeUiTokens.dangerBorder
                  : RealtimeUiTokens.border,
              onTap: _testingServer
                  ? null
                  : () async {
                      await _testConnection();
                      if (setSheetState != null && mounted) {
                        setSheetState(() {});
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),
        RealtimeGlassTextField(
          controller: _serverController,
          label: DemoStrings.of(context).demoBackendUrl,
          hintText: 'http://192.168.31.8:3000',
          prefixIcon: Icons.dns_outlined,
          keyboardType: TextInputType.url,
          onChanged: (_) {
            setState(() {
              _serverOnline = null;
              _serverProviderInfo = null;
              _serverMediaProviderId = null;
              _serverChatProviderId = null;
            });
            if (setSheetState != null) {
              setSheetState(() {});
            }
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _serverPresetChip(
              DemoStrings.of(context).defaultServer,
              _defaultBackendUrl,
              setSheetState,
            ),
            _serverPresetChip(
              'localhost:3000',
              'http://localhost:3000',
              setSheetState,
            ),
            _serverPresetChip(
              'Android 10.0.2.2',
              'http://10.0.2.2:3000',
              setSheetState,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _serverPresetChip(
    String label,
    String url, [
    StateSetter? setSheetState,
  ]) {
    final selected = _server == url;
    return RealtimePill(
      label: label,
      foreground: selected
          ? RealtimeUiTokens.primary
          : RealtimeUiTokens.textMuted,
      background: selected
          ? RealtimeUiTokens.primarySubtle
          : RealtimeUiTokens.surfaceSubtle,
      borderColor: selected
          ? RealtimeUiTokens.primaryBorder
          : RealtimeUiTokens.border,
      onTap: () async {
        _serverController.text = url;
        await _testConnection();
        if (setSheetState != null && mounted) {
          setSheetState(() {});
        }
      },
    );
  }

  Widget _buildIdentitySettingsSection([
    StateSetter? setSheetState,
  ]) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: RealtimeUiTokens.surfaceSubtle.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
      border: Border.all(color: RealtimeUiTokens.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.badge_outlined,
              color: RealtimeUiTokens.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DemoStrings.of(context).demoIdentity,
                    style: const TextStyle(
                      color: RealtimeUiTokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DemoStrings.of(context).demoIdentityDescription,
                    style: const TextStyle(
                      color: RealtimeUiTokens.textMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<String>(
          future: _deviceIdFuture,
          builder: (context, snapshot) {
            final deviceId = snapshot.data ?? '…';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.controlRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 18,
                    color: RealtimeUiTokens.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DemoStrings.of(context).userId,
                          style: const TextStyle(
                            color: RealtimeUiTokens.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deviceId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RealtimeUiTokens.text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.hasData)
                    IconButton(
                      tooltip: DemoStrings.of(context).copy,
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: RealtimeUiTokens.textMuted,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: deviceId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(DemoStrings.of(context).copySuccess),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        RealtimeGlassTextField(
          controller: _displayNameController,
          label: DemoStrings.of(context).displayName,
          hintText: DemoStrings.of(context).displayNameExample,
          prefixIcon: Icons.person_outline_rounded,
          onChanged: (value) {
            unawaited(_persistDisplayName(value));
            setState(() {});
            if (setSheetState != null) {
              setSheetState(() {});
            }
          },
        ),
      ],
    ),
  );

  Widget _buildActionTabsCard() => RealtimeGlassSurface(
    radius: RealtimeUiTokens.cardRadius,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: RealtimeUiTokens.surfaceSubtle.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            border: Border.all(color: RealtimeUiTokens.border),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _roomTabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius + 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            labelColor: RealtimeUiTokens.text,
            unselectedLabelColor: RealtimeUiTokens.textMuted,
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: DemoStrings.of(context).joinRoomTab),
              Tab(text: DemoStrings.of(context).createMeeting),
              Tab(text: DemoStrings.of(context).startLive),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _roomTabs,
          builder: (context, _) {
            final tab = _roomTabs.index;
            if (tab == 0) {
              return Column(
                key: const ValueKey('join-tab-content'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _roomForm(
                    code: _joinCodeController,
                    codeLabel: DemoStrings.of(context).roomCode,
                    actionLabel: DemoStrings.of(context).joinRoom,
                    action: _joinRoom,
                    isCreate: false,
                  ),
                  const SizedBox(height: 22),
                  _buildAvailableRooms(),
                ],
              );
            }
            final live = tab == 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: live
                        ? const Color(0xFFFFF1F2).withValues(alpha: 0.8)
                        : RealtimeUiTokens.primarySubtle
                            .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.compactRadius,
                    ),
                    border: Border.all(
                      color: live
                          ? const Color(0xFFFECDD3)
                          : RealtimeUiTokens.primaryBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        live ? Icons.sensors_rounded : Icons.groups_rounded,
                        size: 20,
                        color: live
                            ? const Color(0xFFE11D48)
                            : RealtimeUiTokens.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          live
                              ? (DemoStrings.of(context).isZh
                                  ? '高清互动直播 · 悬浮弹幕流 · 实时飘心点赞 · 清屏沉浸模式'
                                  : 'Interactive livestream · Floating danmaku · Flying heart likes · Clean screen')
                              : (DemoStrings.of(context).isZh
                                  ? '多人协作会议 · 宫格与演讲者布局 · 屏幕共享 · 全员静音管理'
                                  : 'Multi-party meeting · Grid & Speaker layouts · Screen sharing · Host controls'),
                          style: TextStyle(
                            fontSize: 12,
                            color: live
                                ? const Color(0xFFE11D48)
                                : RealtimeUiTokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _roomForm(
                  code: _createCodeController,
                  codeLabel: DemoStrings.of(context).optionalRoomCode,
                  actionLabel: live
                      ? DemoStrings.of(context).startLive
                      : DemoStrings.of(context).createMeeting,
                  action: () {
                    _createRoomMode = live
                        ? MediaRoomMode.broadcast
                        : MediaRoomMode.meeting;
                    return _createRoom();
                  },
                  isCreate: true,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _roomForm({
    required TextEditingController code,
    required String codeLabel,
    required String actionLabel,
    required Future<void> Function() action,
    required bool isCreate,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RealtimeGlassTextField(
        controller: code,
        label: codeLabel,
        hintText: DemoStrings.of(context).roomCodeHelp,
        prefixIcon: Icons.tag_rounded,
        suffix: isCreate
            ? RealtimePill(
                label: DemoStrings.of(context).random,
                icon: Icons.casino_outlined,
                foreground: RealtimeUiTokens.primary,
                background: RealtimeUiTokens.primarySubtle,
                borderColor: RealtimeUiTokens.primaryBorder,
                onTap: _generateRandomCreateCode,
              )
            : RealtimePill(
                label: RealtimeStrings.of(context).paste,
                icon: Icons.content_paste_rounded,
                foreground: RealtimeUiTokens.textMuted,
                background: RealtimeUiTokens.surfaceSubtle,
                onTap: _pasteJoinCode,
              ),
      ),
      const SizedBox(height: 18),
      RealtimeGlassButton(
        onPressed: _busy ? null : action,
        isLoading: _busy,
        icon: isCreate ? Icons.add_rounded : Icons.arrow_forward_rounded,
        child: Text(actionLabel),
      ),
    ],
  );

  Widget _buildAvailableRooms() {
    final strings = DemoStrings.of(context);
    final allRooms = _availableRooms;
    final rooms = _roomFilter == null
        ? allRooms
        : allRooms.where((r) => r.roomMode == _roomFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    strings.availableRooms,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: RealtimeUiTokens.text,
                    ),
                  ),
                  if (allRooms.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: '${allRooms.length}',
                      foreground: RealtimeUiTokens.primary,
                      background: RealtimeUiTokens.primarySubtle,
                      borderColor: RealtimeUiTokens.primaryBorder,
                    ),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _roomListRequestInFlight || _busy
                  ? null
                  : () => _refreshRooms(),
              icon: _roomListRequestInFlight
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: Text(strings.refresh),
            ),
          ],
        ),
        if (allRooms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              RealtimePill(
                label: strings.isZh ? '全部' : 'All',
                foreground: _roomFilter == null
                    ? Colors.white
                    : RealtimeUiTokens.textMuted,
                background: _roomFilter == null
                    ? RealtimeUiTokens.primary
                    : RealtimeUiTokens.surfaceSubtle,
                onTap: () => setState(() => _roomFilter = null),
              ),
              const SizedBox(width: 6),
              RealtimePill(
                label: strings.meeting,
                icon: Icons.groups_rounded,
                foreground: _roomFilter == MediaRoomMode.meeting
                    ? Colors.white
                    : RealtimeUiTokens.primary,
                background: _roomFilter == MediaRoomMode.meeting
                    ? RealtimeUiTokens.primary
                    : RealtimeUiTokens.primarySubtle,
                onTap: () => setState(() => _roomFilter = MediaRoomMode.meeting),
              ),
              const SizedBox(width: 6),
              RealtimePill(
                label: strings.live,
                icon: Icons.podcasts_rounded,
                foreground: _roomFilter == MediaRoomMode.broadcast
                    ? Colors.white
                    : const Color(0xFFE11D48),
                background: _roomFilter == MediaRoomMode.broadcast
                    ? const Color(0xFFE11D48)
                    : const Color(0xFFFFF1F2),
                borderColor: const Color(0xFFFECDD3),
                onTap: () =>
                    setState(() => _roomFilter = MediaRoomMode.broadcast),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (_roomListError != null)
          Text(
            _roomListError!,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
          )
        else if (rooms.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
              border: Border.all(color: RealtimeUiTokens.border),
            ),
            child: Text(
              _roomFilter == MediaRoomMode.broadcast
                  ? strings.noActiveLiveStreams
                  : (_roomFilter == MediaRoomMode.meeting
                      ? strings.noActiveMeetings
                      : strings.noActiveRooms),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: RealtimeUiTokens.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          ...rooms.map(
            (room) => RealtimeRoomCard(
              room: room,
              onJoin: _busy ? null : () => _joinDiscoveredRoom(room),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner() => RealtimeGlassSurface(
    radius: RealtimeUiTokens.controlRadius,
    padding: const EdgeInsets.all(14),
    fillColor: RealtimeUiTokens.dangerSubtle,
    borderColor: RealtimeUiTokens.dangerBorder,
    opacity: 0.94,
    shadow: false,
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: RealtimeUiTokens.danger,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _displayError(context)!,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Color(0xFFB91C1C),
          ),
          onPressed: () => setState(() {
            _error = null;
            _formError = null;
          }),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}

/// Demo room view driven entirely by the room and capability objects returned
/// by the high-level SDK.
class MeetingRoomPage extends StatelessWidget {
  const MeetingRoomPage({
    super.key,
    required this.room,
    required this.initialMediaSettings,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialMediaSettings;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<MediaBackgroundImagePreset>>(
        future: DemoBackground.presets,
        builder: (context, snapshot) => RealtimeRoomView(
          room: room,
          config: MediaRoomViewConfig(
            showChat: true,
            initialMediaSettings: initialMediaSettings,
            backgroundImagePresets: snapshot.data ?? const [],
          ),
        ),
      );
}
