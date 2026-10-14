part of '../flutter_realtime_design_ui.dart';

class RealtimeSegmentTab<T> {
  const RealtimeSegmentTab({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int? badge;
}
