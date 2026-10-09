import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'live_reactions_controller.dart';

class LiveReactionParticle extends StatefulWidget {
  const LiveReactionParticle({super.key, required this.heart});
  final LiveReactionHeart heart;

  @override
  State<LiveReactionParticle> createState() => LiveReactionParticleState();
}

class LiveReactionParticleState extends State<LiveReactionParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, child) {
      final value = _progress.value;
      final yOffset = -value * 220;
      final xOffset = math.sin(value * math.pi * 2) * 16;
      final opacity = (1.0 - value).clamp(0.0, 1.0);
      return Align(
        alignment: Alignment(widget.heart.startX * 2 - 1, 0.85),
        child: Transform.translate(
          offset: Offset(xOffset, yOffset),
          child: Opacity(
            opacity: opacity,
            child: Icon(
              Icons.favorite_rounded,
              size: 26,
              color: widget.heart.color,
            ),
          ),
        ),
      );
    },
  );
}
