import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

enum RealtimeExperience { meeting, live, chat }

enum RealtimeAction { create, join }

class RealtimeUser {
  const RealtimeUser({
    required this.id,
    required this.name,
    this.deviceId,
  });

  final String id;
  final String name;
  final String? deviceId;

  RealtimeUser normalized() {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    final normalizedDeviceId = deviceId?.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    return RealtimeUser(
      id: normalizedId,
      name: normalizedName,
      deviceId: normalizedDeviceId == null || normalizedDeviceId.isEmpty
          ? null
          : normalizedDeviceId,
    );
  }

  MediaIdentity toMediaIdentity() => MediaIdentity(
    userId: id,
    displayName: name,
    deviceId: deviceId,
  ).normalized();
}

class RealtimeCredentials {
  const RealtimeCredentials({
    required this.providerId,
    required this.payload,
  });

  final String providerId;
  final Map<String, dynamic> payload;
}

typedef RealtimeChatCredentialProvider = Future<RealtimeCredentials> Function();

sealed class RealtimeSource {
  const RealtimeSource();

  const factory RealtimeSource.backend() = RealtimeBackendSource;

  const factory RealtimeSource.credentials({
    RealtimeCredentials? media,
    RealtimeCredentials? chat,
    RealtimeChatCredentialProvider? chatCredentialProvider,
  }) = RealtimeCredentialsSource;
}

class RealtimeBackendSource extends RealtimeSource {
  const RealtimeBackendSource();
}

class RealtimeCredentialsSource extends RealtimeSource {
  const RealtimeCredentialsSource({
    this.media,
    this.chat,
    this.chatCredentialProvider,
  });

  final RealtimeCredentials? media;
  final RealtimeCredentials? chat;
  final RealtimeChatCredentialProvider? chatCredentialProvider;
}

class RealtimeRequest {
  const RealtimeRequest._({
    required this.action,
    required this.experience,
    required this.user,
    required this.source,
    this.roomCode,
    this.roomOwnerCredential,
    this.mediaRole,
    this.chatRole,
  });

  factory RealtimeRequest.create({
    required RealtimeExperience type,
    required RealtimeUser user,
    String? roomCode,
    String? roomOwnerCredential,
    RealtimeSource source = const RealtimeSource.backend(),
    MediaRole? mediaRole,
    ChatRole? chatRole,
  }) => RealtimeRequest._(
    action: RealtimeAction.create,
    experience: type,
    user: user,
    roomCode: roomCode,
    roomOwnerCredential: roomOwnerCredential,
    source: source,
    mediaRole: mediaRole,
    chatRole: chatRole,
  );

  factory RealtimeRequest.join({
    required RealtimeExperience type,
    required RealtimeUser user,
    String? roomCode,
    String? roomOwnerCredential,
    RealtimeSource source = const RealtimeSource.backend(),
    MediaRole? mediaRole,
    ChatRole? chatRole,
  }) => RealtimeRequest._(
    action: RealtimeAction.join,
    experience: type,
    user: user,
    roomCode: roomCode,
    roomOwnerCredential: roomOwnerCredential,
    source: source,
    mediaRole: mediaRole,
    chatRole: chatRole,
  );

  final RealtimeAction action;
  final RealtimeExperience experience;
  final RealtimeUser user;
  final String? roomCode;
  final String? roomOwnerCredential;
  final RealtimeSource source;
  final MediaRole? mediaRole;
  final ChatRole? chatRole;
}
