import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

typedef MediaPreJoinCheckRunner = Future<MediaPreJoinResult> Function();
typedef _PermissionActionCallback =
    Future<void> Function(MediaPermissionKind kind);

class MediaPreJoinDialog extends StatefulWidget {
  const MediaPreJoinDialog({super.key, required this.runCheck, this.title});

  final MediaPreJoinCheckRunner runCheck;
  final String? title;

  static Future<bool> show(
    BuildContext context, {
    required MediaPreJoinCheckRunner runCheck,
    String? title,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.34),
        builder: (_) => MediaPreJoinDialog(runCheck: runCheck, title: title),
      ) ??
      false;

  @override
  State<MediaPreJoinDialog> createState() => _MediaPreJoinDialogState();
}

class _MediaPreJoinDialogState extends State<MediaPreJoinDialog> {
  MediaPreJoinResult? _result;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.runCheck();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final strings = RealtimeStrings.of(context);
    return RealtimeGlassDialog(
      icon: Icons.fact_check_outlined,
      title: Text(widget.title ?? strings.preJoinCheck),
      content: SizedBox(
        width: 480,
        child: AnimatedSwitcher(
          duration: RealtimeUiTokens.animNormal,
          switchInCurve: Curves.easeOutCubic,
          child: _loading
              ? _LoadingView(
                  key: const ValueKey('prejoin-loading'),
                  label: strings.runningPreJoinChecks,
                )
              : _error != null
              ? _ErrorView(key: const ValueKey('prejoin-error'), error: _error!)
              : _ResultView(
                  key: const ValueKey('prejoin-result'),
                  result: result!,
                ),
        ),
      ),
      actions: [
        if (!_loading)
          TextButton.icon(
            onPressed: _run,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(strings.runAgain),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(result?.isReady == true ? strings.cancel : strings.close),
        ),
        if (!_loading && _error == null && result?.isReady == true)
          RealtimeGlassPressable(
            borderRadius: RealtimeUiTokens.controlRadius,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: RealtimeUiTokens.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                ),
              ),
              child: Text(strings.continueLabel),
            ),
          ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: RealtimeUiTokens.primarySubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            border: Border.all(color: RealtimeUiTokens.primaryBorder),
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: RealtimeUiTokens.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RealtimeUiTokens.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RealtimeUiTokens.dangerSubtle.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: Border.all(color: RealtimeUiTokens.dangerBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: RealtimeUiTokens.danger,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.unableToRunPreJoin,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: RealtimeUiTokens.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: RealtimeUiTokens.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    super.key,
    required this.result,
    this.permissionStates = const {},
    this.requestingPermission,
    this.canOpenAppSettings = false,
    this.onPermissionAction,
  });

  final MediaPreJoinResult result;
  final Map<MediaPermissionKind, MediaPermissionState> permissionStates;
  final MediaPermissionKind? requestingPermission;
  final bool canOpenAppSettings;
  final _PermissionActionCallback? onPermissionAction;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: result.isReady
                ? RealtimeUiTokens.successSubtle.withValues(alpha: 0.90)
                : RealtimeUiTokens.dangerSubtle.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            border: Border.all(
              color: result.isReady
                  ? RealtimeUiTokens.successBorder
                  : RealtimeUiTokens.dangerBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  result.isReady
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 20,
                  color: result.isReady
                      ? RealtimeUiTokens.success
                      : RealtimeUiTokens.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.isReady
                      ? strings.readyToContinue
                      : strings.resolveBlockingIssues,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: RealtimeUiTokens.text,
                  ),
                ),
              ),
              if (result.providerId case final provider?)
                RealtimePill(
                  label: mediaProviderDisplayName(provider),
                  foreground: RealtimeUiTokens.primary,
                  background: Colors.white,
                  borderColor: RealtimeUiTokens.primaryBorder,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < result.checks.length; i++)
                  _CheckRow(
                    check: result.checks[i],
                    index: i,
                    permissionStates: permissionStates,
                    requestingPermission: requestingPermission,
                    canOpenAppSettings: canOpenAppSettings,
                    onPermissionAction: onPermissionAction,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.check,
    required this.index,
    required this.permissionStates,
    required this.requestingPermission,
    required this.canOpenAppSettings,
    required this.onPermissionAction,
  });

  final MediaPreJoinCheck check;
  final int index;
  final Map<MediaPermissionKind, MediaPermissionState> permissionStates;
  final MediaPermissionKind? requestingPermission;
  final bool canOpenAppSettings;
  final _PermissionActionCallback? onPermissionAction;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(check.status);
    final strings = RealtimeStrings.of(context);
    final permissionKind = _permissionKindFor(check.type);
    final permissionState = permissionKind == null
        ? null
        : permissionStates[permissionKind];
    final canAct =
        onPermissionAction != null &&
        permissionKind != null &&
        permissionState != null &&
        permissionState != MediaPermissionState.granted &&
        permissionState != MediaPermissionState.unsupported &&
        permissionState != MediaPermissionState.restricted;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 180 + (index * 35).clamp(0, 160)),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 8),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .76),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          border: Border.all(color: RealtimeUiTokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: Icon(visual.icon, size: 18, color: visual.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelFor(strings, check.type),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: RealtimeUiTokens.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    check.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RealtimeUiTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RealtimePill(
                  label: strings.preJoinStatus(check.status.name),
                  foreground: visual.color,
                  background: visual.background,
                  borderColor: visual.color.withValues(alpha: 0.24),
                ),
                if (canAct) ...[
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: requestingPermission == permissionKind
                        ? null
                        : () => onPermissionAction!(permissionKind!),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: requestingPermission == permissionKind
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            permissionState ==
                                    MediaPermissionState.permanentlyDenied
                                ? canOpenAppSettings
                                      ? strings.openAppSettings
                                      : strings.browserPermissionSettings
                                : strings.requestPermission,
                            textAlign: TextAlign.right,
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CheckVisual _visualFor(MediaPreJoinStatus status) => switch (status) {
    MediaPreJoinStatus.passed => const _CheckVisual(
      Icons.check_circle_outline_rounded,
      RealtimeUiTokens.success,
      RealtimeUiTokens.successSubtle,
    ),
    MediaPreJoinStatus.failed => const _CheckVisual(
      Icons.cancel_outlined,
      RealtimeUiTokens.danger,
      RealtimeUiTokens.dangerSubtle,
    ),
    MediaPreJoinStatus.unsupported => const _CheckVisual(
      Icons.remove_circle_outline_rounded,
      RealtimeUiTokens.textMuted,
      RealtimeUiTokens.surfaceSubtle,
    ),
    MediaPreJoinStatus.unknown => const _CheckVisual(
      Icons.help_outline_rounded,
      RealtimeUiTokens.warning,
      RealtimeUiTokens.warningSubtle,
    ),
  };

  String _labelFor(RealtimeStrings strings, MediaPreJoinCheckType type) =>
      switch (type) {
        MediaPreJoinCheckType.backend => strings.backend,
        MediaPreJoinCheckType.provider => strings.provider,
        MediaPreJoinCheckType.microphonePermission =>
          strings.microphonePermission,
        MediaPreJoinCheckType.cameraPermission => strings.cameraPermission,
        MediaPreJoinCheckType.microphoneDevice => strings.microphoneDevice,
        MediaPreJoinCheckType.cameraDevice => strings.cameraDevice,
        MediaPreJoinCheckType.network => strings.network,
        MediaPreJoinCheckType.providerNetwork => strings.providerNetwork,
      };
}

class _CheckVisual {
  const _CheckVisual(this.icon, this.color, this.background);

  final IconData icon;
  final Color color;
  final Color background;
}

MediaPermissionKind? _permissionKindFor(MediaPreJoinCheckType type) =>
    switch (type) {
      MediaPreJoinCheckType.microphonePermission =>
        MediaPermissionKind.microphone,
      MediaPreJoinCheckType.cameraPermission => MediaPermissionKind.camera,
      _ => null,
    };

typedef MediaLocalPreviewOpener =
    Future<MediaLocalPreviewSession?> Function(
      String providerId,
      MediaRole role,
    );

/// Responsive device setup page used before joining a meeting or live room.
///
/// [MediaPreJoinDialog.show] remains available for existing integrations.
class MediaPreJoinPage extends StatefulWidget {
  const MediaPreJoinPage({
    super.key,
    required this.runCheck,
    required this.openPreview,
    this.permissionRequester = const DefaultMediaPermissionProbe(),
    this.displayName = '',
    this.roomLabel,
    this.title,
  });

  final MediaPreJoinCheckRunner runCheck;
  final MediaLocalPreviewOpener openPreview;
  final MediaPermissionRequester permissionRequester;
  final String displayName;
  final String? roomLabel;
  final String? title;

  static Future<MediaLocalPreviewSettings?> show(
    BuildContext context, {
    required MediaPreJoinCheckRunner runCheck,
    required MediaLocalPreviewOpener openPreview,
    MediaPermissionRequester permissionRequester =
        const DefaultMediaPermissionProbe(),
    String displayName = '',
    String? roomLabel,
    String? title,
  }) => Navigator.of(context).push<MediaLocalPreviewSettings?>(
    MaterialPageRoute(
      builder: (_) => MediaPreJoinPage(
        runCheck: runCheck,
        openPreview: openPreview,
        permissionRequester: permissionRequester,
        displayName: displayName,
        roomLabel: roomLabel,
        title: title,
      ),
    ),
  );

  @override
  State<MediaPreJoinPage> createState() => _MediaPreJoinPageState();
}

class _MediaPreJoinPageState extends State<MediaPreJoinPage>
    with WidgetsBindingObserver {
  MediaPreJoinResult? _result;
  MediaLocalPreviewSession? _preview;
  Object? _error;
  Object? _previewError;
  Object? _deviceError;
  List<MediaDevice> _devices = const [];
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  Map<MediaPermissionKind, MediaPermissionState> _permissionStates = const {};
  MediaPermissionKind? _requestingPermission;
  bool _refreshPermissionsOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runChecks();
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
      _previewError = null;
      _deviceError = null;
      _devices = const [];
      _permissionStates = const {};
    });
    await _disposePreview();
    try {
      final result = await widget.runCheck();
      final permissionStates = await _readPermissionStates();
      if (!mounted) return;
      _result = result;
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
          _preview = preview;
          if (preview != null) {
            try {
              _devices = await preview.listMediaDevices();
            } catch (error) {
              _deviceError = error;
            }
          }
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

  Future<void> _disposePreview() async {
    final preview = _preview;
    _preview = null;
    if (preview != null) await preview.dispose();
  }

  Future<void> _enter() async {
    final result = _result;
    if (_loading || _saving || result == null || !result.isReady) return;
    setState(() => _saving = true);
    final settings =
        _preview?.settings ?? MediaLocalPreviewSettings(cameraEnabled: false);
    await _disposePreview();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop(settings);
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
      if (mounted) setState(() => _previewError = null);
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    }
  }

  Future<void> _setCamera(bool enabled) async {
    final preview = _preview;
    if (preview == null) return;
    try {
      await preview.setCameraEnabled(enabled);
      if (mounted) setState(() => _previewError = null);
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    }
  }

  Future<void> _selectDevice(MediaDevice device) async {
    final preview = _preview;
    if (preview == null) return;
    try {
      await preview.selectMediaDevice(device);
      if (mounted) setState(() => _deviceError = null);
    } catch (error) {
      if (mounted) setState(() => _deviceError = error);
    }
  }

  Future<Map<MediaPermissionKind, MediaPermissionState>>
  _readPermissionStates() async => {
    for (final kind in MediaPermissionKind.values)
      kind: await _safePermissionStatus(kind),
  };

  Future<MediaPermissionState> _safePermissionStatus(
    MediaPermissionKind kind,
  ) async {
    try {
      return await widget.permissionRequester.status(kind);
    } catch (_) {
      return MediaPermissionState.unknown;
    }
  }

  Future<void> _refreshPermissionStates({required bool updateChecks}) async {
    final states = await _readPermissionStates();
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
      if (widget.permissionRequester.canOpenAppSettings) {
        setState(() => _requestingPermission = kind);
        _refreshPermissionsOnResume = true;
        var opened = false;
        try {
          opened = await widget.permissionRequester.openAppSettings();
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
      next = await widget.permissionRequester.request(kind);
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
  ) {
    final type = kind == MediaPermissionKind.microphone
        ? MediaPreJoinCheckType.microphonePermission
        : MediaPreJoinCheckType.cameraPermission;
    final original = result.check(type);
    if (original == null) return result;
    final status = switch (state) {
      MediaPermissionState.granted => MediaPreJoinStatus.passed,
      MediaPermissionState.denied ||
      MediaPermissionState.permanentlyDenied ||
      MediaPermissionState.restricted => MediaPreJoinStatus.failed,
      MediaPermissionState.unsupported => MediaPreJoinStatus.unsupported,
      MediaPermissionState.limited ||
      MediaPermissionState.provisional ||
      MediaPermissionState.unknown => MediaPreJoinStatus.unknown,
    };
    final label = kind == MediaPermissionKind.microphone
        ? RealtimeStrings.of(context).microphone
        : RealtimeStrings.of(context).camera;
    final strings = RealtimeStrings.of(context);
    final message = switch (state) {
      MediaPermissionState.granted => strings.permissionGranted(label),
      MediaPermissionState.denied => strings.permissionDenied(label),
      MediaPermissionState.permanentlyDenied =>
        widget.permissionRequester.canOpenAppSettings
            ? strings.permissionPermanentlyDenied(label)
            : strings.permissionBrowserHelp(label),
      MediaPermissionState.restricted => strings.permissionRestricted(label),
      MediaPermissionState.unsupported => original.message,
      MediaPermissionState.limited ||
      MediaPermissionState.provisional => original.message,
      MediaPermissionState.unknown => strings.permissionDenied(label),
    };
    final updated = MediaPreJoinCheck(
      type: original.type,
      status: status,
      severity: original.severity,
      message: message,
      details: original.details,
    );
    return MediaPreJoinResult(
      role: result.role,
      providerId: result.providerId,
      checks: [
        for (final check in result.checks) check.type == type ? updated : check,
      ],
    );
  }

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
      _deviceError = null;
      _devices = const [];
    });
    try {
      final preview = await widget.openPreview(result.providerId!, result.role);
      if (!mounted) {
        await preview?.dispose();
        return;
      }
      _preview = preview;
      if (preview != null) {
        try {
          _devices = await preview.listMediaDevices();
        } catch (error) {
          _deviceError = error;
        }
      }
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final preview = _preview;
    _preview = null;
    if (preview != null) unawaited(preview.dispose());
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
            child: Column(
              children: [
                _pageHeader(context, strings),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide =
                          constraints.maxWidth >= 960 &&
                          constraints.maxHeight >= 500;
                      final preview = _previewPanel(strings, isViewer);
                      final setup = _setupPanel(strings, result, isViewer);
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 20 : 14,
                              2,
                              wide ? 20 : 14,
                              14,
                            ),
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 6, child: preview),
                                      const SizedBox(width: 18),
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
                _footer(strings, result),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(BuildContext context, RealtimeStrings strings) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: RealtimeGlassSurface(
      radius: RealtimeUiTokens.dockRadius,
      opacity: .88,
      blur: RealtimeUiTokens.subtleBlur,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? strings.preJoinCheck,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: RealtimeUiTokens.text,
                  ),
                ),
                if (widget.roomLabel?.isNotEmpty == true)
                  Text(
                    widget.roomLabel!,
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
          if (_result?.providerId case final provider?) ...[
            const SizedBox(width: 8),
            RealtimePill(
              label: mediaProviderDisplayName(provider),
              icon: Icons.hub_outlined,
              foreground: RealtimeUiTokens.primary,
              background: RealtimeUiTokens.primarySubtle,
              borderColor: RealtimeUiTokens.primaryBorder,
            ),
          ],
        ],
      ),
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
            child: Text(
              strings.camera,
              style: const TextStyle(
                color: RealtimeUiTokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.dockRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: const Color(0xFFE9EEF6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_preview?.cameraTrack case final track?)
                      MediaTrackView(renderer: _preview!.renderer, track: track)
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .70),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: RealtimeUiTokens.borderStrong,
                                ),
                              ),
                              child: Icon(
                                isViewer
                                    ? Icons.live_tv_outlined
                                    : Icons.person_outline_rounded,
                                color: RealtimeUiTokens.primary,
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
                              style: const TextStyle(
                                color: RealtimeUiTokens.textMuted,
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
                        foreground: RealtimeUiTokens.text,
                        background: Colors.white,
                        borderColor: RealtimeUiTokens.borderStrong,
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
          if (_previewError != null ||
              (!isViewer && _preview == null && !_loading))
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
          _resultContent(strings, result),
        ],
      ),
    );
  }

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
          if (device != null) _selectDevice(device);
        },
      ),
    );
  }

  Widget _resultContent(RealtimeStrings strings, MediaPreJoinResult? result) {
    if (_loading) return _LoadingView(label: strings.runningPreJoinChecks);
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
        _ResultView(
          result: result,
          permissionStates: _permissionStates,
          requestingPermission: _requestingPermission,
          canOpenAppSettings: widget.permissionRequester.canOpenAppSettings,
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
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .92,
      blur: RealtimeUiTokens.subtleBlur,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result?.providerId == null
                  ? strings.preJoinCheck
                  : mediaProviderDisplayName(result!.providerId!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RealtimeUiTokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // The CTA must stay a flex child: a hard maxWidth of 320 plus the
          // 12px gap overflows the footer on 390px phone viewports, where the
          // glass surface leaves only ~331.8px of usable width.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                height: 48,
                child: RealtimeGlassButton(
                  onPressed: !_loading && !_saving && result?.isReady == true
                      ? _enter
                      : null,
                  isLoading: _saving,
                  icon: Icons.arrow_forward_rounded,
                  child: Text(label),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
