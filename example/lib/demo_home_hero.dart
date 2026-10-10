import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Presentational only: no room operations, timers or SDK sessions.
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
  Widget build(BuildContext context) =>
      compact ? _buildCompactHeader(context) : _buildHeader(context);

  /// The full feature hero is for tablets and desktops. On phones the primary
  /// task is getting into a room, so keep branding and backend diagnostics
  /// readable without pushing the join controls below the first screen.
  Widget _buildCompactHeader(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = DemoStrings.of(context);
    final provider = mediaProviderId == null
        ? strings.unconfigured
        : mediaProviderDisplayName(mediaProviderId!);
    final chat = chatProviderId == null
        ? strings.unconfigured
        : strings.chatProviderDisplayName(chatProviderId!);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.primarySubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.video_call_rounded,
                  size: 23,
                  color: style.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realtime Media',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                    Text(
                      strings.appSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: style.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                online == true
                    ? Icons.check_circle_rounded
                    : online == false
                    ? Icons.error_outline_rounded
                    : Icons.circle_outlined,
                color: online == true
                    ? style.success
                    : online == false
                    ? style.danger
                    : style.textMuted,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  testingServer
                      ? strings.checking
                      : '${strings.videoProviderLabel}: $provider  ·  ${strings.chatProviderLabel}: $chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = DemoStrings.of(context);
    final mediaName = testingServer
        ? strings.checking
        : mediaProviderId == null
        ? strings.unconfigured
        : mediaProviderDisplayName(mediaProviderId!);
    final chatName = testingServer
        ? strings.checking
        : chatProviderId == null
        ? strings.unconfigured
        : strings.chatProviderDisplayName(chatProviderId!);

    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.sheetRadius,
      opacity: 0.90,
      blur: RealtimeUiTokens.blur,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: style.primarySubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  border: Border.all(color: style.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: style.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      strings.workspaceEyebrow,
                      style: TextStyle(
                        color: style.primary,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Realtime Media',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: style.primary,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.workspaceTitle,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.2,
              color: style.text,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.workspaceDescription,
            style: TextStyle(
              color: style.textMuted,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroFeature(
                context,
                Icons.groups_2_outlined,
                strings.workspaceMeetings,
              ),
              _heroFeature(
                context,
                Icons.sensors_rounded,
                strings.workspaceLive,
              ),
              _heroFeature(
                context,
                Icons.chat_bubble_outline_rounded,
                strings.workspaceChat,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: style.border),
          const SizedBox(height: 10),
          Text(
            strings.appSubtitle,
            style: TextStyle(
              color: style.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RealtimePill(
                label: '${strings.videoProviderLabel} · $mediaName',
                icon: Icons.videocam_outlined,
                foreground: style.primary,
                background: style.primarySubtle,
                borderColor: style.primaryBorder,
              ),
              RealtimePill(
                label: '${strings.chatProviderLabel} · $chatName',
                icon: Icons.forum_outlined,
                foreground: style.primary,
                background: style.primarySubtle,
                borderColor: style.primaryBorder,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroFeature(BuildContext context, IconData icon, String label) {
    final style = RealtimeStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style.surfaceSubtle,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: style.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: style.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
