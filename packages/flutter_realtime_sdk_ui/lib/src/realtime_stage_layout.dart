import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Shared size-class breakpoints for stage layouts (reference-image mapping).
///
/// Layout follows available width, never device type or orientation
/// (Apple HIG Layout › Size classes). Compact stacks video-first with
/// overlays; regular/expanded use leading info + center stage.
abstract final class RealtimeStageBreakpoints {
  static const double compactMaxWidth = 600;
  static const double expandedMinWidth = 980;

  static bool isCompact(double width) => width < compactMaxWidth;
  static bool isExpanded(double width) => width >= expandedMinWidth;
  static bool isRegular(double width) =>
      width >= compactMaxWidth && width < expandedMinWidth;
}

/// Single signal badge for live content: dot + label + optional duration.
///
/// The dot is never the only carrier (label always present) and the
/// duration uses tabular figures so digits do not jitter.
class RealtimeLiveBadge extends StatelessWidget {
  const RealtimeLiveBadge({super.key, this.duration, this.label = 'LIVE'});

  final Duration? duration;
  final String label;

  static String formatDuration(Duration value) {
    final int totalSeconds = value.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: duration == null ? label : '$label ${formatDuration(duration!)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: RealtimeUiTokens.appleCrimson,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            if (duration != null) ...[
              const SizedBox(width: 6),
              Text(
                formatDuration(duration!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
            // Keep text legible even if a caller places the badge on light art.
            if (theme.brightness == Brightness.light) const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

/// Opaque leading info panel shared by Home featured card, Pre-Join info
/// column and Live desktop left column (reference-image left panel).
///
/// Content layer stays opaque; glass is reserved for floating controls over
/// video. Exactly one prominent action per instance.
class RealtimeFeaturedLiveCard extends StatelessWidget {
  const RealtimeFeaturedLiveCard({
    super.key,
    required this.title,
    required this.hostName,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.statusText,
    this.isLive = true,
  });

  final String title;
  final String hostName;
  final String description;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? statusText;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    return RealtimeCardSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: RealtimeUiTokens.appleCrimson,
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              if (statusText != null) ...[
                if (isLive) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            hostName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: Text(primaryLabel),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 44),
                ),
                child: Text(secondaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
