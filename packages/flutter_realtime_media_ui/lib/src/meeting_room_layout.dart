import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'realtime_ui_style.dart';

class MeetingRoomViewLayout extends StatelessWidget {
  const MeetingRoomViewLayout({
    super.key,
    required this.constraints,
    required this.panelOpen,
    required this.participantsOpen,
    required this.topBar,
    required this.header,
    required this.connectionBanner,
    required this.errorBanner,
    required this.stage,
    required this.sidePanel,
    required this.rtcData,
    required this.dock,
  });
  final BoxConstraints constraints;
  final bool panelOpen;
  final bool participantsOpen;
  final Widget topBar;
  final Widget? header;
  final Widget? connectionBanner;
  final Widget errorBanner;
  final Widget stage;
  final Widget sidePanel;
  final Widget? rtcData;
  final Widget dock;
  @override
  Widget build(BuildContext context) {
    final wide =
        constraints.maxWidth >= 1000 &&
        MediaQuery.textScalerOf(context).scale(17) < 28;
    final medium = constraints.maxWidth >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RealtimeAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              topBar,
              if (header != null) header!,
              if (connectionBanner != null) connectionBanner!,
              errorBanner,
              Expanded(
                child: wide
                    ? _buildWideStage(context, panelOpen)
                    : medium
                    ? _buildMediumStage(panelOpen, constraints)
                    : _buildCompactStage(context, panelOpen, constraints),
              ),
              if (rtcData != null) rtcData!,
              dock,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideStage(BuildContext context, bool panelOpen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: stage),
        if (panelOpen)
          SizedBox(
            key: ValueKey(
              participantsOpen
                  ? 'meeting-participants-wide'
                  : 'meeting-chat-wide',
            ),
            width: 340,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiThemeExtension.of(
                context,
              ).duration(context, RealtimeUiTokens.animNormal),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset((1 - progress) * 16, 0),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: sidePanel,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediumStage(bool panelOpen, BoxConstraints constraints) {
    return Stack(
      fit: StackFit.expand,
      children: [
        stage,
        if (panelOpen)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              key: ValueKey(
                participantsOpen
                    ? 'meeting-participants-medium'
                    : 'meeting-chat-medium',
              ),
              width: math.min(360, constraints.maxWidth * .56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: sidePanel,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactStage(
    BuildContext context,
    bool panelOpen,
    BoxConstraints constraints,
  ) {
    final maxChatHeight = math.max(160.0, constraints.maxHeight - 140);
    final desiredChatHeight = (constraints.maxHeight * .45).clamp(180.0, 380.0);
    final chatHeight = math.min(desiredChatHeight, maxChatHeight);

    return Column(
      children: [
        Expanded(child: stage),
        if (panelOpen)
          SizedBox(
            key: ValueKey(
              participantsOpen
                  ? 'meeting-participants-compact'
                  : 'meeting-chat-compact',
            ),
            height: chatHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: RealtimeUiThemeExtension.of(
                context,
              ).duration(context, RealtimeUiTokens.animNormal),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Opacity(
                opacity: progress,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 14),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                child: sidePanel,
              ),
            ),
          ),
      ],
    );
  }
}

/// Meeting top status bar.
