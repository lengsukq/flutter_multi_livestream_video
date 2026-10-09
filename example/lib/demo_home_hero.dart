import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

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
                  borderRadius: BorderRadius.circular(12),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF15254D), Color(0xFF284995), Color(0xFF3866AC)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -85,
              right: -100,
              child: SizedBox(
                width: 290,
                height: 290,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x184BDDE8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: -100,
              left: -100,
              child: SizedBox(
                width: 230,
                height: 230,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x15FFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF91E6F6),
                        size: 17,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          strings.workspaceEyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC8E5FF),
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 27),
                  const Text(
                    'Realtime Media',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC8E5FF),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.workspaceTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.17,
                      color: Colors.white,
                      fontSize: 31,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.workspaceDescription,
                    style: const TextStyle(
                      color: Color(0xFFE2ECFE),
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _heroFeature(
                        Icons.groups_2_outlined,
                        strings.workspaceMeetings,
                      ),
                      _heroFeature(
                        Icons.sensors_rounded,
                        strings.workspaceLive,
                      ),
                      _heroFeature(
                        Icons.chat_bubble_outline_rounded,
                        strings.workspaceChat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 29),
                  const Divider(color: Color(0x40FFFFFF)),
                  const SizedBox(height: 10),
                  Text(
                    strings.appSubtitle,
                    style: const TextStyle(
                      color: Color(0xFFC8E5FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RealtimePill(
                        label: '${strings.videoProviderLabel} · $mediaName',
                        icon: Icons.videocam_outlined,
                        foreground: RealtimeUiTokens.primary,
                        background: Colors.white,
                      ),
                      RealtimePill(
                        label: '${strings.chatProviderLabel} · $chatName',
                        icon: Icons.forum_outlined,
                        foreground: RealtimeUiTokens.primary,
                        background: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFeature(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Colors.white.withValues(alpha: .2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
