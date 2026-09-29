import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

typedef MediaPreJoinCheckRunner = Future<MediaPreJoinResult> Function();

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
  const _ResultView({super.key, required this.result});

  final MediaPreJoinResult result;

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
                  _CheckRow(check: result.checks[i], index: i),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.index});

  final MediaPreJoinCheck check;
  final int index;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(check.status);
    final strings = RealtimeStrings.of(context);
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
            RealtimePill(
              label: strings.preJoinStatus(check.status.name),
              foreground: visual.color,
              background: visual.background,
              borderColor: visual.color.withValues(alpha: 0.24),
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
    this.displayName = '',
    this.roomLabel,
    this.title,
  });

  final MediaPreJoinCheckRunner runCheck;
  final MediaLocalPreviewOpener openPreview;
  final String displayName;
  final String? roomLabel;
  final String? title;

  static Future<MediaLocalPreviewSettings?> show(
    BuildContext context, {
    required MediaPreJoinCheckRunner runCheck,
    required MediaLocalPreviewOpener openPreview,
    String displayName = '',
    String? roomLabel,
    String? title,
  }) => Navigator.of(context).push<MediaLocalPreviewSettings?>(
    MaterialPageRoute(
      builder: (_) => MediaPreJoinPage(
        runCheck: runCheck,
        openPreview: openPreview,
        displayName: displayName,
        roomLabel: roomLabel,
        title: title,
      ),
    ),
  );

  @override
  State<MediaPreJoinPage> createState() => _MediaPreJoinPageState();
}

class _MediaPreJoinPageState extends State<MediaPreJoinPage> {
  MediaPreJoinResult? _result;
  MediaLocalPreviewSession? _preview;
  Object? _error;
  Object? _previewError;
  Object? _deviceError;
  List<MediaDevice> _devices = const [];
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _loading = true;
      _error = null;
      _previewError = null;
      _deviceError = null;
      _devices = const [];
    });
    await _disposePreview();
    try {
      final result = await widget.runCheck();
      if (!mounted) return;
      _result = result;
      setState(() => _loading = false);
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

  @override
  void dispose() {
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
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(
          child: Column(
            children: [
              _pageHeader(context, strings),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final preview = _previewPanel(strings, isViewer);
                    final setup = _setupPanel(strings, result, isViewer);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: preview),
                          Expanded(flex: 5, child: setup),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      children: [preview, const SizedBox(height: 12), setup],
                    );
                  },
                ),
              ),
              _footer(strings, result),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(BuildContext context, RealtimeStrings strings) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
    child: Row(
      children: [
        IconButton(
          tooltip: strings.cancel,
          onPressed: _saving ? null : _cancel,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ?? strings.preJoinCheck,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (widget.roomLabel?.isNotEmpty == true)
                Text(
                  widget.roomLabel!,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _previewPanel(RealtimeStrings strings, bool isViewer) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: const Color(0xFF111827),
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
                          Icon(
                            isViewer
                                ? Icons.live_tv_outlined
                                : Icons.person_outline_rounded,
                            color: const Color(0xFF94A3B8),
                            size: 58,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isViewer
                                ? strings.live
                                : _preview == null
                                ? strings.cameraPreviewUnavailable
                                : strings.camera,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
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
                      background: const Color(0xB3000000),
                      borderColor: const Color(0x40FFFFFF),
                    ),
                  ),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!isViewer && _preview != null) _mediaToggles(strings),
        if (_previewError != null ||
            (!isViewer && _preview == null && !_loading))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _previewError == null
                  ? strings.cameraPreviewUnavailable
                  : '${strings.previewStartFailed} $_previewError',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
            ),
          ),
      ],
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
    avatar: Icon(icon, size: 18),
    label: Text(label),
    selected: enabled,
    onSelected: available ? onChanged : null,
    showCheckmark: false,
    backgroundColor: const Color(0xFF1F2937),
    selectedColor: const Color(0xFF374151),
    labelStyle: const TextStyle(color: Colors.white),
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
      return Padding(
        padding: const EdgeInsets.all(14),
        child: _resultContent(strings, result),
      );
    }
    final preview = _preview;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.deviceSetup,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
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
              Text(
                '${strings.deviceListUnavailable}: $_deviceError',
                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
              )
            else if (!preview.capabilities.canEnumerateMicrophones &&
                !preview.capabilities.canEnumerateCameras &&
                !preview.capabilities.canEnumerateAudioDevices)
              Text(
                strings.deviceSelectionUnsupported,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              )
            else if (_devices.isEmpty)
              Text(
                strings.noDevicesFound,
                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
              ),
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
        dropdownColor: const Color(0xFF1F2937),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          filled: true,
          fillColor: const Color(0xFF111827),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            borderSide: const BorderSide(color: Color(0xFF374151)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            borderSide: const BorderSide(color: Color(0xFF374151)),
          ),
        ),
        style: const TextStyle(color: Colors.white),
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
        children: [
          Text(
            '${strings.unableToRunPreJoin} $_error',
            style: const TextStyle(color: Color(0xFFFCA5A5)),
          ),
          TextButton.icon(
            onPressed: _runChecks,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(strings.runAgain),
          ),
        ],
      );
    }
    if (result == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultView(result: result),
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

  Widget _footer(RealtimeStrings strings, MediaPreJoinResult? result) {
    final label = result?.role == MediaRole.viewer
        ? strings.enterLiveRoom
        : result?.role == MediaRole.host
        ? strings.enterLiveRoom
        : strings.joinMeeting;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(top: BorderSide(color: Color(0xFF253044))),
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: !_loading && !_saving && result?.isReady == true
              ? _enter
              : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: RealtimeUiTokens.primary,
            disabledBackgroundColor: const Color(0xFF374151),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
