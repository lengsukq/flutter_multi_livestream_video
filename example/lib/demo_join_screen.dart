import 'demo_server_settings_panel.dart';
import 'demo_identity_settings_panel.dart';
import 'demo_join_coordinator.dart';
import 'demo_realtime_configuration.dart';
import 'demo_meeting_room_page.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_background.dart';
import 'demo_composable_pre_join_page.dart';
import 'demo_backend_diagnostics.dart';
import 'demo_available_rooms.dart';
import 'demo_room_directory.dart';
import 'demo_home_hero.dart';
import 'demo_identity_store.dart';
import 'demo_strings.dart';
import 'standalone_chat_demo.dart';

const String _defaultBackendUrl = String.fromEnvironment(
  'MEDIA_BACKEND_URL',
  defaultValue: 'http://192.168.31.8:3000',
);
const String _appToken = String.fromEnvironment('MEDIA_APP_TOKEN');

/// Optional test seam; Demo registers its desired providers explicitly.
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

  DemoEntryPhase _entryPhase = DemoEntryPhase.idle;
  bool get _busy => _entryPhase != DemoEntryPhase.idle;
  String? _error;
  DemoJoinFormError? _formError;
  MediaRoomMode _createRoomMode = MediaRoomMode.meeting;
  MediaRoomMode _joinRoomMode = MediaRoomMode.meeting;

  // Backend connection status: null = untested, true = online, false = offline
  bool? get _serverOnline => _diagnostics.online;
  String? get _serverMediaProviderId => _diagnostics.mediaProviderId;
  String? get _serverChatProviderId => _diagnostics.chatProviderId;
  bool get _testingServer => _diagnostics.testing;
  Timer? _serverStatusTimer;
  List<MediaRoomSummary> get _availableRooms => _roomDirectory.rooms;
  String? get _roomListError => _roomDirectory.error;
  late final _entryCoordinator = DemoJoinCoordinator(_identityStore);

  @override
  void initState() {
    super.initState();
    _diagnostics.addListener(_notifyBackendChanged);
    _roomDirectory.addListener(_notifyBackendChanged);
    _demoTabs = TabController(length: 2, vsync: this);
    _roomTabs = TabController(length: 3, vsync: this);
    _deviceIdFuture = _entryCoordinator.deviceId;
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

  void _showFormError(DemoJoinFormError error) {
    setState(() {
      _formError = error;
      _error = null;
    });
  }

  String? _displayError(BuildContext context) {
    final strings = DemoStrings.of(context);
    return switch (_formError) {
      DemoJoinFormError.backendMissing => strings.enterBackendUrl,
      DemoJoinFormError.roomCodeMissing => strings.enterRoomCode,
      DemoJoinFormError.invalidRoomCode => strings.invalidRoomCode,
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

  Future<void> _createRoom() => _prepareEntry(
    DemoRoomEntryKind.create,
    _createRoomMode,
    _createCodeController.text,
  );
  Future<void> _joinRoom({String? providerId, MediaRoomMode? roomMode}) =>
      _prepareEntry(
        DemoRoomEntryKind.join,
        roomMode ??
            _availableRooms
                .where((r) => r.roomCode == _joinCodeController.text.trim())
                .firstOrNull
                ?.roomMode ??
            _joinRoomMode,
        _joinCodeController.text,
        providerId: providerId,
      );

  Future<void> _prepareEntry(
    DemoRoomEntryKind kind,
    MediaRoomMode mode,
    String code, {
    String? providerId,
  }) async {
    if (_busy) return;
    setState(() => _entryPhase = DemoEntryPhase.preparing);
    try {
      final result = await _entryCoordinator.prepare(
        kind: kind,
        backendUrl: _server,
        code: code,
        displayName: _displayNameController.text,
        mode: mode,
        createRealtime: (url) =>
            widget.realtimeFactory?.call(url) ??
            createDemoRealtime(url, appToken: _appToken),
      );
      if (!mounted) return;
      switch (result) {
        case DemoJoinRejected(:final reason):
          _showFormError(reason);
        case DemoJoinFailed(:final error):
          setState(() => _error = error.message);
        case DemoJoinPrepared(:final entry):
          _displayNameController.text = entry.user.name;
          await _runPreJoin(
            entry.realtime,
            role: entry.role,
            providerId: providerId,
            roomCode: kind == DemoRoomEntryKind.join ? entry.roomCode : null,
            displayName: entry.user.name,
            roomLabel: entry.roomCode ?? DemoStrings.of(context).createAndJoin,
            onEnter: (preJoinContext, settings) async {
              final connection = await entry.connect();
              await _openMeeting(
                preJoinContext,
                connection,
                initialMediaSettings: settings,
                roomMode: entry.mode,
              );
            },
          );
      }
    } finally {
      if (mounted) setState(() => _entryPhase = DemoEntryPhase.idle);
    }
  }

  Realtime _newRealtime() =>
      widget.realtimeFactory?.call(_server) ??
      createDemoRealtime(_server, appToken: _appToken);

  Future<void> _runPreJoin(
    Realtime realtime, {
    required MediaRole role,
    required String displayName,
    required String roomLabel,
    required MediaPreJoinEnter onEnter,
    String? providerId,
    String? roomCode,
  }) async {
    if (_entryPhase == DemoEntryPhase.preJoin) return;
    setState(() => _entryPhase = DemoEntryPhase.preJoin);
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
      if (mounted) setState(() => _entryPhase = DemoEntryPhase.idle);
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
    final strings = DemoStrings.of(context);
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.pillRadius,
      opacity: 0.80,
      shadow: false,
      child: PopupMenuButton<ThemeMode>(
        tooltip: strings.appearanceTheme,
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
                Text(strings.themeLight, style: TextStyle(color: style.text)),
              ],
            ),
          ),
          PopupMenuItem(
            value: ThemeMode.dark,
            child: Row(
              children: [
                Icon(Icons.dark_mode_rounded, size: 18, color: style.text),
                const SizedBox(width: 8),
                Text(strings.themeDark, style: TextStyle(color: style.text)),
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
                Text(strings.themeSystem, style: TextStyle(color: style.text)),
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
    unawaited(
      showRealtimeGlassBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, _) {
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
                        _buildServerSettingsSection(),
                        const SizedBox(height: 12),
                        _buildIdentitySettingsSection(),
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
      ),
    );
  }

  Widget _buildServerSettingsSection() => DemoServerSettingsPanel(
    controller: _serverController, diagnostics: _diagnostics,
    defaultBackendUrl: _defaultBackendUrl, onTest: _testConnection);
  Widget _buildIdentitySettingsSection() => DemoIdentitySettingsPanel(
    deviceId: _deviceIdFuture, displayNameController: _displayNameController,
    onNameChanged: (value) { unawaited(_persistDisplayName(value)); setState(() {}); });

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
                              label: DemoStrings.of(
                                context,
                              ).joinMeetingParticipant,
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
                              label: DemoStrings.of(context).watchLiveViewer,
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
                                ? DemoStrings.of(context).liveBannerDescription
                                : DemoStrings.of(
                                    context,
                                  ).meetingBannerDescription,
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
