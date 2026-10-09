import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

class LiveGift {
  const LiveGift({required this.id, required this.name, required this.icon});
  final String id, name, icon;
  factory LiveGift.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => LiveGift._fromJsonUnchecked(value));
  factory LiveGift._fromJsonUnchecked(Map<String, dynamic> value) => LiveGift(
    id: JsonReader(value).required<String>('id'),
    name: JsonReader(value).required<String>('name'),
    icon: JsonReader(value).required<String>('icon'),
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
  factory LiveGiftEvent.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => LiveGiftEvent._fromJsonUnchecked(value));
  factory LiveGiftEvent._fromJsonUnchecked(Map<String, dynamic> value) =>
      LiveGiftEvent(
        id: JsonReader(value).required<String>('id'),
        sequence: JsonReader(value).required<int>('sequence'),
        userId: JsonReader(value).required<String>('userId'),
        displayName: JsonReader(value).required<String>('displayName'),
        recipientId: JsonReader(value).required<String>('recipientId'),
        giftId: JsonReader(value).required<String>('giftId'),
        quantity: JsonReader(value).required<int>('quantity'),
        timestamp: JsonReader(value).dateTime('timestamp'),
      );
}

/// A confirmed room-wide like, keyed by the shared interaction revision.
class LiveLikeEvent {
  const LiveLikeEvent({
    required this.id,
    required this.sequence,
    required this.userId,
    required this.quantity,
    required this.timestamp,
  });
  final String id, userId;
  final int sequence, quantity;
  final DateTime timestamp;

  factory LiveLikeEvent.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(
        () => LiveLikeEvent(
          id: JsonReader(value).required<String>('id'),
          sequence: JsonReader(value).required<int>('sequence'),
          userId: JsonReader(value).required<String>('userId'),
          quantity: JsonReader(value).required<int>('quantity'),
          timestamp: JsonReader(value).dateTime('timestamp'),
        ),
      );
}

class LiveInteractionState {
  LiveInteractionState({
    required this.roomCode,
    required this.revision,
    required this.selfUserId,
    required this.recipientId,
    required this.canSendGift,
    List<LiveGift> catalog = const [],
    List<LiveGiftEvent> events = const [],
    List<LiveLikeEvent> likeEvents = const [],
    this.totalLikes = 0,
    Map<String, int> totals = const {},
  }) : catalog = List.unmodifiable(catalog),
       events = List.unmodifiable(events),
       likeEvents = List.unmodifiable(likeEvents),
       totals = Map.unmodifiable(totals);
  final String roomCode, selfUserId, recipientId;
  final int revision;
  final bool canSendGift;
  final List<LiveGift> catalog;
  final List<LiveGiftEvent> events;
  final List<LiveLikeEvent> likeEvents;
  final int totalLikes;
  final Map<String, int> totals;
  factory LiveInteractionState.fromJson(Map<String, dynamic> value) =>
      JsonReader(
        value,
      ).decode(() => LiveInteractionState._fromJsonUnchecked(value));
  factory LiveInteractionState._fromJsonUnchecked(Map<String, dynamic> value) =>
      LiveInteractionState(
        roomCode: JsonReader(value).required<String>('roomCode'),
        revision: JsonReader(value).required<int>('revision'),
        selfUserId: JsonReader(value).required<String>('selfUserId'),
        recipientId: JsonReader(value).required<String>('recipientId'),
        canSendGift: JsonReader(value).required<bool>('canSendGift'),
        catalog: JsonReader(
          value,
        ).objects('catalog', LiveGift.fromJson, optional: false),
        events: JsonReader(
          value,
        ).objects('events', LiveGiftEvent.fromJson, optional: false),
        likeEvents: JsonReader(
          value,
        ).objects('likeEvents', LiveLikeEvent.fromJson, optional: true),
        totalLikes: (value['totalLikes'] as int?) ?? 0,
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
  Future<LiveInteractionState> sendLike({required String eventId});
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
    this.requestTimeout = const Duration(seconds: 10),
  }) : _base = Uri.parse(backendUrl),
       _executor = RealtimeHttpExecutor(client: client);
  final Uri _base;
  final String roomCode, participantId, participantCredential;
  final FutureOr<String?> Function()? tokenProvider;
  final RealtimeHttpExecutor _executor;
  final Duration requestTimeout;
  Future<LiveInteractionState> _post(
    String operation,
    Map<String, Object?> data,
  ) async {
    final json = await _executor.request(
      method: 'POST',
      uri: _base.replace(
        path:
            '${_base.path.replaceFirst(RegExp(r"/$"), "")}/rooms/${Uri.encodeComponent(roomCode)}/live/$operation',
      ),
      timeout: requestTimeout,
      domain: 'live',
      headers: () async {
        final bearer = await tokenProvider?.call();
        return {
          'Content-Type': 'application/json',
          if (bearer != null && bearer.isNotEmpty)
            'Authorization': 'Bearer $bearer',
        };
      },
      body: {
        'requesterParticipantId': participantId,
        'participantCredential': participantCredential,
        ...data,
      },
    );
    return JsonReader(json).decode(() => LiveInteractionState.fromJson(json));
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
  Future<LiveInteractionState> sendLike({required String eventId}) =>
      _post('like', {'eventId': eventId});
  @override
  void close() {
    _executor.close();
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
  final _likes = StreamController<LiveLikeEvent>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  static final _random = Random.secure();
  LiveInteractionState? _state;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);
  Timer? _timer;
  StreamSubscription<int>? _hints;
  Future<void>? _pending;
  Timer? _automaticRefreshTimer;
  bool _automaticRefreshRequested = false;
  LiveInteractionState? get state => _state;
  Stream<LiveInteractionState> get states => _states.stream;
  Stream<LiveGiftEvent> get events => _events.stream;
  Stream<LiveLikeEvent> get likes => _likes.stream;
  Stream<Object> get errors => _errors.stream;
  String newEventId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  Future<void> start() async {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Live interactions disposed',
      );
    }
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
      return Future.error(
        const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Live interactions disposed',
        ),
      );
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
    try {
      _setState(await repository.snapshot());
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'live',
          operation: 'snapshot',
          stackTrace: stack,
        ),
        stack,
      );
    }
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
      for (final event in next.likeEvents) {
        if (event.sequence > previous.revision) _likes.add(event);
      }
    }
    _states.add(next);
  }

  Future<void> sendGift(
    String giftId, {
    int quantity = 1,
    String? eventId,
  }) async {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Live interactions disposed',
      );
    }
    if (quantity < 1 || quantity > 99) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Gift quantity must be between 1 and 99.',
        domain: 'live',
        operation: 'sendGift',
      );
    }
    if (_state == null) await start();
    if (_state?.canSendGift != true) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The host is offline',
      );
    }
    try {
      _setState(
        await repository.sendGift(
          giftId,
          quantity,
          eventId: eventId ?? newEventId(),
        ),
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'live',
          operation: 'sendGift',
          stackTrace: stack,
        ),
        stack,
      );
    }
    if (_disposed) return;
    try {
      await revisionTransport?.publish(_state!.revision);
    } catch (e) {
      if (!_disposed) _errors.add(e);
    }
  }

  /// Send one authenticated like. Retrying with the same event ID is safe.
  Future<void> sendLike({String? eventId}) async {
    if (_disposed) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Live interactions disposed',
      );
    }
    if (_state == null) await start();
    try {
      _setState(await repository.sendLike(eventId: eventId ?? newEventId()));
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'live',
          operation: 'sendLike',
          stackTrace: stack,
        ),
        stack,
      );
    }
    if (_disposed) return;
    try {
      await revisionTransport?.publish(_state!.revision);
    } catch (error) {
      if (!_disposed) _errors.add(error);
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('poll.timer', () async {
      _timer?.cancel();
    });
    await cleanup.run('refresh.timer', () async {
      _automaticRefreshTimer?.cancel();
      _automaticRefreshRequested = false;
    });
    await cleanup.run('revision.subscription', () async {
      await _hints?.cancel();
    });
    await cleanup.run('refresh.pending', () async {
      try {
        await _pending;
      } catch (_) {
        /* The refresh caller receives its failure. */
      }
    });
    await cleanup.run('revision.transport', () async {
      await revisionTransport?.dispose();
    });
    await cleanup.run('repository', () async {
      repository.close();
    });
    await cleanup.run('states', () async {
      await _states.close();
    });
    await cleanup.run('events', () async {
      await _events.close();
    });
    await cleanup.run('likes', () async {
      await _likes.close();
    });
    await cleanup.run('errors', () async {
      await _errors.close();
    });
    cleanup.finish(domain: 'live');
  }
}
