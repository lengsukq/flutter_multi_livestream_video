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
    this.realtimeFactory,
    this.roomPageFactory,
    this.backgroundPresets,
    this.initialBackendUrl,
    this.permissionRequester,
  });

  final ValueChanged<Locale> onLocaleChanged;
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
  late final Future<String> _deviceIdFuture;
  final _serverController = TextEditingController();
  final _createCodeController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();

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
    _demoTabs = TabController(length: 3, vsync: this);
    _deviceIdFuture = _entryCoordinator.deviceId;
    unawaited(_loadDisplayName());
    _serverController.text = widget.initialBackendUrl ?? _defaultBackendUrl;
    unawaited(_testConnection());
    unawaited(_refreshRooms(silent: true));
    _serverStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_testConnection(silent: true));
      if (_demoTabs.index == 0 && !_busy) {
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
    _serverController.dispose();
    _createCodeController.dispose();
    _joinCodeController.dispose();
    _displayNameController.dispose();
    _avatarUrlController.dispose();
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
    final avatarUrl = await _identityStore.loadAvatarUrl();
    if (!mounted) return;
    _displayNameController.text = name;
    _avatarUrlController.text = avatarUrl;
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
        avatarUrl: _avatarUrlController.text,
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
            avatarUrl: entry.user.avatarUrl,
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
    String? avatarUrl,
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
            avatarUrl: avatarUrl,
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

  void _selectDestination(int index) {
    _demoTabs.index = index;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = DemoStrings.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return RealtimeWorkspaceShell(
      selectedIndex: _demoTabs.index,
      onDestinationSelected: _selectDestination,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: strings.home,
        ),
        NavigationDestination(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: const Icon(Icons.chat_bubble_rounded),
          label: strings.chatTab,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: strings.settings,
        ),
      ],
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + inset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 24),
                if (_demoTabs.index == 0) ...[
                  _homeHero(compact: MediaQuery.sizeOf(context).width < 600),
                  const SizedBox(height: 24),
                  _buildActionTabsCard(),
                  if (_error != null || _formError != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(),
                  ],
                ],
                // Keep the embedded chat host mounted when navigating away.
                Offstage(
                  offstage: _demoTabs.index != 1,
                  child: FutureBuilder<String>(
                    future: _deviceIdFuture,
                    builder: (context, snapshot) => snapshot.hasData
                        ? StandaloneChatDemoPage(
                            backendUrl: _server,
                            realtime: _newRealtime(),
                            userId: snapshot.data!,
                            displayName: _displayNameController.text,
                            avatarUrl: _avatarUrlController.text,
                            embedded: true,
                            visible: _demoTabs.index == 1,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
                if (_demoTabs.index == 2) ...[
                  Text(
                    strings.settings,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  _buildIdentitySettingsSection(),
                  const SizedBox(height: 24),
                  _buildServerSettingsSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.pillRadius,
      opacity: 0.78,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Realtime Media',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 6),
          _buildLanguageMenu(),
          IconButton(
            tooltip: DemoStrings.of(context).settings,
            onPressed: () => _selectDestination(2),
            icon: RealtimeAvatar(
              name: _displayNameController.text,
              avatarUrl: _avatarUrlController.text,
              size: 30,
            ),
          ),
          const SizedBox(width: 4),
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
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        color: style.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          side: BorderSide(color: style.border),
        ),
        icon: Icon(Icons.language_rounded, size: 18, color: style.text),
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

  Widget _homeHero({required bool compact}) => DemoHomeHero(
    compact: compact,
    mediaProviderId: _serverMediaProviderId,
    chatProviderId: _serverChatProviderId,
    online: _serverOnline,
    testingServer: _testingServer,
  );

  Widget _buildServerSettingsSection() => DemoServerSettingsPanel(
    controller: _serverController,
    diagnostics: _diagnostics,
    defaultBackendUrl: _defaultBackendUrl,
    onTest: _testConnection,
  );
  Widget _buildIdentitySettingsSection() => DemoIdentitySettingsPanel(
    deviceId: _deviceIdFuture,
    displayNameController: _displayNameController,
    avatarUrlController: _avatarUrlController,
    onAvatarChanged: (value) {
      unawaited(_identityStore.saveAvatarUrl(value));
      setState(() {});
    },
    onNameChanged: (value) {
      unawaited(_persistDisplayName(value));
      setState(() {});
    },
  );

  Widget _buildActionTabsCard() {
    final strings = DemoStrings.of(context);
    final style = RealtimeStyle.of(context);
    final form = RealtimeCardSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.joinRoom, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          RealtimeCupertinoSegmentedBar<MediaRoomMode>(
            groupValue: _joinRoomMode,
            onValueChanged: (mode) => setState(() => _joinRoomMode = mode),
            children: {
              MediaRoomMode.meeting: Text(strings.joinMeetingParticipant),
              MediaRoomMode.broadcast: Text(strings.watchLiveViewer),
            },
          ),
          const SizedBox(height: 20),
          _roomForm(
            code: _joinCodeController,
            codeLabel: strings.roomCode,
            actionLabel: strings.joinRoom,
            action: _joinRoom,
            isCreate: false,
          ),
          const SizedBox(height: 20),
          Divider(color: style.border),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _showCreateForm(false),
            icon: const Icon(Icons.add_rounded),
            label: Text(strings.createMeeting),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : () => _showCreateForm(true),
            icon: const Icon(Icons.sensors_rounded),
            label: Text(strings.startLive),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 850 &&
            MediaQuery.textScalerOf(context).scale(17) < 28;
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: form),
                  const SizedBox(width: 24),
                  Expanded(child: _buildAvailableRooms()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  form,
                  const SizedBox(height: 24),
                  _buildAvailableRooms(),
                ],
              );
      },
    );
  }

  void _showCreateForm(bool live) {
    final strings = DemoStrings.of(context);
    final label = live ? strings.startLive : strings.createMeeting;
    unawaited(
      showRealtimeGlassBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: RealtimeSheetHeader(title: label)),
                  IconButton(
                    tooltip: RealtimeStrings.of(context).close,
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                live
                    ? strings.liveBannerDescription
                    : strings.meetingBannerDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _roomForm(
                code: _createCodeController,
                codeLabel: strings.optionalRoomCode,
                actionLabel: label,
                isCreate: true,
                action: () async {
                  _createRoomMode = live
                      ? MediaRoomMode.broadcast
                      : MediaRoomMode.meeting;
                  Navigator.pop(sheetContext);
                  await _createRoom();
                },
              ),
            ],
          ),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RealtimeGlassTextField(
          controller: code,
          label: codeLabel,
          hintText: DemoStrings.of(context).roomCodeHelp,
          prefixIcon: Icons.tag_rounded,
          suffix: isCreate
              ? RealtimeFieldAction(
                  label: DemoStrings.of(context).random,
                  icon: Icons.casino_outlined,
                  onPressed: _busy ? null : _generateRandomCreateCode,
                )
              : RealtimeFieldAction(
                  label: RealtimeStrings.of(context).paste,
                  icon: Icons.content_paste_rounded,
                  onPressed: _busy ? null : () => unawaited(_pasteJoinCode()),
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
