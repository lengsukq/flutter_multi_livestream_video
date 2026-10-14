import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

/// Stable application identity used independently from provider participant ids.
class MediaIdentity {
  const MediaIdentity({
    required this.userId,
    required this.displayName,
    this.deviceId,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? deviceId;
  final String? avatarUrl;

  MediaIdentity normalized() {
    final id = userId.trim();
    final name = displayName.trim();
    final avatar = RealtimeAvatarUrl.tryParse(avatarUrl);
    if (avatarUrl?.trim().isNotEmpty == true && avatar == null) {
      throw ArgumentError.value(
        avatarUrl,
        'avatarUrl',
        'must be an HTTP(S) image URL',
      );
    }
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
      avatarUrl: avatar,
      deviceId: deviceId?.trim().isEmpty ?? true ? null : deviceId!.trim(),
    );
  }
}
