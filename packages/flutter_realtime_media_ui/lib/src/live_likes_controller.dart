/// Provider-independent contract for room-wide live reactions.
///
/// The media UI does not depend on a specific chat, RTC, or backend provider.
abstract interface class LiveLikesController {
  int get totalLikes;
  Stream<int> get totals;
  Stream<int> get receivedLikes;
  Future<void> sendLike();
}
