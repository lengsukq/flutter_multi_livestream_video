/// Optional low-latency hint transport. Revision hints are never trusted as
/// state or teacher authorization; only the repository's snapshot is used.
abstract interface class ClassroomRevisionTransport {
  Stream<int> get revisions;
  Future<void> publish(int revision);
  Future<void> dispose();
}
