import 'dart:async';

import 'package:flutter_realtime_media_ui/src/live_reactions_controller.dart';
import 'package:flutter_realtime_media_ui/src/live_likes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Likes implements LiveLikesController {
  final _incoming = StreamController<int>.broadcast();
  final _totals = StreamController<int>.broadcast();
  int current = 3;
  int sends = 0;

  @override
  int get totalLikes => current;
  @override
  Stream<int> get receivedLikes => _incoming.stream;
  @override
  Stream<int> get totals => _totals.stream;
  @override
  Future<void> sendLike() async => sends++;
  void receive(int count) => _incoming.add(count);
  void update(int total) => _totals.add(total);
  Future<void> dispose() async {
    await _incoming.close();
    await _totals.close();
  }
}

void main() {
  test('reaction ownership, provider replacement and dispose', () async {
    final first = _Likes();
    final next = _Likes();
    final subject = LiveReactionsController();
    subject.bind(first);
    expect(subject.totalLikes, 3);
    await subject.sendLike();
    expect(first.sends, 1);
    first.update(7);
    first.receive(9);
    await Future<void>.delayed(Duration.zero);
    expect(subject.totalLikes, 7);
    expect(subject.hearts, hasLength(5));

    subject.bind(next);
    expect(subject.hearts, isEmpty);
    expect(subject.totalLikes, 3);
    first.update(90);
    first.receive(7);
    await Future<void>.delayed(Duration.zero);
    expect(subject.totalLikes, 3);
    expect(subject.hearts, isEmpty);

    subject.dispose();
    next.receive(2);
    next.update(12);
    await Future<void>.delayed(Duration.zero);
    expect(first.sends, 1);
    await first.dispose();
    await next.dispose();
  });
}
