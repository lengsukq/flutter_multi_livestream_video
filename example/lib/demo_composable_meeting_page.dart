import 'demo_custom_interaction.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_background.dart';
import 'widgets/demo_cloud_recording_result_dialog.dart';
import 'widgets/demo_recording_widgets.dart';

/// Demo-owned layout: the SDK supplies only stateful functional widgets.
///
/// This page intentionally does not use MediaRoomView or RealtimeRoomView.
/// Apps can replace any Row/Column/Stack here without touching the SDK.
class DemoComposableMeetingPage extends StatefulWidget {
  const DemoComposableMeetingPage({
    super.key,
    required this.room,
    required this.initialSettings,
  });

  final RealtimeRoom room;
  final MediaLocalPreviewSettings initialSettings;

  @override
  State<DemoComposableMeetingPage> createState() =>
      _DemoComposableMeetingPageState();
}

enum _DemoSidePanel { closed, chat, participants, classroom }

class _DemoComposableMeetingPageState extends State<DemoComposableMeetingPage> {
  late Future<void> _videoEffectsReady;
  _DemoSidePanel _panel = _DemoSidePanel.closed;
  bool _recordingBusy = false;

  @override
  void initState() {
    super.initState();
    _videoEffectsReady = _prepare();
  }

  Future<void> _prepare() async {
    await widget.room.prepareVideoEffects(widget.initialSettings);
    await widget.room.sharedContent?.start();
  }

  @override
  void didUpdateWidget(covariant DemoComposableMeetingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.initialSettings != widget.initialSettings) {
      _videoEffectsReady = _prepare();
      _panel = _DemoSidePanel.closed;
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final strings = RealtimeStrings.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.leaveRoomTitle),
            content: Text(strings.leaveRoomConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.leave),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _onLeft() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _openEffects(BuildContext context) async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final presets = await DemoBackground.loadPresets(isZh: zh);
    if (!context.mounted) return;
    final controller = RealtimeRoomUiScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BackgroundEffectSelector(
              capabilities: controller.room.backgroundCapabilities,
              effect: controller.room.backgroundEffect,
              imagePresets: presets,
              busy: controller.isPending(RealtimeRoomUiAction.backgroundEffect),
              onChanged: (effect) async {
                try {
                  await controller.setBackgroundEffect(effect);
                  if (sheetContext.mounted) updateSheet(() {});
                } catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.maybeOf(
                      sheetContext,
                    )?.showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendWave(BuildContext context) async {
    try {
      await widget.room.interactions.publish(DemoWaveInteraction.topic, {
        'sentAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _openClassroomTools(BuildContext context) {
    final classroom = widget.room.classroom;
    if (classroom == null) return;
    unawaited(
      showRealtimeGlassBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: ClassroomToolsPanel(
            classroom: classroom,
            showHeader: true,
            onClose: () => Navigator.maybeOf(sheetContext)?.pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _videoEffectsReady,
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
                  onPressed: () => setState(() {
                    _videoEffectsReady = _prepare();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

      return RealtimeRoomUiScope(
        room: widget.room,
        child: Scaffold(
          backgroundColor: RealtimeUiTokens.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return Column(
                  children: [
                    // iOS style structured navigation row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide ? 240 : 150,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.04),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.meeting_room_outlined,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Flexible(
                                    child: RealtimeRoomInfo(
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (wide) ...[
                            const SizedBox(width: 8),
                            const RealtimeConnectionIndicator(),
                          ],
                          DemoRecordingBadge(room: widget.room),
                          const Spacer(),
                          RealtimeLeaveButton(
                            onConfirm: _confirmLeave,
                            onLeft: _onLeft,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Expanded(child: _DemoMeetingStage()),
                          if (wide && _panel != _DemoSidePanel.closed)
                            SizedBox(width: 330, child: _sidePanel()),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: RealtimeMeetingDock(
                        showLabels: wide,
                        mediaGroup: [
                          RealtimeDockMicrophoneButton(showLabel: wide),
                          RealtimeDockCameraButton(showLabel: wide),
                        ],
                        collaborationGroup: [
                          RealtimeDockSharedContentButton(showLabel: wide),
                          RealtimeDockReactionsButton(
                            showLabel: wide,
                            onWave:
                                widget.room.interactions.capabilities.canPublish
                                ? () => unawaited(_sendWave(context))
                                : null,
                          ),
                        ],
                        panelsGroup: [
                          if (widget.room.chat != null)
                            RealtimeDockItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: RealtimeStrings.of(context).chat,
                              isActive: wide && _panel == _DemoSidePanel.chat,
                              onPressed: () =>
                                  _toggle(_DemoSidePanel.chat, isWide: wide),
                              showLabel: wide,
                            ),
                          RealtimeDockItem(
                            icon: Icons.people_outline_rounded,
                            label: RealtimeStrings.of(context).participants,
                            isActive:
                                wide && _panel == _DemoSidePanel.participants,
                            onPressed: () => _toggle(
                              _DemoSidePanel.participants,
                              isWide: wide,
                            ),
                            showLabel: wide,
                          ),
                          if (widget.room.classroom != null)
                            RealtimeDockItem(
                              icon: Icons.school_outlined,
                              label: RealtimeStrings.of(context).classroom,
                              isActive:
                                  wide && _panel == _DemoSidePanel.classroom,
                              onPressed: () => _toggle(
                                _DemoSidePanel.classroom,
                                isWide: wide,
                              ),
                              showLabel: wide,
                            ),
                          StreamBuilder<RecordingStatus>(
                            stream: widget.room.recordingStatuses,
                            initialData: widget.room.recordingStatus,
                            builder: (context, snapshot) {
                              final recStatus =
                                  snapshot.data ?? RecordingStatus.idle;
                              final isRecording =
                                  recStatus == RecordingStatus.recording;
                              final isZh =
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode ==
                                  'zh';
                              final isCloud =
                                  const {
                                    'livekit',
                                    'trtc',
                                    'agora',
                                    'artc',
                                    'chime',
                                    'ivs',
                                  }.contains(widget.room.engineProviderId) &&
                                  widget.room.featureBackendUrl != null;

                              return RealtimeDockMoreButton(
                                showLabel: wide,
                                hasActiveBadge: isRecording,
                                items: [
                                  RealtimeDockMoreItem(
                                    icon: Icons.cameraswitch_rounded,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).flipCamera,
                                    subtitle: isZh ? '前后切换' : 'Flip',
                                    onTap: () {
                                      final controller = RealtimeRoomUiScope.of(
                                        context,
                                      );
                                      unawaited(controller.switchCamera());
                                    },
                                  ),
                                  RealtimeDockMoreItem(
                                    icon: Icons.blur_on_rounded,
                                    title: RealtimeStrings.of(
                                      context,
                                    ).backgroundEffects,
                                    subtitle: isZh ? '背景特效' : 'Effects',
                                    onTap: () =>
                                        unawaited(_openEffects(context)),
                                  ),
                                  RealtimeDockMoreItem(
                                    icon: isRecording
                                        ? Icons.stop_circle_rounded
                                        : Icons.fiber_manual_record_rounded,
                                    title: isRecording
                                        ? (isZh ? '停止录制' : 'Stop Rec')
                                        : (isZh ? '会议录制' : 'Record'),
                                    subtitle: isRecording
                                        ? (isZh ? '录制中' : 'Recording')
                                        : (isCloud
                                              ? (isZh ? '云端录制' : 'Cloud')
                                              : (isZh
                                                    ? '录制不可用'
                                                    : 'Unavailable')),
                                    isDanger: isRecording,
                                    showBadgeDot: isRecording,
                                    onTap: () =>
                                        unawaited(_handleRecording(context)),
                                  ),
                                  if (isCloud)
                                    RealtimeDockMoreItem(
                                      icon: Icons.cloud_download_rounded,
                                      title: isZh ? '录制结果' : 'Recordings',
                                      subtitle: isZh ? '查看云录像' : 'Files',
                                      onTap: () =>
                                          _showCloudResultDialog(context),
                                    ),
                                  if (widget
                                          .room
                                          .classroom
                                          ?.state
                                          ?.capabilities
                                          .canUseTools ==
                                      true)
                                    RealtimeDockMoreItem(
                                      icon: Icons.build_outlined,
                                      title: RealtimeStrings.of(
                                        context,
                                      ).classroomTools,
                                      subtitle: isZh ? '互动工具' : 'Tools',
                                      onTap: () => _openClassroomTools(context),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                        exitAction: RealtimeDockItem(
                          icon: Icons.call_end_rounded,
                          label: RealtimeStrings.of(context).leave,
                          isDanger: true,
                          onPressed: () async {
                            if (await _confirmLeave(context)) {
                              if (context.mounted) {
                                final controller = RealtimeRoomUiScope.of(
                                  context,
                                );
                                await controller.leave();
                                _onLeft();
                              }
                            }
                          },
                          showLabel: wide,
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

  void _toggle(_DemoSidePanel panel, {required bool isWide}) {
    if (!isWide) {
      _openMobileSheet(panel);
      return;
    }
    setState(() {
      _panel = _panel == panel ? _DemoSidePanel.closed : panel;
    });
  }

  void _openMobileSheet(_DemoSidePanel panel) {
    final strings = RealtimeStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: RealtimeRoomUiScope(
              room: widget.room,
              child: Container(
                height: MediaQuery.of(sheetContext).size.height * 0.72,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (switch (panel) {
                                _DemoSidePanel.chat => const Color(0xFF0284C7),
                                _DemoSidePanel.classroom => const Color(
                                  0xFF8B5CF6,
                                ),
                                _ => const Color(0xFF3B82F6),
                              }).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              switch (panel) {
                                _DemoSidePanel.chat =>
                                  Icons.chat_bubble_outline_rounded,
                                _DemoSidePanel.classroom =>
                                  Icons.school_outlined,
                                _ => Icons.people_outline_rounded,
                              },
                              size: 16,
                              color: switch (panel) {
                                _DemoSidePanel.chat => const Color(0xFF0284C7),
                                _DemoSidePanel.classroom => const Color(
                                  0xFF8B5CF6,
                                ),
                                _ => const Color(0xFF3B82F6),
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            switch (panel) {
                              _DemoSidePanel.chat => strings.chat,
                              _DemoSidePanel.classroom => strings.classroom,
                              _ => strings.participants,
                            },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: switch (panel) {
                        _DemoSidePanel.chat => const RealtimeChatPanel(),
                        _DemoSidePanel.classroom => RealtimeClassroomPanel(
                          showHeader: false,
                          onClose: () => Navigator.pop(sheetContext),
                        ),
                        _ => const RealtimeManagedParticipantList(),
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sidePanel() {
    final strings = RealtimeStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.95)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: (switch (_panel) {
                      _DemoSidePanel.chat => const Color(0xFF0284C7),
                      _DemoSidePanel.classroom => const Color(0xFF8B5CF6),
                      _ => const Color(0xFF3B82F6),
                    }).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    switch (_panel) {
                      _DemoSidePanel.chat => Icons.chat_bubble_outline_rounded,
                      _DemoSidePanel.classroom => Icons.school_outlined,
                      _ => Icons.people_outline_rounded,
                    },
                    size: 16,
                    color: switch (_panel) {
                      _DemoSidePanel.chat => const Color(0xFF0284C7),
                      _DemoSidePanel.classroom => const Color(0xFF8B5CF6),
                      _ => const Color(0xFF3B82F6),
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (_panel) {
                      _DemoSidePanel.chat => strings.chat,
                      _DemoSidePanel.classroom => strings.classroom,
                      _ => strings.participants,
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.closePanel,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _panel = _DemoSidePanel.closed),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: switch (_panel) {
              _DemoSidePanel.chat => const RealtimeChatPanel(),
              _DemoSidePanel.classroom => RealtimeClassroomPanel(
                showHeader: false,
                onClose: () => setState(() => _panel = _DemoSidePanel.closed),
              ),
              _ => const RealtimeManagedParticipantList(),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecording(BuildContext context) async {
    if (_recordingBusy || !mounted) return;
    final isCloud =
        const {
          'livekit',
          'trtc',
          'agora',
          'artc',
          'chime',
          'ivs',
        }.contains(widget.room.engineProviderId) &&
        widget.room.featureBackendUrl != null;

    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    if (!isCloud || !widget.room.media.isLogicalOwner) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            !isCloud
                ? (isZh
                      ? '当前没有可用的云录制后端；本地录制已移除。'
                      : 'Cloud recording is unavailable; local recording was removed.')
                : (isZh
                      ? '只有房主可以操作云录制。'
                      : 'Only the room owner can control cloud recording.'),
          ),
        ),
      );
      return;
    }
    setState(() => _recordingBusy = true);
    try {
      if (widget.room.recordingStatus == RecordingStatus.recording) {
        await widget.room.stopRecording();
        if (!mounted || !context.mounted) return;
        unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
          ),
        );
      } else {
        final chosen = await showDialog<RecordingLayout>(
          context: context,
          builder: (dialogCtx) => SimpleDialog(
            title: Text(isZh ? '选择云端录制布局' : 'Choose Cloud Recording Layout'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogCtx, RecordingLayout.grid),
                child: ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: Text(isZh ? '画廊视图（多画面网格）' : 'Grid Layout'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(dialogCtx, RecordingLayout.speaker),
                child: ListTile(
                  leading: const Icon(Icons.person_pin),
                  title: Text(isZh ? '主讲人视图（大画面聚焦）' : 'Speaker Layout'),
                ),
              ),
            ],
          ),
        );
        if (chosen == null || !mounted) return;
        await widget.room.startRecording(
          RecordingOptions.cloud(layout: chosen),
        );
        if (mounted && context.mounted) {
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              isZh ? '云录制操作失败：$error' : 'Cloud recording failed: $error',
            ),
            duration: const Duration(seconds: 8),
            showCloseIcon: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recordingBusy = false);
    }
  }

  void _showCloudResultDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => DemoCloudRecordingResultDialog(room: widget.room),
      ),
    );
  }
}

class _DemoMeetingStage extends StatelessWidget {
  const _DemoMeetingStage();

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          RealtimeSharedContentStage(
            members: controller.snapshot.contentShareTrack != null
                ? const RealtimeScreenShareStage()
                : const RealtimeVideoGrid(),
          ),
          if (controller.room.classroom != null)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: RealtimeClassroomEventOverlay(
                classroom: controller.room.classroom!,
              ),
            ),
          DemoWaveOverlay(room: controller.room),
        ],
      ),
    );
  }
}
