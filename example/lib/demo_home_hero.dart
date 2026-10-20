import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Editorial workspace heading directly styled after Tandem Green Room.
/// Follows Bricolage Grotesque h1 + Onest lede + Tandem pill metadata.
class DemoHomeHero extends StatelessWidget {
  const DemoHomeHero({
    super.key,
    required this.compact,
    required this.mediaProviderId,
    required this.chatProviderId,
    required this.online,
    required this.testingServer,
  });

  final bool compact;
  final String? mediaProviderId;
  final String? chatProviderId;
  final bool? online;
  final bool testingServer;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final DemoStrings strings = DemoStrings.of(context);
    final String mediaName = testingServer
        ? strings.checking
        : mediaProviderId == null
        ? strings.unconfigured
        : mediaProviderDisplayName(mediaProviderId!);
    final String chatName = testingServer
        ? strings.checking
        : chatProviderId == null
        ? strings.unconfigured
        : strings.chatProviderDisplayName(chatProviderId!);
    final String statusText =
        '${strings.videoProviderLabel}: $mediaName · ${strings.chatProviderLabel}: $chatName';

    final displayFamily = RealtimeFonts.displayOf(context);
    final bodyFamily = RealtimeFonts.bodyOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(0, compact ? 4 : 8, 0, compact ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tandem status pill
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!compact)
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: style.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: style.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: style.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.workspaceEyebrow,
                        style: TextStyle(
                          fontFamily: bodyFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: style.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              _OnlineDot(online: online, testingServer: testingServer),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          // Tandem h1: font: 700 clamp(26px,3.2vw,38px)/1.1 "Bricolage Grotesque"
          Text(
            strings.workspaceTitle,
            style: TextStyle(
              fontFamily: displayFamily,
              fontSize: compact ? 26 : 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.12,
              color: style.text,
            ),
          ),
          const SizedBox(height: 8),
          // Tandem lede: color: var(--muted); font: 400 14px/1.45 "Onest"
          Text(
            strings.workspaceDescription,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: bodyFamily,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: style.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          // Metadata status line with cloud icon
          Row(
            children: [
              Icon(
                Icons.cloud_done_rounded,
                size: 15,
                color: style.textMuted,
                semanticLabel: 'Server status',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: bodyFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: style.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tandem online indicator with dot + label
class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.online, required this.testingServer});

  final bool? online;
  final bool testingServer;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = DemoStrings.of(context);
    final bool isOnline = online == true;
    final bool isOffline = online == false;
    final String label = testingServer
        ? strings.checking
        : isOnline
        ? 'Ready'
        : isOffline
        ? 'Offline'
        : 'Standby';
    final Color dot = isOnline
        ? style.speak
        : isOffline
        ? style.danger
        : style.textMuted;
    return Semantics(
      label: 'Server $label',
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: style.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: RealtimeFonts.bodyOf(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isOnline
                    ? style.speakStrong
                    : isOffline
                    ? style.danger
                    : style.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
