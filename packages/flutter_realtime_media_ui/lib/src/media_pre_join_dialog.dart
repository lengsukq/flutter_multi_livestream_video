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
