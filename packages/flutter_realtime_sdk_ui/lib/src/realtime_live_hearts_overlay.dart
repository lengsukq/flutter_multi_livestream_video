import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'room_ui_controller.dart';

/// Received hearts float away and are removed when their animation ends.
class RealtimeLiveHeartsOverlay extends StatefulWidget {
  const RealtimeLiveHeartsOverlay({super.key});

  @override
  State<RealtimeLiveHeartsOverlay> createState() => _LiveHeartsOverlayState();
}

class _LiveHeartsOverlayState extends State<RealtimeLiveHeartsOverlay> {
  RealtimeRoomUiController? _controller;
  final List<int> _bursts = [];
  int _lastCount = 0;
  int _nextId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = RealtimeRoomUiScope.of(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_onLikes);
    _controller = controller;
    _lastCount = controller.receivedLikeCount;
    _bursts.clear();
    controller.addListener(_onLikes);
  }

  void _onLikes() {
    final count = _controller!.receivedLikeCount;
    final quantity = count - _lastCount;
    _lastCount = count;
    if (quantity <= 0) return;
    setState(() {
      for (var i = 0; i < quantity.clamp(0, 4); i++) {
        _bursts.add(_nextId++);
      }
      if (_bursts.length > 8) _bursts.removeRange(0, _bursts.length - 8);
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onLikes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final id in _bursts)
              _HeartBurst(
                key: ValueKey(id),
                lane: id % 3,
                onComplete: () {
                  if (mounted) setState(() => _bursts.remove(id));
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _HeartBurst extends StatefulWidget {
  const _HeartBurst({super.key, required this.lane, required this.onComplete});
  final int lane;
  final VoidCallback onComplete;

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_animation.isAnimating && _animation.value == 0) {
      final configured = RealtimeUiThemeExtension.of(
        context,
      ).duration(context, const Duration(milliseconds: 1100));
      _reduceMotion = _reduceMotion || configured == Duration.zero;
      _animation.duration = _reduceMotion
          ? const Duration(milliseconds: 300)
          : configured;
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = Curves.easeOut.transform(_animation.value);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: 1 - _animation.value,
            child: Transform.translate(
              offset: _reduceMotion
                  ? Offset.zero
                  : Offset(
                      (widget.lane - 1) * 16 * progress,
                      -(constraints.maxHeight - 36).clamp(0, double.infinity) *
                          progress,
                    ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF375F),
                size: 32,
              ),
            ),
          ),
        );
      },
    ),
  );
}
