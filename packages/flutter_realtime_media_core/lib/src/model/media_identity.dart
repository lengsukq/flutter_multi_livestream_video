/// Stable application identity used independently from provider participant ids.
class MediaIdentity {
  const MediaIdentity({
    required this.userId,
    required this.displayName,
    this.deviceId,
  });

  final String userId;
  final String displayName;
  final String? deviceId;

  MediaIdentity normalized() {
    final id = userId.trim();
    final name = displayName.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'must not be empty',
      );
    }
    return MediaIdentity(
      userId: id,
      displayName: name,
      deviceId: deviceId?.trim().isEmpty ?? true ? null : deviceId!.trim(),
    );
  }
}
