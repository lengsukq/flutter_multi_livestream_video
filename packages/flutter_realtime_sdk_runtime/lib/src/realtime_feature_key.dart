/// A typed room feature identity. IDs are unique within a runtime.
class RealtimeFeatureKey<T extends Object> {
  const RealtimeFeatureKey(this.id);
  final String id;
  Type get valueType => T;
}
