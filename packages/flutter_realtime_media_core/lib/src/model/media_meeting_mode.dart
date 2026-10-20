/// Product policy within an interactive meeting, independent of its provider.
enum MediaMeetingMode {
  standard,
  classroom;

  /// Missing metadata preserves the classroom policy of earlier backends.
  static MediaMeetingMode fromMetadata(Map<String, Object?> metadata) =>
      metadata['meetingMode'] == 'standard' ? standard : classroom;
}
