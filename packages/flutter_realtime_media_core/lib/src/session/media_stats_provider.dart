import '../model/media_connection_stats.dart';
import 'media_session.dart';

/// Optional surface for providers that expose RTC network statistics.
abstract interface class MediaStatsProvider {
  MediaConnectionStats? get connectionStats;
  Stream<MediaConnectionStats> get stats;
}

extension MediaSessionStats on MediaSession {
  MediaConnectionStats? get connectionStats {
    final current = this;
    return current is MediaStatsProvider
        ? (current as MediaStatsProvider).connectionStats
        : null;
  }

  Stream<MediaConnectionStats> get stats {
    final current = this;
    return current is MediaStatsProvider
        ? (current as MediaStatsProvider).stats
        : const Stream<MediaConnectionStats>.empty();
  }
}
