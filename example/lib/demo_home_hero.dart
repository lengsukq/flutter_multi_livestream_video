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
      key: const ValueKey('demo-home-hero'),
      padding: EdgeInsets.fromLTRB(0, compact ? 4 : 10, 0, compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: style.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.workspaceEyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: bodyFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color: style.textSecondary,
                  ),
                ),
              ),
              Tooltip(
                message: statusText,
                child: _OnlineDot(online: online, testingServer: testingServer),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            strings.workspaceTitle,
            style: TextStyle(
              fontFamily: displayFamily,
              fontSize: compact ? 25 : 31,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.65,
              height: 1.16,
              color: style.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.workspaceDescription,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: bodyFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: style.textMuted,
            ),
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
