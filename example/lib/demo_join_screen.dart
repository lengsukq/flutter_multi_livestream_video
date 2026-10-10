import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'demo_background.dart';
import 'demo_composable_meeting_page.dart';
import 'demo_composable_live_page.dart';
import 'demo_composable_pre_join_page.dart';
import 'demo_backend_diagnostics.dart';
import 'demo_available_rooms.dart';
import 'demo_room_directory.dart';
import 'demo_home_hero.dart';
import 'demo_identity_store.dart';
import 'demo_room_flow.dart';
import 'demo_strings.dart';
import 'standalone_chat_demo.dart';

enum _JoinFormError { backendMissing, roomCodeMissing, invalidRoomCode }

const String _defaultBackendUrl = String.fromEnvironment(
  'MEDIA_BACKEND_URL',
  defaultValue: 'http://192.168.31.8:3000',
);
const String _appToken = String.fromEnvironment('MEDIA_APP_TOKEN');

/// Optional test seam; production uses the full SDK with its built-in drivers.
typedef DemoRealtimeFactory = Realtime Function(String backendUrl);
typedef DemoRoomPageFactory =
    Widget Function(
      RealtimeConnection connection,
      MediaLocalPreviewSettings settings,
      MediaRoomMode? mode,
    );

/// Adaptive and clean Join Screen directly reusing SDK built-in glass UI.
class JoinScreen extends StatefulWidget {
  const JoinScreen({
    super.key,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.realtimeFactory,
    this.roomPageFactory,
    this.backgroundPresets,
    this.initialBackendUrl,
    this.permissionRequester,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final DemoRealtimeFactory? realtimeFactory;
  final DemoRoomPageFactory? roomPageFactory;
  final Future<List<MediaBackgroundImagePreset>> Function()? backgroundPresets;
  final String? initialBackendUrl;
  final MediaPermissionRequester? permissionRequester;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with TickerProviderStateMixin {
  final _identityStore = DemoIdentityStore();
  final _diagnostics = DemoBackendDiagnostics();
  final _roomDirectory = DemoRoomDirectory();

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
  MediaRoomMode _joinRoomMode = MediaRoomMode.meeting;

  // Backend connection status: null = untested, true = online, false = offline
  bool? get _serverOnline => _diagnostics.online;
  String? get _serverProviderInfo => _diagnostics.providerInfo;
  String? get _serverMediaProviderId => _diagnostics.mediaProviderId;
  String? get _serverChatProviderId => _diagnostics.chatProviderId;
  bool get _testingServer => _diagnostics.testing;
  Timer? _serverStatusTimer;
  List<MediaRoomSummary> get _availableRooms => _roomDirectory.rooms;
  String? get _roomListError => _roomDirectory.error;
  final Map<String, String> _roomOwnerCredentials = {};

  @override
  void initState() {
    super.initState();
    _diagnostics.addListener(_notifyBackendChanged);
    _roomDirectory.addListener(_notifyBackendChanged);
    _demoTabs = TabController(length: 2, vsync: this);
    _roomTabs = TabController(length: 3, vsync: this);
    _deviceIdFuture = _identityStore.loadDeviceId();
    unawaited(_loadDisplayName());
    _serverController.text = widget.initialBackendUrl ?? _defaultBackendUrl;
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
    _joinRoomMode = room.roomMode ?? MediaRoomMode.meeting;
    await _joinRoom(
      providerId: room.engineId ?? room.providerId,
      roomMode: room.roomMode,
    );
  }

  Future<void> _refreshRooms({bool silent = false}) => _roomDirectory.refresh(
    url: _server,
    currentUrl: () => _server,
    listRooms: () => _newRealtime().listRooms(),
    displayError: (error) =>
        DemoStrings.of(context).displayRealtimeError(error),
    silent: silent,
  );

  @override
  void dispose() {
    _diagnostics.removeListener(_notifyBackendChanged);
    _diagnostics.dispose();
    _roomDirectory.removeListener(_notifyBackendChanged);
    _roomDirectory.dispose();
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
  void _notifyBackendChanged() {
    if (mounted) setState(() {});
  }

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
    final id = await _deviceIdFuture;
    final name = await _identityStore.loadDisplayName(id);
    if (!mounted) return;
    _displayNameController.text = name;
    setState(() {});
  }

  Future<String> _resolveDisplayName(String deviceId) async {
    var value = _displayNameController.text.trim();
    if (value.isEmpty) {
      value = _identityStore.defaultDisplayName(deviceId);
      _displayNameController.text = value;
    }
    await _identityStore.saveDisplayName(value);
    return value;
  }

  Future<void> _persistDisplayName(String value) =>
      _identityStore.saveDisplayName(value);

  Future<void> _testConnection({bool silent = false}) => _diagnostics.refresh(
    url: _server,
    currentUrl: () => _server,
    diagnose: () => _newRealtime().diagnoseBackend(),
    silent: silent,
  );

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
    final flow = DemoRoomFlow(
      open: realtime.open,
      ownerCredentials: _roomOwnerCredentials,
    );
    final mode = _createRoomMode;
    final role = mode == MediaRoomMode.broadcast
        ? MediaRole.host
        : MediaRole.participant;
    final deviceId = await _deviceIdFuture;
    final displayName = await _resolveDisplayName(deviceId);
    await _runPreJoin(
      realtime,
      role: role,
      displayName: displayName,
      roomLabel: roomLabel,
      onEnter: (preJoinContext, settings) async {
        final connection = await flow.create(
          mode: mode,
          deviceId: deviceId,
          displayName: displayName,
          roomCode: requestedCode.isEmpty ? null : requestedCode,
        );
        if (!preJoinContext.mounted) {
          await connection.dispose();
          return;
        }
        await _openMeeting(
          preJoinContext,
          connection,
          initialMediaSettings: settings,
          roomMode: mode,
        );
      },
    );
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
    final flow = DemoRoomFlow(
      open: realtime.open,
      ownerCredentials: _roomOwnerCredentials,
    );
    final targetMode =
        roomMode ??
        _availableRooms
            .where((r) => r.roomCode == code)
            .firstOrNull
            ?.roomMode ??
        _joinRoomMode;
    final role = targetMode == MediaRoomMode.broadcast
        ? MediaRole.viewer
        : MediaRole.participant;
    final deviceId = await _deviceIdFuture;
    final displayName = await _resolveDisplayName(deviceId);
    await _runPreJoin(
      realtime,
      role: role,
      providerId: providerId,
      roomCode: code,
      displayName: displayName,
      roomLabel: code,
      onEnter: (preJoinContext, settings) async {
        final connection = await flow.join(
          code: code,
          mode: targetMode,
          deviceId: deviceId,
          displayName: displayName,
        );
        if (!preJoinContext.mounted) {
          await connection.dispose();
          return;
        }
        await _openMeeting(
          preJoinContext,
          connection,
          initialMediaSettings: settings,
          roomMode: targetMode,
        );
      },
    );
  }

  Realtime _newRealtime() =>
      widget.realtimeFactory?.call(_server) ??
      Realtime.standard(
        backendUrl: _server,
        tokenProvider: _appToken.trim().isEmpty ? null : () async => _appToken,
      );

  Future<void> _runPreJoin(
    Realtime realtime, {
    required MediaRole role,
    required String displayName,
    required String roomLabel,
    required MediaPreJoinEnter onEnter,
    String? providerId,
    String? roomCode,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final backgroundPresets =
          await (widget.backgroundPresets?.call() ?? DemoBackground.presets);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DemoComposablePreJoinPage(
            permissionRequester:
                widget.permissionRequester ??
                const DefaultMediaPermissionProbe(),
            onEnter: onEnter,
            runCheck: () => realtime.preJoin(
              role: role,
              providerId: providerId,
              roomCode: roomCode,
            ),
            openPreview: (id, previewRole) =>
                realtime.createLocalPreview(providerId: id, role: previewRole),
            displayName: displayName,
            roomLabel: roomLabel,
            imagePresets: backgroundPresets,
            title: role == MediaRole.viewer
                ? DemoStrings.of(context).live
                : role == MediaRole.host
                ? DemoStrings.of(context).startLive
                : DemoStrings.of(context).meeting,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMeeting(
    BuildContext preJoinContext,
    RealtimeConnection connection, {
    required MediaLocalPreviewSettings initialMediaSettings,
    MediaRoomMode? roomMode,
  }) async {
    if (!preJoinContext.mounted) {
      await connection.dispose();
      return;
    }

    try {
      final destination =
          widget.roomPageFactory?.call(
            connection,
            initialMediaSettings,
            roomMode,
          ) ??
          MeetingRoomPage(
            room: connection.mediaRoom!,
            initialMediaSettings: initialMediaSettings,
            roomMode: roomMode,
          );
      await Navigator.of(preJoinContext).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => destination),
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
              final desktop = constraints.maxWidth >= 980;
              final compact = constraints.maxWidth < 600;
              final horizontalPadding = constraints.maxWidth < 400
                  ? 12.0
                  : 24.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  desktop ? 28 : 12,
                  horizontalPadding,
                  24 + bottomInset,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(),
                        SizedBox(
                          height: desktop
                              ? 36
                              : compact
                              ? 10
                              : 18,
                        ),
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _homeHero(compact: false),
                              ),
                              const SizedBox(width: 28),
                              Expanded(flex: 6, child: _buildHomeActions()),
                            ],
                          )
                        else
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (compact)
                                    _homeHero(compact: true)
                                  else
                                    _homeHero(compact: false),
                                  SizedBox(height: compact ? 12 : 20),
                                  _buildHomeActions(),
                                ],
                              ),
                            ),
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

  Widget _buildHomeActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildDemoTabsCard(),
      const SizedBox(height: 12),
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
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return StandaloneChatDemoPage(
                    backendUrl: _server,
                    realtime: _newRealtime(),
                    userId: snapshot.data!,
                    displayName: _displayNameController.text.trim().isEmpty
                        ? _identityStore.defaultDisplayName(snapshot.data!)
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
        builder: (context, _) =>
            _demoTabs.index != 0 || (_error == null && _formError == null)
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _buildErrorBanner(),
              ),
      ),
    ],
  );

  Widget _buildTopBar() {
    final strings = DemoStrings.of(context);
    final style = RealtimeStyle.of(context);
    return Row(
      children: [
        Icon(Icons.hub_rounded, color: style.primary, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'REALTIME / DEMO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.4,
              color: style.textMuted,
            ),
          ),
        ),
        _buildThemeMenu(),
        const SizedBox(width: 8),
        _buildLanguageMenu(),
        const SizedBox(width: 8),
        RealtimeGlassSurface(
          radius: RealtimeUiTokens.pillRadius,
          opacity: 0.80,
          shadow: false,
          child: Tooltip(
            message: strings.serverAndIdentitySettings,
            child: IconButton(
              icon: Icon(Icons.settings_outlined, size: 20, color: style.text),
              onPressed: _showServerAndIdentitySheet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeMenu() {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.pillRadius,
      opacity: 0.80,
      shadow: false,
      child: PopupMenuButton<ThemeMode>(
        tooltip: strings.isZh ? '外观主题' : 'Appearance theme',
        color: style.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          side: BorderSide(color: style.border),
        ),
        icon: Icon(
          switch (widget.themeMode) {
            ThemeMode.light => Icons.light_mode_rounded,
            ThemeMode.dark => Icons.dark_mode_rounded,
            ThemeMode.system => Icons.brightness_auto_rounded,
          },
          size: 20,
          color: style.text,
        ),
        onSelected: widget.onThemeModeChanged,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: ThemeMode.light,
            child: Row(
              children: [
                Icon(Icons.light_mode_rounded, size: 18, color: style.text),
                const SizedBox(width: 8),
                Text(
                  strings.isZh ? '简白浅色 (默认)' : 'Light (Default)',
                  style: TextStyle(color: style.text),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.dark,
            child: Row(
              children: [
                Icon(Icons.dark_mode_rounded, size: 18, color: style.text),
                const SizedBox(width: 8),
                Text(
                  strings.isZh ? '质感深色' : 'Dark',
                  style: TextStyle(color: style.text),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.system,
            child: Row(
              children: [
                Icon(
                  Icons.brightness_auto_rounded,
                  size: 18,
                  color: style.text,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.isZh ? '跟随系统' : 'System',
                  style: TextStyle(color: style.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageMenu() {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.pillRadius,
      opacity: 0.80,
      shadow: false,
      child: PopupMenuButton<Locale>(
        tooltip: strings.language,
        color: style.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          side: BorderSide(color: style.border),
        ),
        icon: Icon(Icons.language_rounded, size: 20, color: style.text),
        onSelected: widget.onLocaleChanged,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: const Locale('en'),
            child: Text(strings.english, style: TextStyle(color: style.text)),
          ),
          PopupMenuItem(
            value: const Locale('zh', 'CN'),
            child: Text(strings.chinese, style: TextStyle(color: style.text)),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoTabsCard() => AnimatedBuilder(
    animation: _demoTabs,
    builder: (context, _) => RealtimeSegmentedTabs<int>(
      height: 48,
      selectedValue: _demoTabs.index,
      onChanged: (val) {
        _demoTabs.animateTo(val);
        setState(() {});
      },
      tabs: [
        RealtimeSegmentTab(
          value: 0,
          icon: Icons.videocam_rounded,
          label: DemoStrings.of(context).videoTab,
        ),
        RealtimeSegmentTab(
          value: 1,
          icon: Icons.chat_bubble_outline_rounded,
          label: DemoStrings.of(context).chatTab,
        ),
      ],
    ),
  );

  Widget _homeHero({required bool compact}) => DemoHomeHero(
    compact: compact,
    mediaProviderId: _serverMediaProviderId,
    chatProviderId: _serverChatProviderId,
    online: _serverOnline,
    testingServer: _testingServer,
  );

  void _showServerAndIdentitySheet() {
    showRealtimeGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final style = RealtimeStyle.of(sheetContext);
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 6, 18, 16 + bottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: style.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DemoStrings.of(
                                sheetContext,
                              ).serverAndIdentitySettings,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: style.text,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: style.textMuted,
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
                        child: Text(DemoStrings.of(sheetContext).done),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServerSettingsSection([StateSetter? setSheetState]) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(16),
      shadow: false,
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RealtimePill(
                label: DemoStrings.of(context).backendStatus(
                  _serverProviderInfo,
                  checkingNow: _testingServer,
                ),
                leadingDotColor: _testingServer
                    ? style.primary
                    : _serverOnline == true
                    ? style.success
                    : _serverOnline == false
                    ? style.danger
                    : const Color(0xFF94A3B8),
                foreground: _serverOnline == true
                    ? style.success
                    : _serverOnline == false
                    ? style.danger
                    : style.textMuted,
                background: _serverOnline == true
                    ? style.successSubtle
                    : _serverOnline == false
                    ? style.dangerSubtle
                    : style.surfaceSubtle,
                borderColor: _serverOnline == true
                    ? (style.isDark
                          ? style.success
                          : RealtimeUiTokens.successBorder)
                    : _serverOnline == false
                    ? (style.isDark
                          ? style.danger
                          : RealtimeUiTokens.dangerBorder)
                    : style.border,
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
              _diagnostics.clear();
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
  }

  Widget _serverPresetChip(
    String label,
    String url, [
    StateSetter? setSheetState,
  ]) {
    final style = RealtimeStyle.of(context);
    final selected = _server == url;
    return RealtimePill(
      label: label,
      foreground: selected ? Colors.white : style.textMuted,
      background: selected ? style.primary : style.surfaceSubtle,
      borderColor: selected ? style.primary : style.border,
      onTap: () async {
        _serverController.text = url;
        await _testConnection();
        if (setSheetState != null && mounted) {
          setSheetState(() {});
        }
      },
    );
  }

  Widget _buildIdentitySettingsSection([StateSetter? setSheetState]) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(16),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.badge_outlined, color: style.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DemoStrings.of(context).demoIdentity,
                      style: TextStyle(
                        color: style.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DemoStrings.of(context).demoIdentityDescription,
                      style: TextStyle(
                        color: style.textMuted,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: style.surface,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                  border: Border.all(color: style.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 18,
                      color: style.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DemoStrings.of(context).userId,
                            style: TextStyle(
                              color: style.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.text,
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
                        icon: Icon(Icons.copy_rounded, color: style.textMuted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: deviceId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                DemoStrings.of(context).copySuccess,
                              ),
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
  }

  Widget _buildActionTabsCard() {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _roomTabs,
            builder: (context, _) => RealtimeSegmentedTabs<int>(
              height: 44,
              selectedValue: _roomTabs.index,
              onChanged: (val) {
                _roomTabs.animateTo(val);
                setState(() {});
              },
              tabs: [
                RealtimeSegmentTab(
                  value: 0,
                  label: DemoStrings.of(context).joinRoomTab,
                ),
                RealtimeSegmentTab(
                  value: 1,
                  label: DemoStrings.of(context).createMeeting,
                ),
                RealtimeSegmentTab(
                  value: 2,
                  label: DemoStrings.of(context).startLive,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _roomTabs,
            builder: (context, _) {
              final tab = _roomTabs.index;
              if (tab == 0) {
                final isLiveMode = _joinRoomMode == MediaRoomMode.broadcast;
                return Column(
                  key: const ValueKey('join-tab-content'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: RealtimePill(
                              label: DemoStrings.of(context).isZh
                                  ? '加入会议 (参会者)'
                                  : 'Join Meeting',
                              icon: Icons.groups_rounded,
                              foreground: !isLiveMode
                                  ? Colors.white
                                  : style.textMuted,
                              background: !isLiveMode
                                  ? style.primary
                                  : style.surfaceSubtle,
                              borderColor: !isLiveMode
                                  ? style.primary
                                  : style.border,
                              onTap: () => setState(
                                () => _joinRoomMode = MediaRoomMode.meeting,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RealtimePill(
                              label: DemoStrings.of(context).isZh
                                  ? '观看直播 (观众)'
                                  : 'Watch Live',
                              icon: Icons.podcasts_rounded,
                              foreground: isLiveMode
                                  ? Colors.white
                                  : (style.isDark
                                        ? const Color(0xFFFB7185)
                                        : const Color(0xFFE11D48)),
                              background: isLiveMode
                                  ? const Color(0xFFE11D48)
                                  : (style.isDark
                                        ? const Color(0xFF3B1219)
                                        : const Color(0xFFFFF1F2)),
                              borderColor: isLiveMode
                                  ? const Color(0xFFE11D48)
                                  : (style.isDark
                                        ? const Color(0xFF7F1D1D)
                                        : const Color(0xFFFECDD3)),
                              onTap: () => setState(
                                () => _joinRoomMode = MediaRoomMode.broadcast,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                          ? (style.isDark
                                ? const Color(0xFF3B1219)
                                : const Color(
                                    0xFFFFF1F2,
                                  ).withValues(alpha: 0.8))
                          : style.primarySubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      border: Border.all(
                        color: live
                            ? (style.isDark
                                  ? const Color(0xFF7F1D1D)
                                  : const Color(0xFFFECDD3))
                            : style.primaryBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          live ? Icons.sensors_rounded : Icons.groups_rounded,
                          size: 20,
                          color: live
                              ? (style.isDark
                                    ? const Color(0xFFFB7185)
                                    : const Color(0xFFE11D48))
                              : style.primary,
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
                                  ? (style.isDark
                                        ? const Color(0xFFFB7185)
                                        : const Color(0xFFE11D48))
                                  : style.primary,
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
  }

  Widget _roomForm({
    required TextEditingController code,
    required String codeLabel,
    required String actionLabel,
    required Future<void> Function() action,
    required bool isCreate,
  }) {
    final style = RealtimeStyle.of(context);
    return Column(
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
                  foreground: style.primary,
                  background: style.primarySubtle,
                  borderColor: style.primaryBorder,
                  onTap: _generateRandomCreateCode,
                )
              : RealtimePill(
                  label: RealtimeStrings.of(context).paste,
                  icon: Icons.content_paste_rounded,
                  foreground: style.primary,
                  background: style.primarySubtle,
                  borderColor: style.primaryBorder,
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
  }

  Widget _buildAvailableRooms() => DemoAvailableRooms(
    rooms: _availableRooms,
    error: _roomListError,
    loading: _roomDirectory.loading,
    busy: _busy,
    onRefresh: () => unawaited(_refreshRooms()),
    onJoin: (room) => unawaited(_joinDiscoveredRoom(room)),
  );

  Widget _buildErrorBanner() {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.controlRadius,
      padding: const EdgeInsets.all(14),
      fillColor: style.dangerSubtle,
      borderColor: style.isDark
          ? const Color(0xFF7F1D1D)
          : const Color(0xFFFECDD3),
      opacity: 0.94,
      shadow: false,
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: style.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _displayError(context)!,
              style: TextStyle(
                color: style.isDark
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: style.isDark
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFB91C1C),
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
}

/// Demo room view driven entirely by the room and capability objects returned
/// by the high-level SDK.
class MeetingRoomPage extends StatelessWidget {
  const MeetingRoomPage({
    super.key,
    required this.room,
    required this.initialMediaSettings,
    this.roomMode,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialMediaSettings;
  final MediaRoomMode? roomMode;

  @override
  Widget build(BuildContext context) {
    // Both Meeting and Live layouts are now owned by the Demo. The default
    // RealtimeRoomView remains available for quick SDK integration.
    if (roomMode == MediaRoomMode.broadcast ||
        room.media.role == MediaRole.viewer) {
      return DemoComposableLivePage(
        room: room,
        initialSettings: initialMediaSettings,
      );
    }
    return DemoComposableMeetingPage(
      room: room,
      initialSettings: initialMediaSettings,
    );
  }
}
