import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'demo_identity_store.dart';
import 'demo_room_flow.dart';

enum DemoRoomEntryKind { create, join }

enum DemoJoinFormError { backendMissing, roomCodeMissing, invalidRoomCode }

enum DemoEntryPhase { idle, preparing, preJoin }

sealed class DemoJoinPreparation {
  const DemoJoinPreparation();
}

final class DemoJoinRejected extends DemoJoinPreparation {
  const DemoJoinRejected(this.reason);
  final DemoJoinFormError reason;
}

final class DemoJoinFailed extends DemoJoinPreparation {
  const DemoJoinFailed(this.error);
  final RealtimeException error;
}

final class DemoJoinPrepared extends DemoJoinPreparation {
  const DemoJoinPrepared(this.entry);
  final DemoPreparedRoomEntry entry;
}

/// Immutable input for the SDK's Pre-Join and subsequent connection.
class DemoPreparedRoomEntry {
  const DemoPreparedRoomEntry({
    required this.realtime,
    required this.kind,
    required this.user,
    required this.mode,
    required this.role,
    required this.roomCode,
    required this.flow,
  });
  final Realtime realtime;
  final DemoRoomEntryKind kind;
  final RealtimeUser user;
  final MediaRoomMode mode;
  final MediaRole role;
  final String? roomCode;
  final DemoRoomFlow flow;
  Future<RealtimeConnection> connect() => switch (kind) {
    DemoRoomEntryKind.create => flow.create(
      mode: mode,
      deviceId: user.id,
      displayName: user.name,
      avatarUrl: user.avatarUrl,
      roomCode: roomCode,
    ),
    DemoRoomEntryKind.join => flow.join(
      code: roomCode!,
      mode: mode,
      deviceId: user.id,
      displayName: user.name,
      avatarUrl: user.avatarUrl,
    ),
  };
}

/// Form preparation and identity integration only. Provider choice, permissions
/// and domain behavior stay in the SDK/server. Routes own opened connections.
class DemoJoinCoordinator {
  DemoJoinCoordinator(this.identity);
  final DemoIdentityStore identity;
  late final Future<String> deviceId = identity.loadDeviceId();
  final Map<String, Map<String, String>> _authorityByBackend = {};
  Future<String> loadDisplayName() async =>
      identity.loadDisplayName(await deviceId);
  Future<DemoJoinPreparation> prepare({
    required DemoRoomEntryKind kind,
    required String backendUrl,
    required String code,
    required String displayName,
    String? avatarUrl,
    required MediaRoomMode mode,
    required Realtime Function(String) createRealtime,
  }) async {
    final backend = backendUrl.trim();
    final roomCode = code.trim();
    if (backend.isEmpty) {
      return const DemoJoinRejected(DemoJoinFormError.backendMissing);
    }
    if (kind == DemoRoomEntryKind.join && roomCode.isEmpty) {
      return const DemoJoinRejected(DemoJoinFormError.roomCodeMissing);
    }
    if (kind == DemoRoomEntryKind.create &&
        roomCode.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(roomCode)) {
      return const DemoJoinRejected(DemoJoinFormError.invalidRoomCode);
    }
    try {
      final id = await deviceId;
      final name = displayName.trim().isEmpty
          ? identity.defaultDisplayName(id)
          : displayName.trim();
      final user = RealtimeUser(
        id: id,
        name: name,
        deviceId: id,
        avatarUrl: avatarUrl,
      ).normalized();
      await identity.saveDisplayName(name);
      if (avatarUrl != null) await identity.saveAvatarUrl(user.avatarUrl ?? '');
      final realtime = createRealtime(backend);
      return DemoJoinPrepared(
        DemoPreparedRoomEntry(
          realtime: realtime,
          kind: kind,
          user: user,
          mode: mode,
          role: mode == MediaRoomMode.broadcast
              ? (kind == DemoRoomEntryKind.create
                    ? MediaRole.host
                    : MediaRole.viewer)
              : MediaRole.participant,
          roomCode: roomCode.isEmpty ? null : roomCode,
          flow: DemoRoomFlow(
            open: realtime.open,
            ownerCredentials: _authorityByBackend.putIfAbsent(
              backend,
              () => {},
            ),
          ),
        ),
      );
    } catch (error, stack) {
      return DemoJoinFailed(
        normalizeRealtimeException(
          error,
          domain: 'demo.entry',
          operation: 'prepare',
          stackTrace: stack,
        ),
      );
    }
  }
}
