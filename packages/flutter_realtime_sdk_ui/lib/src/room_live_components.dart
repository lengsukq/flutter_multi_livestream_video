import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';

import 'room_ui_controller.dart';
import 'room_media_components.dart';
import 'room_control_components.dart';

/// Only renders the broadcaster; audience members are roster entries.
class RealtimeLiveVideoStage extends StatelessWidget {
  const RealtimeLiveVideoStage({
    super.key,
    this.placeholder,
    this.fit,
    this.showNameTag = false,
  });

  final Widget? placeholder;
  final BoxFit? fit;
  final bool showNameTag;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final members = snapshot.participants;
        final localHost = controller.room.media.role == MediaRole.host;
        final MediaParticipant? host = localHost
            ? (members.where((p) => p.isLocal).firstOrNull ??
                  members
                      .where((p) => p.id == snapshot.localParticipantId)
                      .firstOrNull ??
                  MediaParticipant(
                    id: controller.room.media.participantId,
                    displayName: controller.room.media.participantId,
                    isLocal: true,
                    isVideoEnabled: snapshot.localVideoEnabled,
                  ))
            : (members
                      .where(
                        (p) =>
                            !p.isLocal &&
                            (p.isVideoEnabled || p.videoTrack != null),
                      )
                      .firstOrNull ??
                  members.where((p) => !p.isLocal).firstOrNull);
        if (host == null) {
          return placeholder ??
              const Center(child: Icon(Icons.videocam_off_outlined, size: 56));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final effectiveFit =
                fit ??
                (constraints.maxHeight > constraints.maxWidth
                    ? BoxFit.cover
                    : BoxFit.contain);
            return RealtimeVideoTile(
              key: ValueKey(host.id),
              participant: host,
              showNameTag: showNameTag,
              borderless: true,
              fit: effectiveFit,
            );
          },
        );
      },
    );
  }
}

/// A short floating chat feed for live broadcasts. No room layout is imposed.
/// The same chat messages are available separately in RealtimeChatPanel.
class RealtimeLiveChatFeed extends StatelessWidget {
  const RealtimeLiveChatFeed({super.key, this.maxMessages = 5});

  final int maxMessages;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.chat == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.messages;
        final count = messages.length < maxMessages
            ? messages.length
            : maxMessages;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var index = messages.length - count;
              index < messages.length;
              index++
            )
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${messages[index].displayName.isEmpty ? messages[index].userId : messages[index].displayName}: ${messages[index].message}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Live gift control usable in a toolbar, side panel or floating overlay.
/// The provider-neutral SDK session retains gift retry/idempotency semantics.
class RealtimeLiveGiftButton extends StatelessWidget {
  const RealtimeLiveGiftButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final session = RealtimeRoomUiScope.of(context).room.liveInteractions;
    if (session == null) return const SizedBox.shrink();
    return LiveGiftControlButton(
      key: ObjectKey(session),
      session: session,
      showLabel: showLabel,
    );
  }
}

/// A live gift ticker without any fixed Stack position.
class RealtimeLiveGiftBanner extends StatelessWidget {
  const RealtimeLiveGiftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = RealtimeRoomUiScope.of(context).room.liveInteractions;
    return session == null
        ? const SizedBox.shrink()
        : LiveGiftBanner(key: ObjectKey(session), session: session);
  }
}

/// Like counter and send button. Shared controller prevents duplicate sends.
class RealtimeLiveLikeButton extends StatelessWidget {
  const RealtimeLiveLikeButton({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.liveInteractions == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pending = controller.isPending(RealtimeRoomUiAction.liveLike);
        final likes = controller.liveState?.totalLikes ?? 0;
        final isZh = RealtimeStrings.of(context).isZh;

        Future<void> sendLike() async {
          try {
            await controller.sendLiveLike();
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        }

        if (iconOnly) {
          return Tooltip(
            message: '${isZh ? '点赞' : 'Like'} $likes',
            child: InkWell(
              onTap: pending ? null : sendLike,
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFFFF5252)],
                  ),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2D55).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.favorite_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    if (likes > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        likes > 999 ? '999+' : '$likes',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return FilledButton.tonalIcon(
          onPressed: pending ? null : sendLike,
          icon: pending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.favorite_rounded),
          label: Text('${isZh ? '点赞' : 'Like'} $likes'),
        );
      },
    );
  }
}

/// Optional live status chip: caller decides where it sits in the page.
class RealtimeLiveStatus extends StatelessWidget {
  const RealtimeLiveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isViewer = controller.room.media.role == MediaRole.viewer;
        return Chip(
          avatar: Icon(
            isViewer ? Icons.visibility_outlined : Icons.sensors,
            size: 16,
          ),
          label: Text(
            '${isViewer ? (strings.isZh ? '观看中' : 'Watching') : strings.liveStatus} · ${controller.snapshot.participants.length}',
          ),
        );
      },
    );
  }
}

/// Displays a short-lived heart for each confirmed live-like update.
/// Animations belong to this widget, while one shared controller owns events.
class RealtimeLiveHeartsOverlay extends StatelessWidget {
  const RealtimeLiveHeartsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    if (controller.room.liveInteractions == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 1100),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.8),
              end: const Offset(0, -1.5),
            ).animate(animation),
            child: child,
          ),
        ),
        child: controller.receivedLikeCount == 0
            ? const SizedBox.shrink(key: ValueKey(0))
            : Icon(
                Icons.favorite,
                key: ValueKey(controller.receivedLikeCount),
                color: Colors.pinkAccent,
                size: 32,
              ),
      ),
    );
  }
}

/// Host tools panel providing quick access to camera flip, virtual background,
/// screen sharing, audio output routing and custom host extensions.
class RealtimeHostToolsPanel extends StatefulWidget {
  const RealtimeHostToolsPanel({
    super.key,
    this.showHeader = false,
    this.onClose,
    this.imagePresets = const [],
    this.imagePresetsFuture,
    this.extraTools = const [],
  });

  final bool showHeader;
  final VoidCallback? onClose;
  final List<MediaBackgroundImagePreset> imagePresets;
  final Future<List<MediaBackgroundImagePreset>>? imagePresetsFuture;
  final List<Widget> extraTools;

  @override
  State<RealtimeHostToolsPanel> createState() => _RealtimeHostToolsPanelState();
}

class _RealtimeHostToolsPanelState extends State<RealtimeHostToolsPanel> {
  List<MediaBackgroundImagePreset> _presets = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _presets = widget.imagePresets;
    if (widget.imagePresetsFuture != null) {
      unawaited(
        widget.imagePresetsFuture!
            .then((presets) {
              if (mounted) setState(() => _presets = presets);
            })
            .catchError((Object err) {
              if (mounted) setState(() => _error = err);
            }),
      );
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeHostToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePresetsFuture != oldWidget.imagePresetsFuture &&
        widget.imagePresetsFuture != null) {
      unawaited(
        widget.imagePresetsFuture!
            .then((presets) {
              if (mounted) setState(() => _presets = presets);
            })
            .catchError((Object err) {
              if (mounted) setState(() => _error = err);
            }),
      );
    } else if (widget.imagePresets != oldWidget.imagePresets) {
      setState(() => _presets = widget.imagePresets);
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required RealtimeStyle style,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: style.textMuted),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: style.textMuted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _effectDescription(
    MediaBackgroundEffect effect,
    RealtimeStrings strings,
  ) {
    final isZh = strings.isZh;
    return switch (effect.type) {
      MediaBackgroundEffectType.none => isZh ? '未开启特效' : 'None',
      MediaBackgroundEffectType.blur => isZh ? '已开启背景虚化' : 'Blur active',
      MediaBackgroundEffectType.replaceImage =>
        isZh ? '已应用自定义背景' : 'Custom image',
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    final isZh = strings.isZh;
    final style = RealtimeStyle.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        final isHost = controller.room.media.role == MediaRole.host;

        return Column(
          children: [
            if (widget.showHeader) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: style.primarySubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(color: style.primaryBorder),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: style.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            isZh ? '主播工具' : 'Host Tools',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: style.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RealtimePill(
                            label: isZh ? '主播控制台' : 'Broadcaster',
                            foreground: isHost
                                ? style.primary
                                : style.textMuted,
                            background: isHost
                                ? style.primarySubtle
                                : style.surfaceSubtle,
                            borderColor: isHost
                                ? style.primaryBorder
                                : style.border,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: style.textMuted,
                      splashRadius: 18,
                      onPressed:
                          widget.onClose ??
                          () => Navigator.maybeOf(context)?.pop(),
                    ),
                  ],
                ),
              ),
              Divider(color: style.border, height: 1),
            ],
            if (controller.isPending(RealtimeRoomUiAction.backgroundEffect) ||
                controller.isPending(RealtimeRoomUiAction.screenShare) ||
                controller.isPending(RealtimeRoomUiAction.switchCamera) ||
                controller.isPending(RealtimeRoomUiAction.audioOutput))
              LinearProgressIndicator(
                minHeight: 2,
                color: style.primary,
                backgroundColor: style.primarySubtle,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: style.dangerSubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(
                          color: style.danger.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: style.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_error',
                              style: TextStyle(
                                color: style.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Section 1: Video & Camera
                  _buildSectionHeader(
                    icon: Icons.videocam_outlined,
                    title: isZh ? '画面与镜头' : 'Video & Camera',
                    style: style,
                  ),

                  // 1.1 Camera switch
                  RealtimeCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    radius: RealtimeUiTokens.cardRadius,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: RealtimeUiTokens.iosBlue.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.compactRadius,
                            ),
                            border: Border.all(
                              color: RealtimeUiTokens.iosBlue.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.cameraswitch_outlined,
                            size: 19,
                            color: RealtimeUiTokens.iosBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isZh ? '翻转摄像头' : 'Switch Camera',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: style.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isZh
                                    ? '切换前置与后置镜头拍摄视角'
                                    : 'Toggle between front and rear cameras',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: style.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: style.primary,
                            side: BorderSide(color: style.primaryBorder),
                            backgroundColor: style.primarySubtle,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                RealtimeUiTokens.compactRadius,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: Text(
                            isZh ? '翻转' : 'Switch',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed:
                              controller.canSwitchCamera &&
                                  !controller.isPending(
                                    RealtimeRoomUiAction.switchCamera,
                                  )
                              ? () async {
                                  try {
                                    await controller.switchCamera();
                                  } catch (err) {
                                    if (mounted) {
                                      setState(() => _error = err);
                                    }
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // 1.2 Screen share
                  RealtimeCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    radius: RealtimeUiTokens.cardRadius,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: RealtimeUiTokens.iosTeal.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.compactRadius,
                            ),
                            border: Border.all(
                              color: RealtimeUiTokens.iosTeal.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Icon(
                            snapshot.localScreenShareEnabled
                                ? Icons.stop_screen_share_rounded
                                : Icons.screen_share_outlined,
                            size: 19,
                            color: RealtimeUiTokens.iosTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isZh ? '屏幕共享' : 'Screen Share',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: style.text,
                                    ),
                                  ),
                                  if (snapshot.localScreenShareEnabled) ...[
                                    const SizedBox(width: 6),
                                    RealtimePill(
                                      label: isZh ? '共享中' : 'Sharing',
                                      foreground: RealtimeUiTokens.iosGreen,
                                      background: RealtimeUiTokens.iosGreen
                                          .withValues(alpha: 0.12),
                                      borderColor: RealtimeUiTokens.iosGreen
                                          .withValues(alpha: 0.25),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                snapshot.localScreenShareEnabled
                                    ? (isZh
                                          ? '正在向全场观众共享屏幕内容'
                                          : 'Streaming screen to audience')
                                    : (isZh
                                          ? '将当前屏幕画面推流给观众'
                                          : 'Share your screen with viewers'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: style.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: snapshot.localScreenShareEnabled
                                ? style.danger
                                : style.primary,
                            side: BorderSide(
                              color: snapshot.localScreenShareEnabled
                                  ? style.danger.withValues(alpha: 0.35)
                                  : style.primaryBorder,
                            ),
                            backgroundColor: snapshot.localScreenShareEnabled
                                ? style.dangerSubtle
                                : style.primarySubtle,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                RealtimeUiTokens.compactRadius,
                              ),
                            ),
                          ),
                          icon: Icon(
                            snapshot.localScreenShareEnabled
                                ? Icons.stop_circle_outlined
                                : Icons.play_arrow_rounded,
                            size: 16,
                          ),
                          label: Text(
                            snapshot.localScreenShareEnabled
                                ? (isZh ? '停止' : 'Stop')
                                : (isZh ? '开启' : 'Start'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed:
                              controller.canShareScreen &&
                                  !controller.isPending(
                                    RealtimeRoomUiAction.screenShare,
                                  )
                              ? () async {
                                  try {
                                    await controller.toggleScreenShare();
                                  } catch (err) {
                                    if (mounted) {
                                      setState(() => _error = err);
                                    }
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // 1.3 Virtual Background Effects
                  if (controller.room.backgroundCapabilities.isSupported)
                    RealtimeCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      radius: RealtimeUiTokens.cardRadius,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: RealtimeUiTokens.iosIndigo.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    RealtimeUiTokens.compactRadius,
                                  ),
                                  border: Border.all(
                                    color: RealtimeUiTokens.iosIndigo
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.blur_on_rounded,
                                  size: 19,
                                  color: RealtimeUiTokens.iosIndigo,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      strings.backgroundEffects,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: style.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _effectDescription(
                                        controller.room.backgroundEffect,
                                        strings,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: style.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BackgroundEffectSelector(
                            capabilities:
                                controller.room.backgroundCapabilities,
                            effect: controller.room.backgroundEffect,
                            imagePresets: _presets,
                            busy: controller.isPending(
                              RealtimeRoomUiAction.backgroundEffect,
                            ),
                            onChanged: (effect) async {
                              try {
                                await controller.setBackgroundEffect(effect);
                              } catch (err) {
                                if (mounted) setState(() => _error = err);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Section 2: Audio & Output
                  _buildSectionHeader(
                    icon: Icons.volume_up_outlined,
                    title: isZh ? '音频与设备' : 'Audio & Devices',
                    style: style,
                  ),

                  // 2.1 Audio Output
                  if (controller.canListAudioOutputs)
                    RealtimeCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      radius: RealtimeUiTokens.cardRadius,
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: RealtimeUiTokens.iosOrange.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(
                                RealtimeUiTokens.compactRadius,
                              ),
                              border: Border.all(
                                color: RealtimeUiTokens.iosOrange.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.speaker_outlined,
                              size: 19,
                              color: RealtimeUiTokens.iosOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isZh ? '音频输出' : 'Audio Output',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: style.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isZh
                                      ? '选择扬声器、听筒或蓝牙设备'
                                      : 'Select speaker, earphone or bluetooth',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: style.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const RealtimeAudioOutputButton(),
                        ],
                      ),
                    ),

                  // 2.2 Microphone devices
                  if (controller.canListMediaDevices(
                    MediaDeviceKind.microphone,
                  ))
                    RealtimeCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      radius: RealtimeUiTokens.cardRadius,
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: RealtimeUiTokens.iosTeal.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(
                                RealtimeUiTokens.compactRadius,
                              ),
                              border: Border.all(
                                color: RealtimeUiTokens.iosTeal.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.mic_none_rounded,
                              size: 19,
                              color: RealtimeUiTokens.iosTeal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isZh ? '麦克风设备' : 'Microphone Device',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: style.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isZh
                                      ? '切换不同的拾音麦克风设备'
                                      : 'Select microphone input device',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: style.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const RealtimeMediaDevicePicker(
                            kind: MediaDeviceKind.microphone,
                          ),
                        ],
                      ),
                    ),

                  // Section 3: Extensions / Recording
                  if (widget.extraTools.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildSectionHeader(
                      icon: Icons.extension_outlined,
                      title: isZh ? '扩展功能' : 'Extensions',
                      style: style,
                    ),
                    RealtimeCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      radius: RealtimeUiTokens.cardRadius,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: widget.extraTools,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper method to open the unified live host tools bottom sheet.
Future<void> showRealtimeHostToolsBottomSheet(
  BuildContext context, {
  RealtimeRoom? room,
  List<MediaBackgroundImagePreset> imagePresets = const [],
  Future<List<MediaBackgroundImagePreset>>? imagePresetsFuture,
  List<Widget> extraTools = const [],
}) {
  final targetRoom = room ?? RealtimeRoomUiScope.maybeOf(context)?.room;
  return showRealtimeGlassBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final content = RealtimeHostToolsPanel(
        showHeader: true,
        imagePresets: imagePresets,
        imagePresetsFuture: imagePresetsFuture,
        extraTools: extraTools,
        onClose: () => Navigator.maybeOf(sheetContext)?.pop(),
      );
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.76,
            child: targetRoom != null
                ? RealtimeRoomUiScope(room: targetRoom, child: content)
                : content,
          ),
        ),
      );
    },
  );
}
