import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Owns Demo room discovery, request coalescing and stale-response filtering.
class DemoRoomDirectory extends ChangeNotifier {
  List<MediaRoomSummary> rooms = const [];
  String? error;
  bool _inFlight = false;
  bool _disposed = false;
  bool get loading => _inFlight;

  Future<void> refresh({
    required String url,
    required String Function() currentUrl,
    required Future<List<MediaRoomSummary>> Function() listRooms,
    required String Function(Object error) displayError,
    bool silent = false,
  }) async {
    if (_disposed || _inFlight || url.isEmpty) return;
    _inFlight = true;
    if (!silent && error != null) {
      error = null;
      notifyListeners();
    }
    try {
      final updated = await listRooms();
      if (_disposed || url != currentUrl()) return;
      final changed =
          error != null ||
          rooms.length != updated.length ||
          !rooms.every(
            (room) => updated.any(
              (next) =>
                  next.roomCode == room.roomCode &&
                  next.providerId == room.providerId &&
                  next.engineId == room.engineId &&
                  next.roomMode == room.roomMode &&
                  next.attendeeCount == room.attendeeCount &&
                  next.createdAt == room.createdAt,
            ),
          );
      if (changed) {
        rooms = List.unmodifiable(updated);
        error = null;
        notifyListeners();
      }
    } catch (failure) {
      if (!_disposed && !silent && url == currentUrl()) {
        error = displayError(failure);
        notifyListeners();
      }
    } finally {
      _inFlight = false;
      if (!_disposed && !silent) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
