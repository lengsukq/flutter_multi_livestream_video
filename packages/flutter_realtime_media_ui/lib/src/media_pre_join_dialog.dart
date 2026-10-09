import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'media_pre_join_check_widgets.dart';
import 'pre_join_preview_owner.dart';
import 'pre_join_permission_coordinator.dart';
import 'pre_join_media_setup_controller.dart';
import 'background_effect_selector.dart';
import 'media_background_image_preset.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

typedef MediaPreJoinCheckRunner = Future<MediaPreJoinResult> Function();
typedef MediaLocalPreviewOpener =
    Future<MediaLocalPreviewSession?> Function(
      String providerId,
      MediaRole role,
    );

/// Lets a host app perform the actual room entry without closing Pre-Join.
///
/// The preview has already been released before this is called. The host can
/// open its room and replace the Pre-Join route using [context]. Failures are
/// caught and displayed on Pre-Join so that users can retry from here.
typedef MediaPreJoinEnter =
    Future<void> Function(
      BuildContext context,
      MediaLocalPreviewSettings settings,
    );

/// Responsive device setup page used before joining a meeting or live room.
///
/// The public Pre-Join entrypoint also supports asynchronous room entry.
class MediaPreJoinPage extends StatefulWidget {
  const MediaPreJoinPage({
    super.key,
    required this.runCheck,
    required this.openPreview,
    this.onEnter,
    this.permissionRequester = const DefaultMediaPermissionProbe(),
    this.displayName = '',
    this.roomLabel,
    this.title,
    this.backendProviderId,
    this.backgroundImageBytes,
    this.backgroundImagePresets = const [],
  });

  final MediaPreJoinCheckRunner runCheck;
  final MediaLocalPreviewOpener openPreview;
  final MediaPreJoinEnter? onEnter;
  final MediaPermissionRequester permissionRequester;
  final String displayName;
  final String? roomLabel;
  final String? title;

  /// Provider reported by the backend health endpoint, independent of the
  /// provider resolved for the room being joined.
  final String? backendProviderId;

  /// Optional local preset supplied by the host application.
  final Uint8List? backgroundImageBytes;
  final List<MediaBackgroundImagePreset> backgroundImagePresets;

  static Future<MediaLocalPreviewSettings?> show(
    BuildContext context, {
    required MediaPreJoinCheckRunner runCheck,
    required MediaLocalPreviewOpener openPreview,
    MediaPreJoinEnter? onEnter,
    MediaPermissionRequester permissionRequester =
        const DefaultMediaPermissionProbe(),
    String displayName = '',
    String? roomLabel,
    String? title,
    String? backendProviderId,
    Uint8List? backgroundImageBytes,
    List<MediaBackgroundImagePreset> backgroundImagePresets = const [],
  }) => Navigator.of(context).push<MediaLocalPreviewSettings?>(
    MaterialPageRoute(
      builder: (_) => MediaPreJoinPage(
        runCheck: runCheck,
        openPreview: openPreview,
        onEnter: onEnter,
        permissionRequester: permissionRequester,
        displayName: displayName,
        roomLabel: roomLabel,
        title: title,
        backendProviderId: backendProviderId,
        backgroundImageBytes: backgroundImageBytes,
        backgroundImagePresets: backgroundImagePresets,
      ),
    ),
  );

  @override
  State<MediaPreJoinPage> createState() => _MediaPreJoinPageState();
}

class _MediaPreJoinPageState extends State<MediaPreJoinPage>
    with WidgetsBindingObserver {
  MediaPreJoinResult? _result;
  final _previewOwner = PreJoinPreviewOwner();
  late final _permissions = PreJoinPermissionCoordinator(
    widget.permissionRequester,
  );
  MediaLocalPreviewSession? get _preview => _previewOwner.session;
  Object? _error;
  Object? _previewError;
  final _mediaSetup = PreJoinMediaSetupController();
  Object? get _deviceError => _mediaSetup.deviceError;
  List<MediaDevice> get _devices => _mediaSetup.devices;
  bool _loading = true;
  bool _saving = false;
  bool _joining = false;
  Object? _joinError;
  MediaLocalPreviewSettings? _lastJoinSettings;
  bool get _updatingBackground => _mediaSetup.updatingBackground;
  bool _allowPop = false;
  MediaBackgroundEffect get _backgroundEffect => _mediaSetup.backgroundEffect;
  Map<MediaPermissionKind, MediaPermissionState> _permissionStates = const {};
  MediaPermissionKind? _requestingPermission;
  bool _refreshPermissionsOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    observeDetached(_runChecks());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _refreshPermissionsOnResume) {
      _refreshPermissionsOnResume = false;
      unawaited(_refreshPermissionStates(updateChecks: true));
    }
  }

  Future<void> _runChecks() async {
    setState(() {
      _loading = true;
      _error = null;
      _joinError = null;
      _lastJoinSettings = null;
      _previewError = null;
      _mediaSetup.resetDevices();
      _permissionStates = const {};
    });
    await _disposePreview();
    try {
      final result = await widget.runCheck();
      final permissionStates = await _permissions.readStatuses();
      if (!mounted) return;
      _result = result;
      _mediaSetup.applyCapabilities(result.backgroundCapabilities);
      setState(() {
        _permissionStates = permissionStates;
        _loading = false;
      });
      if (result.role != MediaRole.viewer && result.providerId != null) {
        try {
          final preview = await widget.openPreview(
            result.providerId!,
            result.role,
          );
          if (!mounted) {
            await preview?.dispose();
            return;
          }
          _bindPreview(preview);
          await _mediaSetup.loadDevices(preview);
          setState(() {});
        } catch (error) {
          if (mounted) setState(() => _previewError = error);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _bindPreview(MediaLocalPreviewSession? preview) {
    _previewOwner.bind(
      preview,
      onFailure: (error) {
        if (mounted) setState(() => _previewError = error);
      },
    );
  }

  Future<void> _disposePreview() => _previewOwner.release();

  Future<void> _enter() async {
    final result = _result;
    if (_loading || _saving || result == null || !result.isReady) return;
    final retrySettings = _joinError == null ? null : _lastJoinSettings;
    setState(() {
      _saving = true;
      _joining = widget.onEnter != null;
      _joinError = null;
    });
    final settings =
        (retrySettings ??
                _preview?.settings ??
                MediaLocalPreviewSettings(cameraEnabled: false))
            .copyWith(backgroundEffect: _backgroundEffect);
    _lastJoinSettings = settings;
    try {
      await _disposePreview();
      if (!mounted) return;
      if (widget.onEnter case final onEnter?) {
        await onEnter(context, settings);
      }
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop(settings);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _joining = false;
        _joinError = error;
      });
      await _retryLocalPreview();
    }
  }

  Future<void> _cancel() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _disposePreview();
    if (mounted && Navigator.canPop(context)) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _setMicrophone(bool enabled) async {
    final preview = _preview;
    if (preview == null) return;
    try {
      await preview.setMicrophoneEnabled(enabled);
      _lastJoinSettings = null;
      if (mounted) setState(() => _previewError = null);
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    }
  }

  Future<void> _setBackgroundEffect(MediaBackgroundEffect effect) async {
    if (_updatingBackground) return;
    final update = _mediaSetup.applyBackground(_preview, effect);
    if (mounted) setState(() {});
    try {
      await update;
      if (mounted) setState(() => _previewError = null);
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _setCamera(bool enabled) async {
    final preview = _preview;
    if (preview == null) return;
    try {
      await preview.setCameraEnabled(enabled);
      _lastJoinSettings = null;
      if (mounted) setState(() => _previewError = null);
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    }
  }

  Future<void> _selectDevice(MediaDevice device) async {
    final preview = _preview;
    if (preview == null) return;
    final selected = await _mediaSetup.selectDevice(preview, device);
    if (selected) _lastJoinSettings = null;
    if (mounted) setState(() {});
  }

  Future<void> _refreshPermissionStates({required bool updateChecks}) async {
    final states = await _permissions.readStatuses();
    if (!mounted) return;
    setState(() {
      _permissionStates = states;
      if (updateChecks && _result != null) {
        var updatedResult = _result!;
        updatedResult = _withPermissionState(
          updatedResult,
          MediaPermissionKind.microphone,
          states[MediaPermissionKind.microphone] ??
              MediaPermissionState.unknown,
        );
        updatedResult = _withPermissionState(
          updatedResult,
          MediaPermissionKind.camera,
          states[MediaPermissionKind.camera] ?? MediaPermissionState.unknown,
        );
        _result = updatedResult;
      }
    });
  }

  Future<void> _onPermissionAction(MediaPermissionKind kind) async {
    final current = _permissionStates[kind] ?? MediaPermissionState.unknown;
    if (current == MediaPermissionState.permanentlyDenied) {
      if (_permissions.canOpenAppSettings) {
        setState(() => _requestingPermission = kind);
        _refreshPermissionsOnResume = true;
        var opened = false;
        try {
          opened = await _permissions.openAppSettings();
        } catch (_) {
          opened = false;
        }
        if (!mounted) return;
        setState(() => _requestingPermission = null);
        if (!opened) {
          _refreshPermissionsOnResume = false;
          _showPermissionMessage(
            RealtimeStrings.of(context).permissionSettingsUnavailable,
          );
        }
      } else {
        await _showBrowserPermissionHelp(kind);
      }
      return;
    }

    if (current == MediaPermissionState.restricted) return;
    setState(() => _requestingPermission = kind);
    MediaPermissionState next;
    var requestFailed = false;
    try {
      next = await _permissions.request(kind);
    } catch (_) {
      next = MediaPermissionState.unknown;
      requestFailed = true;
    }
    if (!mounted) return;
    setState(() {
      _requestingPermission = null;
      _permissionStates = {..._permissionStates, kind: next};
      if (_result != null) {
        _result = _withPermissionState(_result!, kind, next);
      }
    });
    if (requestFailed || next == MediaPermissionState.unknown) {
      _showPermissionMessage(
        RealtimeStrings.of(context).permissionRequestFailed,
      );
    } else if (kind == MediaPermissionKind.camera &&
        next == MediaPermissionState.granted) {
      await _retryLocalPreview();
    }
  }

  MediaPreJoinResult _withPermissionState(
    MediaPreJoinResult result,
    MediaPermissionKind kind,
    MediaPermissionState state,
  ) => _permissions.projectCheck(
    result: result,
    kind: kind,
    state: state,
    strings: RealtimeStrings.of(context),
  );

  Future<void> _showBrowserPermissionHelp(MediaPermissionKind kind) async {
    final strings = RealtimeStrings.of(context);
    final label = kind == MediaPermissionKind.microphone
        ? strings.microphone
        : strings.camera;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.permissionHelpTitle),
        content: Text(strings.permissionBrowserHelp(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  void _showPermissionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retryLocalPreview() async {
    final result = _result;
    if (result == null ||
        result.role == MediaRole.viewer ||
        result.providerId == null) {
      return;
    }
    await _disposePreview();
    if (!mounted) return;
    setState(() {
      _previewError = null;
      _mediaSetup.resetDevices();
    });
    try {
      final preview = await widget.openPreview(result.providerId!, result.role);
      if (!mounted) {
        await preview?.dispose();
        return;
      }
      _bindPreview(preview);
      await _mediaSetup.loadDevices(preview);
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewOwner.dispose();
    _mediaSetup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final result = _result;
    final isViewer = result?.role == MediaRole.viewer;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) unawaited(_cancel());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RealtimeAmbientBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _pageHeader(context, strings),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide =
                              constraints.maxWidth >= 820 &&
                              constraints.maxHeight >= 420;
                          final preview = _previewPanel(strings, isViewer);
                          final setup = _setupPanel(strings, result, isViewer);
                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: wide ? 1240 : 680,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  constraints.maxWidth < 380 ? 10 : 18,
                                  6,
                                  constraints.maxWidth < 380 ? 10 : 18,
                                  12,
                                ),
                                child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: SingleChildScrollView(
                                              child: preview,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 5,
                                            child: SingleChildScrollView(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: setup,
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView(
                                        padding: EdgeInsets.zero,
                                        children: [
                                          preview,
                                          const SizedBox(height: 12),
                                          setup,
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_joinError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 96),
                          child: SingleChildScrollView(
                            child: _preJoinNotice(
                              '${strings.connectionFailed}: ${_joinError is RealtimeException ? (_joinError! as RealtimeException).message : _joinError}',
                              danger: true,
                            ),
                          ),
                        ),
                      ),
                    _footer(strings, result),
                  ],
                ),
                if (_joining)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xCBEFF3F9),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: RealtimeGlassSurface(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 30,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: RealtimeUiTokens.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    strings.enteringRoom,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: RealtimeUiTokens.text,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    strings.enteringRoomDetail,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: RealtimeUiTokens.textMuted,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(BuildContext context, RealtimeStrings strings) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 570;
        final provider = widget.backendProviderId;
        final providerChip = provider == null
            ? null
            : RealtimePill(
                label: strings.backendProviderLabel(
                  provider.trim().isEmpty
                      ? strings.preJoinStatus('unknown')
                      : mediaProviderDisplayName(provider),
                ),
                icon: Icons.hub_outlined,
                foreground: RealtimeUiTokens.primary,
                background: RealtimeUiTokens.primarySubtle,
                borderColor: RealtimeUiTokens.primaryBorder,
              );
        return RealtimeGlassSurface(
          radius: RealtimeUiTokens.dockRadius,
          opacity: .93,
          blur: RealtimeUiTokens.subtleBlur,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: strings.cancel,
                    onPressed: _saving ? null : _cancel,
                    style: IconButton.styleFrom(
                      foregroundColor: RealtimeUiTokens.text,
                      backgroundColor: RealtimeUiTokens.surfaceSubtle,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? strings.preJoinCheck,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: RealtimeUiTokens.text,
                          ),
                        ),
                        Text(
                          widget.roomLabel?.isNotEmpty == true
                              ? strings.roomLabel(widget.roomLabel!)
                              : strings.preJoinCheck,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RealtimeUiTokens.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact && providerChip != null) ...[
                    const SizedBox(width: 10),
                    providerChip,
                  ],
                ],
              ),
              if (compact && providerChip != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: providerChip,
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _previewPanel(RealtimeStrings strings, bool isViewer) => Padding(
    padding: const EdgeInsets.all(2),
    child: RealtimeGlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.video_camera_front_rounded,
                  size: 18,
                  color: RealtimeUiTokens.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isViewer ? strings.live : strings.camera,
                    style: const TextStyle(
                      color: RealtimeUiTokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.dockRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: const Color(0xFF172239),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_preview?.cameraTrack case final track?)
                      MediaTrackView(
                        renderer: _preview!.renderer,
                        track: track,
                        fit: BoxFit.contain,
                      )
                    else if (_joining)
                      const Center(
                        child: Icon(
                          Icons.video_camera_front_rounded,
                          color: Color(0xFFDEE7F8),
                          size: 32,
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .24),
                                ),
                              ),
                              child: Icon(
                                isViewer
                                    ? Icons.live_tv_outlined
                                    : Icons.person_outline_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isViewer
                                  ? strings.live
                                  : _preview == null
                                  ? strings.cameraPreviewUnavailable
                                  : strings.camera,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFDEE7F8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: RealtimePill(
                        label: widget.displayName.isEmpty
                            ? strings.you
                            : widget.displayName,
                        icon: Icons.person_outline_rounded,
                        foreground: Colors.white,
                        background: const Color(0xCC1E293B),
                        borderColor: const Color(0x55FFFFFF),
                      ),
                    ),
                    if (_loading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: RealtimeUiTokens.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!isViewer && _preview != null) _mediaToggles(strings),
          if (!_joining &&
              (_previewError != null ||
                  (!isViewer && _preview == null && !_loading)))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _preJoinNotice(
                _previewError == null
                    ? strings.cameraPreviewUnavailable
                    : '${strings.previewStartFailed} $_previewError',
                danger: true,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _mediaToggles(RealtimeStrings strings) {
    final preview = _preview!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _toggleChip(
          icon: preview.settings.microphoneEnabled
              ? Icons.mic_rounded
              : Icons.mic_off_rounded,
          label: strings.microphone,
          enabled: preview.settings.microphoneEnabled,
          available: preview.capabilities.canPublishAudio,
          onChanged: _setMicrophone,
        ),
        _toggleChip(
          icon: preview.settings.cameraEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: strings.camera,
          enabled: preview.settings.cameraEnabled,
          available: preview.capabilities.canPublishVideo,
          onChanged: _setCamera,
        ),
      ],
    );
  }

  Widget _toggleChip({
    required IconData icon,
    required String label,
    required bool enabled,
    required bool available,
    required ValueChanged<bool> onChanged,
  }) => FilterChip(
    avatar: Icon(
      icon,
      size: 17,
      color: enabled ? RealtimeUiTokens.primary : RealtimeUiTokens.textMuted,
    ),
    label: Text(label),
    selected: enabled,
    onSelected: available ? onChanged : null,
    showCheckmark: false,
    backgroundColor: Colors.white.withValues(alpha: .78),
    selectedColor: RealtimeUiTokens.primarySubtle,
    checkmarkColor: RealtimeUiTokens.primary,
    labelStyle: TextStyle(
      color: enabled ? RealtimeUiTokens.primary : RealtimeUiTokens.text,
      fontWeight: FontWeight.w700,
    ),
    side: BorderSide(
      color: enabled ? RealtimeUiTokens.primaryBorder : RealtimeUiTokens.border,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
    ),
  );

  Widget _setupPanel(
    RealtimeStrings strings,
    MediaPreJoinResult? result,
    bool isViewer,
  ) {
    if (isViewer) {
      return RealtimeGlassSurface(
        padding: const EdgeInsets.all(16),
        child: _resultContent(strings, result),
      );
    }
    final preview = _preview;
    return RealtimeGlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.deviceSetup,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RealtimeUiTokens.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (preview != null) ...[
            _devicePicker(
              strings.microphone,
              MediaDeviceKind.microphone,
              preview.settings.microphone,
              preview.capabilities.canEnumerateMicrophones &&
                  preview.capabilities.canSelectMicrophone,
            ),
            _devicePicker(
              strings.camera,
              MediaDeviceKind.camera,
              preview.settings.camera,
              preview.capabilities.canEnumerateCameras &&
                  preview.capabilities.canSelectCamera,
            ),
            _devicePicker(
              strings.speaker,
              MediaDeviceKind.audioOutput,
              preview.settings.audioOutput,
              preview.capabilities.canEnumerateAudioDevices &&
                  preview.capabilities.canSelectAudioOutput,
            ),
            const SizedBox(height: 12),
            if (_deviceError != null)
              _preJoinNotice(
                '${strings.deviceListUnavailable}: $_deviceError',
                danger: true,
              )
            else if (!preview.capabilities.canEnumerateMicrophones &&
                !preview.capabilities.canEnumerateCameras &&
                !preview.capabilities.canEnumerateAudioDevices)
              _preJoinNotice(strings.deviceSelectionUnsupported)
            else if (_devices.isEmpty)
              _preJoinNotice(strings.noDevicesFound, danger: true),
          ],
          if (result?.backgroundCapabilities.isSupported == true) ...[
            const SizedBox(height: 12),
            _backgroundEffectSetup(strings),
          ],
          _resultContent(strings, result),
        ],
      ),
    );
  }

  Widget _backgroundEffectSetup(RealtimeStrings strings) => Material(
    color: Colors.white.withValues(alpha: .72),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
      side: const BorderSide(color: RealtimeUiTokens.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: BackgroundEffectSelector(
        capabilities: _result!.backgroundCapabilities,
        effect: _backgroundEffect,
        imageBytes: widget.backgroundImageBytes,
        imagePresets: widget.backgroundImagePresets,
        busy: _updatingBackground,
        onChanged: _setBackgroundEffect,
      ),
    ),
  );

  Widget _devicePicker(
    String label,
    MediaDeviceKind kind,
    MediaDevice? selected,
    bool enabled,
  ) {
    final devices = _devices.where((device) => device.kind == kind).toList();
    if (!enabled || devices.isEmpty) return const SizedBox.shrink();
    final selectedDevice = devices
        .where((d) => d.id == selected?.id)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<MediaDevice>(
        initialValue: selectedDevice,
        isExpanded: true,
        dropdownColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: RealtimeUiTokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: .78),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            borderSide: const BorderSide(color: RealtimeUiTokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            borderSide: const BorderSide(color: RealtimeUiTokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            borderSide: const BorderSide(
              color: RealtimeUiTokens.primary,
              width: 1.5,
            ),
          ),
        ),
        style: const TextStyle(
          color: RealtimeUiTokens.text,
          fontWeight: FontWeight.w600,
        ),
        iconEnabledColor: RealtimeUiTokens.textMuted,
        items: devices
            .map(
              (device) =>
                  DropdownMenuItem(value: device, child: Text(device.label)),
            )
            .toList(growable: false),
        onChanged: (device) {
          if (device != null) observeDetached(_selectDevice(device));
        },
      ),
    );
  }

  Widget _resultContent(RealtimeStrings strings, MediaPreJoinResult? result) {
    if (_loading) {
      return MediaPreJoinLoadingView(label: strings.runningPreJoinChecks);
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _preJoinNotice('${strings.unableToRunPreJoin} $_error', danger: true),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _runChecks,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(strings.runAgain),
            ),
          ),
        ],
      );
    }
    if (result == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPreJoinResultView(
          result: result,
          permissionStates: _permissionStates,
          requestingPermission: _requestingPermission,
          canOpenAppSettings: _permissions.canOpenAppSettings,
          onPermissionAction: _onPermissionAction,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _runChecks,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(strings.runAgain),
          ),
        ),
      ],
    );
  }

  Widget _preJoinNotice(String message, {bool danger = false}) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: danger
          ? RealtimeUiTokens.dangerSubtle
          : RealtimeUiTokens.surfaceSubtle,
      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
      border: Border.all(
        color: danger ? RealtimeUiTokens.dangerBorder : RealtimeUiTokens.border,
      ),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: danger ? RealtimeUiTokens.danger : RealtimeUiTokens.textMuted,
        fontSize: 12,
      ),
    ),
  );

  Widget _footer(RealtimeStrings strings, MediaPreJoinResult? result) {
    final label = result?.role == MediaRole.viewer
        ? strings.enterLiveRoom
        : result?.role == MediaRole.host
        ? strings.enterLiveRoom
        : strings.joinMeeting;
    final providerLabel = result?.providerId == null
        ? strings.preJoinCheck
        : mediaProviderDisplayName(result!.providerId!);
    final action = SizedBox(
      height: 48,
      child: RealtimeGlassButton(
        onPressed: !_loading && !_saving && result?.isReady == true
            ? _enter
            : null,
        isLoading: _saving,
        icon: Icons.arrow_forward_rounded,
        child: Text(label),
      ),
    );
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .92,
      blur: RealtimeUiTokens.subtleBlur,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final provider = Text(
            providerLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RealtimeUiTokens.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
          if (constraints.maxWidth < 540) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: provider,
                ),
                action,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: provider),
              const SizedBox(width: 12),
              SizedBox(width: 270, child: action),
            ],
          );
        },
      ),
    );
  }
}
