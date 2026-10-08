import 'dart:async';
import 'package:flutter/material.dart';
import 'realtime_ui_style.dart';

/// An independently invalidated room region. Video widgets are outside these
/// boundaries, so timers, member requests and reactions never rebuild tracks.
class RoomRegion extends StatelessWidget {
  const RoomRegion({super.key, required this.revision, required this.builder});
  final ValueNotifier<int> revision;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: revision,
    builder: (context, _, child) => builder(context),
  );
}

class RoomElapsedPill extends StatefulWidget {
  const RoomElapsedPill({super.key});
  @override
  State<RoomElapsedPill> createState() => _RoomElapsedPillState();
}

class _RoomElapsedPillState extends State<RoomElapsedPill> {
  final _elapsed = Stopwatch();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _elapsed.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _elapsed.elapsed.inSeconds;
    return RealtimePill(
      label:
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
      leadingDotColor: seconds.isEven
          ? const Color(0xFF10B981)
          : const Color(0xFF34D399),
    );
  }
}

class RoomWaitingPulse extends StatefulWidget {
  const RoomWaitingPulse({super.key, required this.child});
  final Widget child;
  @override
  State<RoomWaitingPulse> createState() => _RoomWaitingPulseState();
}

class _RoomWaitingPulseState extends State<RoomWaitingPulse> {
  Timer? _timer;
  bool _bright = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _bright = !_bright),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 600),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RealtimeUiTokens.primaryGradient,
      boxShadow: [
        BoxShadow(
          color: RealtimeUiTokens.primary.withValues(
            alpha: _bright ? .32 : .16,
          ),
          blurRadius: _bright ? 24 : 14,
          spreadRadius: _bright ? 3 : 0,
        ),
      ],
    ),
    child: widget.child,
  );
}
