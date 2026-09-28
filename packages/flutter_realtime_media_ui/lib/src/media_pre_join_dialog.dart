import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';

typedef MediaPreJoinCheckRunner = Future<MediaPreJoinResult> Function();

class MediaPreJoinDialog extends StatefulWidget {
  const MediaPreJoinDialog({
    super.key,
    required this.runCheck,
    this.title = 'Pre-Join Check',
  });

  final MediaPreJoinCheckRunner runCheck;
  final String title;

  static Future<bool> show(
    BuildContext context, {
    required MediaPreJoinCheckRunner runCheck,
    String title = 'Pre-Join Check',
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? _ErrorView(error: _error!)
            : _ResultView(result: result!),
      ),
      actions: [
        if (!_loading)
          TextButton.icon(
            onPressed: _run,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Run again'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(result?.isReady == true ? 'Cancel' : 'Close'),
        ),
        if (!_loading && _error == null && result?.isReady == true)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, size: 36),
      const SizedBox(height: 12),
      const Text(
        'Unable to run the pre-join check.',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        error.toString(),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final MediaPreJoinResult result;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: result.isReady
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              result.isReady
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: result.isReady
                  ? const Color(0xFF047857)
                  : const Color(0xFFB91C1C),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.isReady
                    ? 'Ready to continue'
                    : 'Resolve blocking issues before joining',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (result.providerId case final provider?)
              Text(
                mediaProviderDisplayName(provider),
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            children: result.checks
                .map((check) => _CheckRow(check: check))
                .toList(growable: false),
          ),
        ),
      ),
    ],
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final MediaPreJoinCheck check;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(check.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(visual.icon, size: 19, color: visual.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelFor(check.type),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  check.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            check.status.name.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _CheckVisual _visualFor(MediaPreJoinStatus status) => switch (status) {
    MediaPreJoinStatus.passed => const _CheckVisual(
      Icons.check_circle_outline_rounded,
      Color(0xFF059669),
    ),
    MediaPreJoinStatus.failed => const _CheckVisual(
      Icons.cancel_outlined,
      Color(0xFFDC2626),
    ),
    MediaPreJoinStatus.unsupported => const _CheckVisual(
      Icons.remove_circle_outline_rounded,
      Color(0xFF64748B),
    ),
    MediaPreJoinStatus.unknown => const _CheckVisual(
      Icons.help_outline_rounded,
      Color(0xFFD97706),
    ),
  };

  String _labelFor(MediaPreJoinCheckType type) => switch (type) {
    MediaPreJoinCheckType.backend => 'Backend',
    MediaPreJoinCheckType.provider => 'Provider',
    MediaPreJoinCheckType.microphonePermission => 'Microphone permission',
    MediaPreJoinCheckType.cameraPermission => 'Camera permission',
    MediaPreJoinCheckType.microphoneDevice => 'Microphone device',
    MediaPreJoinCheckType.cameraDevice => 'Camera device',
    MediaPreJoinCheckType.network => 'Network',
    MediaPreJoinCheckType.providerNetwork => 'Provider network',
  };
}

class _CheckVisual {
  const _CheckVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}
