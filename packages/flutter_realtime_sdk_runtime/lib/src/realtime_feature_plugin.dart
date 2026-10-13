import 'dart:async';
import 'realtime_feature_context.dart';
import 'realtime_feature_key.dart';

/// A typed, optional, room-scoped feature with an explicit resource owner.
abstract class RealtimeFeaturePlugin<T extends Object> {
  const RealtimeFeaturePlugin();
  RealtimeFeatureKey<T> get key;
  String get id => key.id;
  List<RealtimeFeatureKey<Object>> get requiredFeatures => const [];
  FutureOr<T?> attach(RealtimeFeatureContext context);
  FutureOr<void> start(T feature) {}
  FutureOr<void> detach(T feature);
}
