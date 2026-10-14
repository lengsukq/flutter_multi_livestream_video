import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Apple-styled home header using the reference-image leading-info structure.
///
/// Opaque content layer (no glass stacking): eyebrow + title + subtitle +
/// description + a single provider-status row. All entry actions live in the
/// join/create form below, keeping one job per element.
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

    return RealtimeCardSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              if (!compact)
                Text(
                  strings.workspaceEyebrow,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              _OnlineDot(online: online, testingServer: testingServer),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            strings.workspaceTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.appSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            strings.workspaceDescription,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.cloud_done_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Server status',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status indicator with dot + text (never color alone).
class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.online, required this.testingServer});

  final bool? online;
  final bool testingServer;

  @override
  Widget build(BuildContext context) {
    final DemoStrings strings = DemoStrings.of(context);
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
        ? RealtimeUiTokens.appleSuccess
        : isOffline
        ? RealtimeUiTokens.appleDanger
        : Theme.of(context).disabledColor;
    return Semantics(
      label: 'Server $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
