import 'dart:async';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_classroom_ui/src/classroom_command_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unmounted command still reports failure to its host', () async {
    final gate = Completer<void>();
    final failures = <RealtimeException>[];
    var notifications = 0;
    final presenter = ClassroomCommandPresenter(
      onChanged: () => notifications++,
      onError: failures.add,
    );
    final operation = presenter.run(() => gate.future);
    presenter.dispose();
    gate.completeError(StateError('private provider response'));
    await operation;
    expect(notifications, 1);
    expect(failures, hasLength(1));
    expect(
      failures.single.message,
      isNot(contains('private provider response')),
    );
  });

  test('a pending tool does not hold up an unrelated tool', () async {
    final gate = Completer<void>();
    final first = ClassroomCommandPresenter(onChanged: () {}, onError: (_) {});
    final second = ClassroomCommandPresenter(onChanged: () {}, onError: (_) {});
    final pending = first.run(() => gate.future);
    var completed = false;
    await second.run(() async {
      completed = true;
    });
    expect(completed, isTrue);
    expect(first.pending, isTrue);
    gate.complete();
    await pending;
    first.dispose();
    second.dispose();
  });
}
