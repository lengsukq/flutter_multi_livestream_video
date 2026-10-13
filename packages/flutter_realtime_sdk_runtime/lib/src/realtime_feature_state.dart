import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

sealed class RealtimeFeatureState {
  const RealtimeFeatureState();
}

final class RealtimeFeatureRegistered extends RealtimeFeatureState {
  const RealtimeFeatureRegistered();
}

final class RealtimeFeatureAttaching extends RealtimeFeatureState {
  const RealtimeFeatureAttaching();
}

final class RealtimeFeatureAttached extends RealtimeFeatureState {
  const RealtimeFeatureAttached();
}

final class RealtimeFeatureStarting extends RealtimeFeatureState {
  const RealtimeFeatureStarting();
}

final class RealtimeFeatureReady extends RealtimeFeatureState {
  const RealtimeFeatureReady();
}

final class RealtimeFeatureUnavailable extends RealtimeFeatureState {
  const RealtimeFeatureUnavailable();
}

final class RealtimeFeatureFailed extends RealtimeFeatureState {
  const RealtimeFeatureFailed(this.error);
  final RealtimeException error;
}

final class RealtimeFeatureDisposed extends RealtimeFeatureState {
  const RealtimeFeatureDisposed();
}
