import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
export 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

RealtimeException mapRealtimeException(Object error, {String? providerId}) =>
    normalizeRealtimeException(error, providerId: providerId);
