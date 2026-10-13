import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

class LiveRoomViewLayout extends StatelessWidget {
  const LiveRoomViewLayout({
    super.key,
    required this.constraints,
    required this.cleanScreen,
    required this.onCleanScreen,
    required this.onLike,
    required this.stage,
    required this.hearts,
    required this.topBar,
    required this.header,
    required this.connectionBanner,
    required this.danmaku,
    required this.dock,
  });
  final BoxConstraints constraints;
  final bool cleanScreen;
  final VoidCallback onCleanScreen;
  final VoidCallback onLike;
  final Widget stage;
  final Widget hearts;
  final Widget topBar;
  final Widget? header;
  final Widget? connectionBanner;
  final Widget danmaku;
  final Widget dock;
  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cleanScreen) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: RealtimeAmbientBackground(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onCleanScreen,
            child: Stack(
              fit: StackFit.expand,
              children: [
                stage,
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: RealtimePill(
                      label: strings.exitCleanScreen,
                      icon: Icons.fullscreen_exit_rounded,
                      foreground: isDark ? Colors.white : RealtimeUiTokens.text,
                      background: isDark
                          ? Colors.black.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.85),
                      borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : RealtimeUiTokens.border,
                      onTap: onCleanScreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RealtimeAmbientBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fullscreen Video Canvas with tap-to-like
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLike,
              onDoubleTap: () {
                onLike();
                onLike();
              },
              child: stage,
            ),

            // 2. Top Scrim Gradient for text contrast
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.black.withValues(alpha: 0.70),
                              Colors.transparent,
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.70),
                              Colors.transparent,
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Bottom Scrim Gradient for danmaku & control contrast
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 260,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ]
                          : [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.85),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // 4. Floating Hearts Particle Layer
            Positioned.fill(child: hearts),

            // 5. HUD Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: topBar),
            ),

            // 6. Header extension if supplied
            if (header != null)
              Positioned(
                top: 70,
                left: 12,
                right: 12,
                child: SafeArea(top: false, child: header!),
              ),

            // 7. Connection Banner
            if (connectionBanner != null)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: connectionBanner!,
              ),

            // 8. Bottom-Left Floating Danmaku Stream
            Positioned(
              left: 14,
              bottom: 84 + MediaQuery.viewInsetsOf(context).bottom,
              width: math.min(320.0, constraints.maxWidth * 0.72),
              child: danmaku,
            ),

            // 9. Bottom Interaction Dock
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: dock,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating live top bar with anchor capsule, viewer count, and close button.
