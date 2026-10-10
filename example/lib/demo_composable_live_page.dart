import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_background.dart';
import 'widgets/demo_recording_widgets.dart';

/// A broadcast UI assembled entirely by the consuming app.
/// No SDK room template chooses where controls, chat or gifts appear.
class DemoComposableLivePage extends StatefulWidget {
  const DemoComposableLivePage({
    super.key,
    required this.room,
    required this.initialSettings,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  State<DemoComposableLivePage> createState() => _DemoComposableLivePageState();
}

enum _LiveSidePanel { none, chat, members }

class _DemoComposableLivePageState extends State<DemoComposableLivePage> {
  late Future<void> _preparing;
  late final Future<List<MediaBackgroundImagePreset>> _presets;
  _LiveSidePanel _sidePanel = _LiveSidePanel.none;

  @override
  void initState() {
    super.initState();
    _preparing = _prepare();
    _presets = DemoBackground.presets;
  }

  @override
  void didUpdateWidget(covariant DemoComposableLivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.initialSettings != widget.initialSettings) {
      _preparing = _prepare();
      _sidePanel = _LiveSidePanel.none;
    }
  }

  Future<void> _prepare() async {
    await widget.room.prepareVideoEffects(widget.initialSettings);
    // The scoped SDK controller owns the live interaction subscription.
  }

  void _toggle(_LiveSidePanel panel) => setState(() {
    _sidePanel = _sidePanel == panel ? _LiveSidePanel.none : panel;
  });

  Future<bool> _confirmLeave(BuildContext context) async {
    final strings = RealtimeStrings.of(context);
    final host =
        widget.room.media.role == MediaRole.host &&
        widget.room.media.managementCapabilities.closeRoom.supported;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(host ? strings.endLive : strings.leaveRoomTitle),
            content: Text(
              host
                  ? strings.endLiveConfirmation
                  : strings.leaveRoomConfirmation,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(host ? strings.endLive : strings.leave),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _panel() {
    final strings = RealtimeStrings.of(context);
    return RealtimeCard(
      margin: const EdgeInsets.all(8),
      radius: RealtimeUiTokens.cardRadius,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _sidePanel == _LiveSidePanel.chat
                        ? strings.chat
                        : strings.participants,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.closePanel,
                  onPressed: () =>
                      setState(() => _sidePanel = _LiveSidePanel.none),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _sidePanel == _LiveSidePanel.chat
                ? const RealtimeChatPanel()
                : const RealtimeManagedParticipantList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _preparing,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: () => setState(() => _preparing = _prepare()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return RealtimeRoomUiScope(
        room: widget.room,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final isHost = widget.room.media.role != MediaRole.viewer;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.podcasts_rounded),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: RealtimeRoomInfo(),
                            ),
                          ),
                          DemoRecordingBadge(room: widget.room),
                          if (wide) const RealtimeLiveStatus(),
                          const SizedBox(width: 8),
                          RealtimeLeaveButton(
                            onConfirm: _confirmLeave,
                            onLeft: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Stack(
                              children: const [
                                Positioned.fill(
                                  child: RealtimeLiveVideoStage(),
                                ),
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: RealtimeLiveGiftBanner(),
                                ),
                                Positioned(
                                  left: 16,
                                  bottom: 16,
                                  width: 280,
                                  child: IgnorePointer(
                                    child: RealtimeLiveChatFeed(),
                                  ),
                                ),
                                Positioned(
                                  right: 16,
                                  bottom: 68,
                                  child: IgnorePointer(
                                    child: RealtimeLiveHeartsOverlay(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (wide && _sidePanel != _LiveSidePanel.none)
                            SizedBox(width: 330, child: _panel()),
                        ],
                      ),
                    ),
                    if (!wide && _sidePanel != _LiveSidePanel.none)
                      SizedBox(height: 220, child: _panel()),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: RealtimeGlassSurface(
                        radius: RealtimeUiTokens.pillRadius,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!wide) const RealtimeLiveStatus(),
                            if (isHost) ...[
                              const RealtimeMicrophoneButton(),
                              const RealtimeCameraButton(),
                              const RealtimeSwitchCameraButton(),
                              const RealtimeAudioOutputButton(),
                              const RealtimeScreenShareButton(),
                              DemoRecordingButton(room: widget.room),
                              FutureBuilder<List<MediaBackgroundImagePreset>>(
                                future: _presets,
                                builder: (context, snapshot) =>
                                    RealtimeBackgroundEffectsButton(
                                      imagePresets: snapshot.data ?? const [],
                                    ),
                              ),
                            ],
                            const RealtimeLiveLikeButton(),
                            const RealtimeLiveGiftButton(),
                            if (widget.room.chat != null)
                              IconButton(
                                tooltip: RealtimeStrings.of(context).chat,
                                icon: const Icon(Icons.chat_bubble_outline),
                                onPressed: () => _toggle(_LiveSidePanel.chat),
                              ),
                            IconButton(
                              tooltip: RealtimeStrings.of(context).participants,
                              icon: const Icon(Icons.people_outline),
                              onPressed: () => _toggle(_LiveSidePanel.members),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
