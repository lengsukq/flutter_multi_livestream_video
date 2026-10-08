import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class LiveGift {
  const LiveGift({required this.id, required this.name, required this.icon});
  final String id, name, icon;
  factory LiveGift.fromJson(Map<String, dynamic> value) => LiveGift(
    id: value['id'] as String,
    name: value['name'] as String,
    icon: value['icon'] as String,
  );
}

class LiveGiftEvent {
  const LiveGiftEvent({
    required this.id,
    required this.sequence,
    required this.userId,
    required this.displayName,
    required this.recipientId,
    required this.giftId,
    required this.quantity,
    required this.timestamp,
  });
  final String id, userId, displayName, recipientId, giftId;
  final int sequence, quantity;
  final DateTime timestamp;
  factory LiveGiftEvent.fromJson(Map<String, dynamic> value) => LiveGiftEvent(
    id: value['id'] as String,
    sequence: value['sequence'] as int,
    userId: value['userId'] as String,
    displayName: value['displayName'] as String,
    recipientId: value['recipientId'] as String,
    giftId: value['giftId'] as String,
    quantity: value['quantity'] as int,
    timestamp: DateTime.parse(value['timestamp'] as String),
  );
}

class LiveInteractionState {
  const LiveInteractionState({
    required this.roomCode,
    required this.revision,
    required this.selfUserId,
    required this.recipientId,
    required this.canSendGift,
    this.catalog = const [],
    this.events = const [],
    this.totals = const {},
  });
  final String roomCode, selfUserId, recipientId;
  final int revision;
  final bool canSendGift;
  final List<LiveGift> catalog;
  final List<LiveGiftEvent> events;
  final Map<String, int> totals;
  factory LiveInteractionState.fromJson(Map<String, dynamic> value) =>
      LiveInteractionState(
        roomCode: value['roomCode'] as String,
        revision: value['revision'] as int,
        selfUserId: value['selfUserId'] as String,
        recipientId: value['recipientId'] as String,
        canSendGift: value['canSendGift'] as bool,
        catalog: List.unmodifiable(
          (value['catalog'] as List).map(
            (g) => LiveGift.fromJson(Map<String, dynamic>.from(g as Map)),
          ),
        ),
        events: List.unmodifiable(
          (value['events'] as List).map(
            (g) => LiveGiftEvent.fromJson(Map<String, dynamic>.from(g as Map)),
          ),
        ),
        totals: Map.unmodifiable((value['totals'] as Map).cast<String, int>()),
      );
}

abstract interface class LiveRevisionTransport {
  Stream<int> get revisions;
  Future<void> publish(int revision);
  Future<void> dispose();
}

abstract interface class LiveInteractionRepository {
  Future<LiveInteractionState> snapshot();

  /// Caller-provided eventId enables safe retries of the same logical gift.
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  });
  void close();
}

class HttpLiveInteractionRepository implements LiveInteractionRepository {
  HttpLiveInteractionRepository({
    required String backendUrl,
    required this.roomCode,
    required this.participantId,
    required this.participantCredential,
    this.tokenProvider,
    http.Client? client,
  }) : _base = Uri.parse(backendUrl),
       _client = client ?? http.Client(),
       _ownsClient = client == null;
  final Uri _base;
  final String roomCode, participantId, participantCredential;
  final FutureOr<String?> Function()? tokenProvider;
  final http.Client _client;
  final bool _ownsClient;
  Future<LiveInteractionState> _post(
    String operation,
    Map<String, Object?> data,
  ) async {
    final bearer = await tokenProvider?.call();
    final uri = _base.replace(
      path:
          '${_base.path.replaceFirst(RegExp(r'/$'), '')}/rooms/${Uri.encodeComponent(roomCode)}/live/$operation',
    );
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (bearer != null && bearer.isNotEmpty)
              'Authorization': 'Bearer $bearer',
          },
          body: jsonEncode({
            'requesterParticipantId': participantId,
            'participantCredential': participantCredential,
            ...data,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError(
        'Live interaction failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
    return LiveInteractionState.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  @override
  Future<LiveInteractionState> snapshot() => _post('snapshot', {});
  @override
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  }) => _post('gift', {
    'giftId': giftId,
    'quantity': quantity,
    'eventId': eventId,
  });
  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Gifts are demonstration events; this contract does not debit money or points.
class LiveInteractionSession {
  LiveInteractionSession(
    this.repository, {
    this.pollInterval = const Duration(seconds: 2),
    this.revisionTransport,
  });
  final LiveInteractionRepository repository;
  final Duration pollInterval;
  final LiveRevisionTransport? revisionTransport;
  final _states = StreamController<LiveInteractionState>.broadcast();
  final _events = StreamController<LiveGiftEvent>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  static final _random = Random.secure();
  LiveInteractionState? _state;
  bool _disposed = false;
  Timer? _timer;
  StreamSubscription<int>? _hints;
  Future<void>? _pending;
  Timer? _automaticRefreshTimer;
  bool _automaticRefreshRequested = false;
  LiveInteractionState? get state => _state;
  Stream<LiveInteractionState> get states => _states.stream;
  Stream<LiveGiftEvent> get events => _events.stream;
  Stream<Object> get errors => _errors.stream;
  String newEventId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  Future<void> start() async {
    if (_disposed) throw StateError('Live interactions disposed');
    _hints ??= revisionTransport?.revisions.listen(
      (revision) {
        if (revision > (_state?.revision ?? -1)) _requestAutomaticRefresh();
      },
      onError: (Object error) {
        if (!_disposed) _errors.add(error);
      },
    );
    _timer ??= Timer.periodic(pollInterval, (_) => _requestAutomaticRefresh());
    await refresh();
  }

  void _requestAutomaticRefresh() {
    if (_disposed) return;
    _automaticRefreshRequested = true;
    _drainAutomaticRefresh();
  }

  void _drainAutomaticRefresh() {
    if (_disposed ||
        !_automaticRefreshRequested ||
        _pending != null ||
        _automaticRefreshTimer != null) {
      return;
    }
    unawaited(
      refresh().catchError((Object error) {
        if (!_disposed) _errors.add(error);
      }),
    );
  }

  /// Explicit reads bypass the automatic cooldown; all reads share one flight.
  Future<void> refresh() {
    if (_disposed) {
      return Future.error(StateError('Live interactions disposed'));
    }
    if (_pending != null) return _pending!;
    _automaticRefreshRequested = false;
    _automaticRefreshTimer?.cancel();
    _automaticRefreshTimer = Timer(const Duration(seconds: 1), () {
      _automaticRefreshTimer = null;
      _drainAutomaticRefresh();
    });
    return _pending = _reload().whenComplete(() {
      _pending = null;
      _drainAutomaticRefresh();
    });
  }

  Future<void> _reload() async {
    _setState(await repository.snapshot());
  }

  void _setState(LiveInteractionState next) {
    if (_disposed || (_state != null && next.revision < _state!.revision)) {
      return;
    }
    final previous = _state;
    _state = next;
    if (previous != null) {
      for (final event in next.events) {
        if (event.sequence > previous.revision) _events.add(event);
      }
    }
    _states.add(next);
  }

  Future<void> sendGift(
    String giftId, {
    int quantity = 1,
    String? eventId,
  }) async {
    if (_disposed) throw StateError('Live interactions disposed');
    if (quantity < 1 || quantity > 99) {
      throw RangeError.range(quantity, 1, 99, 'quantity');
    }
    if (_state == null) await start();
    if (_state?.canSendGift != true) throw StateError('The host is offline');
    _setState(
      await repository.sendGift(
        giftId,
        quantity,
        eventId: eventId ?? newEventId(),
      ),
    );
    if (_disposed) return;
    try {
      await revisionTransport?.publish(_state!.revision);
    } catch (e) {
      if (!_disposed) _errors.add(e);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _automaticRefreshTimer?.cancel();
    _automaticRefreshRequested = false;
    await _hints?.cancel();
    try {
      await _pending;
    } catch (_) {
      /* In-flight errors were reported to the caller. */
    }
    await revisionTransport?.dispose();
    repository.close();
    await _states.close();
    await _events.close();
    await _errors.close();
  }
}
