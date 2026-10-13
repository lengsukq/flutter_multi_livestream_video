import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Example business event implemented by the Demo, NOT a hard-coded SDK
/// hand-raising/meeting feature. The SDK only transports the typed envelope.
class DemoWaveInteraction {
  const DemoWaveInteraction._();
  static const topic = 'demo.reaction.wave';
}

/// Host-owned layout: a small dock action, not a fixed SDK room toolbar.
class DemoWaveAction extends StatefulWidget {
  const DemoWaveAction({
    super.key,
    required this.room,
    required this.showLabel,
  });

  final RealtimeRoom room;
  final bool showLabel;

  @override
  State<DemoWaveAction> createState() => _DemoWaveActionState();
}

class _DemoWaveActionState extends State<DemoWaveAction> {
  bool _sending = false;

  Future<void> _wave() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.room.interactions.publish(DemoWaveInteraction.topic, {
        'sentAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final supported = widget.room.interactions.capabilities.canPublish;
    return RealtimeDockItem(
      icon: Icons.waving_hand_outlined,
      label: zh ? '挥手' : 'Wave',
      showLabel: widget.showLabel,
      isLoading: _sending,
      onPressed: supported && !_sending ? _wave : null,
    );
  }
}

/// Host-defined transient event overlay. No server state is inferred from
/// receipt; clients that reconnect do not replay past wave events.
class DemoWaveOverlay extends StatefulWidget {
  const DemoWaveOverlay({super.key, required this.room});
  final RealtimeRoom room;

  @override
  State<DemoWaveOverlay> createState() => _DemoWaveOverlayState();
}

class _DemoWaveOverlayState extends State<DemoWaveOverlay> {
  StreamSubscription<InteractionEvent>? _subscription;
  Timer? _timeout;
  String? _sender;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final interactions = widget.room.interactions;
    if (!interactions.capabilities.canSubscribe) return;
    _subscription = interactions.events.listen((event) {
      if (!mounted || event.topic != DemoWaveInteraction.topic) return;
      _timeout?.cancel();
      setState(() => _sender = event.senderId);
      _timeout = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _sender = null);
      });
    });
  }

  @override
  void didUpdateWidget(covariant DemoWaveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.room, widget.room)) return;
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    _sender = null;
    _subscribe();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sender == null) return const SizedBox.shrink();
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            elevation: 4,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.waving_hand_outlined, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      zh ? '$_sender 挥了挥手' : '$_sender waved',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
