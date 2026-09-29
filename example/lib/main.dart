import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'standalone_chat_demo.dart';
import 'demo_strings.dart';

const _demoLocalePreferenceKey = 'realtime_media_demo_locale';
Locale? _initialDemoLocale;

enum _JoinFormError { backendMissing, roomCodeMissing, invalidRoomCode }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final Map<String, String> _roomOwnerCredentials = {};

  @override
  void initState() {
    super.initState();
    _demoTabs = TabController(length: 2, vsync: this);
    _roomTabs = TabController(length: 2, vsync: this);
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
      final rooms = await _newRealtimeSdk().listRooms();
      if (!mounted) return;
      setState(() {
        _availableRooms = rooms;
        _roomListError = null;
      });
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
      final report = await _newRealtimeSdk().diagnoseBackend();
      final backendCheck = report.checkById('backend');
      final online = backendCheck?.status != MediaDoctorStatus.fail;
      if (mounted && _server == url) {
        setState(() {
          _serverOnline = online;
          _serverMediaProviderId = report.activeProvider;
          _serverChatProviderId = report.activeChatProvider;
          _serverProviderInfo = online
              ? backendCheck?.status == MediaDoctorStatus.warning
                    ? 'Reachable (health unavailable)'
                    : report.activeProvider == null
                    ? 'Ready'
                    : 'Default: ${mediaProviderDisplayName(report.activeProvider!)}'
              : report.backendReachable
              ? 'Health check failed'
              : 'Unreachable';
        });
      }
    } catch (_) {
      if (mounted && _server == url) {
        setState(() {
          _serverOnline = false;
          _serverProviderInfo = 'Unreachable';
          _serverMediaProviderId = null;
          _serverChatProviderId = null;
        });
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
    final sdk = _newRealtimeSdk();
    final role = _createRoomMode == MediaRoomMode.broadcast
        ? MediaRole.host
        : MediaRole.participant;
    final canContinue = await _runPreJoin(sdk, role: role);
    if (!canContinue) return;
    final deviceId = await _deviceIdFuture;
    final displayName = await _resolveDisplayName(deviceId);
    await _run(() async {
      final room = await sdk.createRoom(
        roomCode: requestedCode.isEmpty ? null : requestedCode,
        user: MediaIdentity(
          userId: deviceId,
          displayName: displayName,
          deviceId: deviceId,
        ),
        mode: _createRoomMode,
      );
      final ownerCredential = room.media.roomOwnerCredential;
      if (ownerCredential != null) {
        _roomOwnerCredentials[room.roomCode] = ownerCredential;
      }
      await _openMeeting(room);
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
    final sdk = _newRealtimeSdk();
    final role = roomMode == MediaRoomMode.broadcast
        ? MediaRole.viewer
        : MediaRole.participant;
    final canContinue = await _runPreJoin(
      sdk,
      role: role,
      providerId: providerId,
      roomCode: code,
    );
    if (!canContinue) return;
    final deviceId = await _deviceIdFuture;
    final displayName = await _resolveDisplayName(deviceId);
    await _run(() async {
      final room = await sdk.joinRoom(
        roomCode: code,
        roomOwnerCredential: _roomOwnerCredentials[code],
        user: MediaIdentity(
          userId: deviceId,
          displayName: displayName,
          deviceId: deviceId,
        ),
      );
      final ownerCredential = room.media.roomOwnerCredential;
      if (ownerCredential != null) {
        _roomOwnerCredentials[room.roomCode] = ownerCredential;
      }
      await _openMeeting(room);
    });
  }

  RealtimeSdk _newRealtimeSdk() => RealtimeSdk.standard(
    backendUrl: _server,
    tokenProvider: _appToken.trim().isEmpty ? null : () async => _appToken,
  );

  Future<bool> _runPreJoin(
    RealtimeSdk sdk, {
    required MediaRole role,
    String? providerId,
    String? roomCode,
  }) {
    if (!mounted) return Future.value(false);
    return MediaPreJoinDialog.show(
      context,
      runCheck: () =>
          sdk.preJoin(role: role, providerId: providerId, roomCode: roomCode),
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

  Future<void> _openMeeting(RealtimeRoom realtimeRoom) async {
    if (!mounted) {
      await realtimeRoom.dispose();
      return;
    }

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => MeetingRoomPage(room: realtimeRoom)),
      );
    } finally {
      await realtimeRoom.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: RealtimeAmbientBackground(
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
                      _buildTopBar(),
                      const SizedBox(height: 4),
                      _buildHeader(),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _demoTabs,
                        builder: (context, _) => _buildStatusCapsule(),
                      ),
                      const SizedBox(height: 18),
                      _buildDemoTabsCard(),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _demoTabs,
                        builder: (context, _) => Stack(
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
                                    sdk: _newRealtimeSdk(),
                                    userId: snapshot.data!,
                                    displayName:
                                        _displayNameController.text
                                            .trim()
                                            .isEmpty
                                        ? _defaultDisplayName(snapshot.data!)
                                        : _displayNameController.text.trim(),
                                    embedded: true,
                                    visible: _demoTabs.index == 1,
                                  );
                                },
                              ),
                            ),
                          ],
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

  Widget _buildStatusCapsule() {
    final strings = DemoStrings.of(context);
    final providersSummary = strings.providerSummary(
      chatTab: _demoTabs.index == 1,
      mediaProvider: _serverMediaProviderId == null
          ? null
          : mediaProviderDisplayName(_serverMediaProviderId!),
      chatProvider: _serverChatProviderId == null
          ? null
          : strings.chatProviderDisplayName(_serverChatProviderId!),
    );
    final statusText = _server.isEmpty
        ? strings.unconfigured
        : _testingServer
        ? strings.checking
        : _serverOnline == true &&
              _serverProviderInfo != 'Reachable (health unavailable)' &&
              providersSummary.isNotEmpty
        ? providersSummary
        : strings.backendStatus(_serverProviderInfo, checkingNow: false);
    final isOnline = _serverOnline == true;
    final isOffline = _serverOnline == false;
    final statusColor = _testingServer
        ? RealtimeUiTokens.primary
        : isOnline
        ? RealtimeUiTokens.success
        : isOffline
        ? RealtimeUiTokens.danger
        : const Color(0xFF94A3B8);

    final displayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : '...';

    return Center(
      child: RealtimeGlassPressable(
        onTap: _showServerAndIdentitySheet,
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.pillRadius,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          opacity: 0.88,
          borderColor: isOffline
              ? RealtimeUiTokens.dangerBorder
              : RealtimeUiTokens.border,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isOffline
                        ? RealtimeUiTokens.danger
                        : RealtimeUiTokens.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 12,
                color: RealtimeUiTokens.borderStrong,
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: RealtimeUiTokens.textMuted,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: RealtimeUiTokens.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.tune_rounded,
                size: 14,
                color: RealtimeUiTokens.textMuted,
              ),
            ],
          ),
        ),
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
              child: RealtimeGlassSurface(
                radius: RealtimeUiTokens.sheetRadius,
                opacity: 0.94,
                blur: RealtimeUiTokens.blur,
                padding: EdgeInsets.fromLTRB(18, 14, 18, bottomInset + 16),
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
                              onPressed: () => Navigator.of(sheetContext).pop(),
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
              Tab(text: DemoStrings.of(context).createRoomTab),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _roomTabs,
          builder: (context, _) {
            final isJoin = _roomTabs.index == 0;
            return AnimatedSize(
              duration: RealtimeUiTokens.animNormal,
              curve: Curves.easeOutCubic,
              child: isJoin
                  ? Column(
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
                    )
                  : _roomForm(
                      code: _createCodeController,
                      codeLabel: DemoStrings.of(context).optionalRoomCode,
                      actionLabel: DemoStrings.of(context).createAndJoin,
                      action: _createRoom,
                      isCreate: true,
                    ),
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
      if (isCreate) ...[
        const SizedBox(height: 14),
        Text(
          DemoStrings.of(context).roomType,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: RealtimeUiTokens.text,
          ),
        ),
        const SizedBox(height: 8),
        RealtimeModeSelector(
          selectedMode: _createRoomMode,
          onChanged: _busy
              ? null
              : (mode) => setState(() => _createRoomMode = mode),
        ),
      ],
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
    final rooms = _availableRooms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    DemoStrings.of(context).availableRooms,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: RealtimeUiTokens.text,
                    ),
                  ),
                  if (rooms.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: '${rooms.length}',
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
              label: Text(DemoStrings.of(context).refresh),
            ),
          ],
        ),
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
              DemoStrings.of(context).noActiveRooms,
              textAlign: TextAlign.center,
              style: TextStyle(
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
  const MeetingRoomPage({super.key, required this.room});

  final RealtimeRoom room;

  @override
  Widget build(BuildContext context) => RealtimeRoomView(
    room: room,
    config: const MediaRoomViewConfig(showChat: true),
    header: _RoomCapabilitiesSummary(room: room),
  );
}

class _RoomCapabilitiesSummary extends StatelessWidget {
  const _RoomCapabilitiesSummary({required this.room});

  final RealtimeRoom room;

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final capabilities = room.capabilities;
    final media = capabilities.media;
    final chat = capabilities.chat;
    final labels = <(String, bool)>[
      (isZh ? '发布音频' : 'Publish audio', media.canPublishAudio),
      (isZh ? '发布视频' : 'Publish video', media.canPublishVideo),
      (isZh ? '切换摄像头' : 'Switch camera', media.canSwitchCamera),
      (isZh ? '屏幕共享' : 'Screen share', media.canScreenShare),
      (isZh ? '接收视频' : 'Receive video', media.canSubscribeVideo),
      (isZh ? '发送房间数据' : 'Send room data', media.canSendData),
      (isZh ? '房间聊天' : 'Room chat', capabilities.canChat),
      if (room.usesProductChat && chat != null) ...[
        (isZh ? '产品 Chat' : 'Product Chat', chat.canSendMessage),
        (isZh ? '加载历史' : 'Load history', chat.canLoadHistory),
        (isZh ? '删除消息' : 'Delete messages', chat.canDeleteMessage),
        (isZh ? '移除成员' : 'Remove members', chat.canDisconnectUser),
      ],
      if (room.usesRtcDataChat)
        (
          isZh ? 'RTC Data Chat' : 'RTC Data Chat',
          chat?.canSendMessage == true,
        ),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        dense: true,
        title: Text(isZh ? '当前房间能力' : 'Current room capabilities'),
        subtitle: Text(
          isZh
              ? '音频 ${_yesNo(isZh, media.canPublishAudio)} · 视频 ${_yesNo(isZh, media.canPublishVideo)} · 聊天 ${_yesNo(isZh, capabilities.canChat)}'
              : 'Audio ${_yesNo(isZh, media.canPublishAudio)} · Video ${_yesNo(isZh, media.canPublishVideo)} · Chat ${_yesNo(isZh, capabilities.canChat)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, supported) in labels)
                Chip(
                  avatar: Icon(
                    supported ? Icons.check_circle_outline : Icons.block,
                    size: 17,
                    color: supported
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _yesNo(bool isZh, bool value) =>
      isZh ? (value ? '支持' : '不支持') : (value ? 'yes' : 'no');
}
