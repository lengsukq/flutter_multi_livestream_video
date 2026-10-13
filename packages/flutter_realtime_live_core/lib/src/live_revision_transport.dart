import 'dart:async';

abstract interface class LiveRevisionTransport {
  Stream<int> get revisions;
  Future<void> publish(int revision);
  Future<void> dispose();
}
