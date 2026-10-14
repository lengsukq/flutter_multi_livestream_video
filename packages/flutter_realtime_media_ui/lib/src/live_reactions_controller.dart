import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'live_likes_controller.dart';

/// Immutable visual event; providers only supply the number of reactions.
class LiveReactionHeart {
  const LiveReactionHeart({
    required this.id,
    required this.color,
    required this.startX,
  });

  final String id;
  final Color color;
  final double startX;
}

/// Owns live reaction subscriptions and transient animation timers.
///
/// This is independent of the room widget. In particular it never owns or
/// disposes the provider's [LiveLikesController].
class LiveReactionsController {
  final revision = ValueNotifier<int>(0);
  final totalsRevision = ValueNotifier<int>(0);
  final List<LiveReactionHeart> _hearts = [];
  final Set<Timer> _timers = {};
  StreamSubscription<int>? _received;
  StreamSubscription<int>? _totals;
  LiveLikesController? _provider;
  bool _disposed = false;
  int _generation = 0;
  int _totalLikes = 0;

  int get totalLikes => _totalLikes;
  List<LiveReactionHeart> get hearts => List.unmodifiable(_hearts);

  void bind(LiveLikesController? provider) {
    if (_disposed) return;
    final generation = ++_generation;
    unawaited(_received?.cancel());
    unawaited(_totals?.cancel());
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _hearts.clear();
    revision.value++;
    _provider = provider;
    _totalLikes = provider?.totalLikes ?? 0;
    totalsRevision.value++;
    if (provider == null) return;

    _received = provider.receivedLikes.listen((count) {
      if (_disposed || generation != _generation) return;
      for (var index = 0; index < count.clamp(0, 5); index++) {
        _animateHeart();
      }
    });
    _totals = provider.totals.listen((count) {
      if (_disposed || generation != _generation) return;
      _totalLikes = count;
      totalsRevision.value++;
    });
  }

  Future<void> sendLike() async {
    final provider = _provider;
    if (!_disposed && provider != null) await provider.sendLike();
  }

  void _animateHeart() {
    final random = Random();
    const colors = [
      Color(0xFFEF4444),
      Color(0xFFF43F5E),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF1D1D1F),
    ];
    final heart = LiveReactionHeart(
      id: '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1000)}',
      color: colors[random.nextInt(colors.length)],
      startX: 0.65 + random.nextDouble() * 0.25,
    );
    _hearts.add(heart);
    revision.value++;
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 1600), () {
      _timers.remove(timer);
      if (_disposed) return;
      _hearts.removeWhere((item) => item.id == heart.id);
      revision.value++;
    });
    _timers.add(timer);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    unawaited(_received?.cancel());
    unawaited(_totals?.cancel());
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _hearts.clear();
    revision.dispose();
    totalsRevision.dispose();
  }
}
