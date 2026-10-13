import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

sealed class RealtimePreJoinState {
  const RealtimePreJoinState();
}

final class RealtimePreJoinIdle extends RealtimePreJoinState {
  const RealtimePreJoinIdle();
}

final class RealtimePreJoinChecking extends RealtimePreJoinState {
  const RealtimePreJoinChecking();
}

final class RealtimePreJoinReady extends RealtimePreJoinState {
  const RealtimePreJoinReady();
}

final class RealtimePreJoinEntering extends RealtimePreJoinState {
  const RealtimePreJoinEntering();
}

final class RealtimePreJoinCancelling extends RealtimePreJoinState {
  const RealtimePreJoinCancelling();
}

final class RealtimePreJoinFailed extends RealtimePreJoinState {
  const RealtimePreJoinFailed(this.error);
  final RealtimeException error;
}
