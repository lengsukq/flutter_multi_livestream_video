/// Coarse, provider-neutral network quality.
enum MediaNetworkQuality { unknown, excellent, good, fair, poor, bad, down }

/// Latest connection statistics exposed by a provider.
///
/// Every metric is optional because RTC vendors expose different subsets.
class MediaConnectionStats {
  const MediaConnectionStats({
    required this.timestampMs,
    this.upstreamQuality = MediaNetworkQuality.unknown,
    this.downstreamQuality = MediaNetworkQuality.unknown,
    this.rttMs,
    this.uplinkPacketLossPercent,
    this.downlinkPacketLossPercent,
    this.uploadKbps,
    this.downloadKbps,
    this.jitterMs,
  });

  final int timestampMs;
  final MediaNetworkQuality upstreamQuality;
  final MediaNetworkQuality downstreamQuality;
  final int? rttMs;
  final double? uplinkPacketLossPercent;
  final double? downlinkPacketLossPercent;
  final int? uploadKbps;
  final int? downloadKbps;
  final int? jitterMs;

  MediaConnectionStats copyWith({
    int? timestampMs,
    MediaNetworkQuality? upstreamQuality,
    MediaNetworkQuality? downstreamQuality,
    int? rttMs,
    double? uplinkPacketLossPercent,
    double? downlinkPacketLossPercent,
    int? uploadKbps,
    int? downloadKbps,
    int? jitterMs,
  }) => MediaConnectionStats(
    timestampMs: timestampMs ?? this.timestampMs,
    upstreamQuality: upstreamQuality ?? this.upstreamQuality,
    downstreamQuality: downstreamQuality ?? this.downstreamQuality,
    rttMs: rttMs ?? this.rttMs,
    uplinkPacketLossPercent:
        uplinkPacketLossPercent ?? this.uplinkPacketLossPercent,
    downlinkPacketLossPercent:
        downlinkPacketLossPercent ?? this.downlinkPacketLossPercent,
    uploadKbps: uploadKbps ?? this.uploadKbps,
    downloadKbps: downloadKbps ?? this.downloadKbps,
    jitterMs: jitterMs ?? this.jitterMs,
  );
}
