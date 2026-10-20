import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_chat_ui/flutter_realtime_chat_ui.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';

/// Room roster without a sidebar, drawer or modal route.
class RealtimeParticipantList extends StatelessWidget {
  const RealtimeParticipantList({super.key, this.onSelected});
  final ValueChanged<MediaParticipant>? onSelected;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView.builder(
        itemCount: controller.snapshot.participants.length,
        itemBuilder: (context, index) {
          final member = controller.snapshot.participants[index];
          return ListTile(
            key: ValueKey(member.id),
            leading: RealtimeAvatar(
              name: member.displayName,
              avatarUrl: member.avatarUrl,
              size: 36,
              isOnline: true,
              showOnlineDot: true,
            ),
            title: Text(member.displayName),
            subtitle: member.isLocal ? const Text('You') : null,
            trailing: _ParticipantActions(
              controller: controller,
              member: member,
            ),
            onTap: onSelected == null ? null : () => onSelected!(member),
          );
        },
      ),
    );
  }
}

/// Host-only bulk mute with partial-failure retry. Layout stays app-owned.
class RealtimeBulkMuteButton extends StatelessWidget {
  const RealtimeBulkMuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.canMuteAllParticipants) {
          return const SizedBox.shrink();
        }
        final busy = controller.isPending(
          RealtimeRoomUiAction.participantManagement,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: strings.isZh ? '全员静音' : 'Mute all participants',
              icon: const Icon(Icons.volume_off_outlined),
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        useRootNavigator: true,
                        builder: (dialogContext) => RealtimeGlassDialog(
                          title: Text(
                            strings.isZh ? '全员静音？' : 'Mute all participants?',
                          ),
                          content: Text(strings.muteAllConfirmation),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text(strings.cancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: Text(strings.muteAll),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      await _performBulkMute(context, controller, retry: false);
                    },
            ),
            if (controller.bulkMuteFailures.isNotEmpty)
              IconButton(
                tooltip: strings.isZh ? '重试失败成员' : 'Retry failed mutes',
                icon: const Icon(Icons.refresh_outlined),
                onPressed: busy
                    ? null
                    : () => _performBulkMute(context, controller, retry: true),
              ),
          ],
        );
      },
    );
  }

  Future<void> _performBulkMute(
    BuildContext context,
    RealtimeRoomUiController controller, {
    required bool retry,
  }) async {
    final strings = RealtimeStrings.of(context);
    try {
      await controller.muteAllParticipants(retryFailed: retry);
      if (context.mounted && controller.bulkMuteFailures.isNotEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              strings.isZh
                  ? '${controller.bulkMuteFailures.length} 位成员未能静音'
                  : '${controller.bulkMuteFailures.length} participants could not be muted.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

/// Combined RTC/IM directory, sharing the same member reconciliation as the
/// legacy room. The app owns its placement and the list doesn't poll.
class RealtimeManagedParticipantList extends StatefulWidget {
  const RealtimeManagedParticipantList({super.key});

  @override
  State<RealtimeManagedParticipantList> createState() =>
      _RealtimeManagedParticipantListState();
}

class _RealtimeManagedParticipantListState
    extends State<RealtimeManagedParticipantList> {
  RealtimeRoomUiController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = RealtimeRoomUiScope.of(context);
    if (identical(current, _controller)) return;
    _controller = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(current, _controller)) {
        unawaited(current.refreshManagedMembers());
      }
    });
  }

  Future<void> _manage(
    BuildContext context,
    RealtimeRoomUiController controller,
    String action,
    String mediaId,
    String chatId,
    String name,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    final strings = RealtimeStrings.of(context);
    if (action == 'removeMedia' || action == 'removeChat') {
      final confirm = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => RealtimeGlassDialog(
          title: Text(
            action == 'removeChat'
                ? strings.removeFromChat
                : strings.removeFromMedia,
          ),
          content: Text(name),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.leave),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
    }
    try {
      switch (action) {
        case 'mute':
          await controller.muteParticipant(mediaId);
        case 'stopVideo':
          await controller.stopParticipantVideo(mediaId);
        case 'removeMedia':
          await controller.removeParticipant(mediaId);
        case 'removeChat':
          await controller.removeChatMember(chatId);
        case 'host':
          await controller.changeParticipantRole(mediaId, MediaRole.host);
      }
      if (action != 'removeChat' && action != 'host') {
        await controller.refreshManagedMembers();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final members = controller.managedMembers;
        final capabilities = controller.room.media.managementCapabilities;
        final mediaHost = controller.room.media.isLogicalOwner;
        final chat = controller.chatUiController;
        final canManageChat =
            chat?.isHost == true &&
            chat!.managementCapabilities.removeMember.supported;

        return Column(
          children: [
            // Clean subheader bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: style.primarySubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.pillRadius,
                      ),
                      border: Border.all(
                        color: style.primaryBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: RealtimeUiTokens.speakStrong,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${strings.participants} (${members.length})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: style.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const RealtimeBulkMuteButton(),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: strings.refresh,
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.membersLoading
                        ? null
                        : () => unawaited(controller.refreshManagedMembers()),
                    icon: controller.membersLoading
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),
            ),
            if (controller.memberLoadError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  controller.memberLoadError.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: members.isEmpty
                  ? Center(
                      child: controller.membersLoading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.group_off_rounded,
                                    size: 28,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  strings.noManagedMembers,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : RealtimeUiTokens.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      itemCount: members.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final media = member.media;
                        final chatMember = member.chat;
                        final canManageMedia =
                            !member.isSelf && media != null && mediaHost;
                        final canRemoveChat =
                            !member.isSelf &&
                            chatMember != null &&
                            canManageChat;
                        final isHost = media?.role == MediaRole.host;

                        final actions = <PopupMenuEntry<String>>[
                          if (canManageMedia &&
                              capabilities.muteParticipant.supported)
                            PopupMenuItem(
                              value: 'mute',
                              child: Text(strings.muteParticipant),
                            ),
                          if (canManageMedia &&
                              capabilities.stopParticipantVideo.supported)
                            PopupMenuItem(
                              value: 'stopVideo',
                              child: Text(strings.stopParticipantVideo),
                            ),
                          if (canManageMedia &&
                              capabilities.changeParticipantRole.supported)
                            PopupMenuItem(
                              value: 'host',
                              child: Text(strings.grantHost),
                            ),
                          if (canManageMedia &&
                              capabilities.removeParticipant.supported)
                            PopupMenuItem(
                              value: 'removeMedia',
                              child: Text(strings.removeFromMedia),
                            ),
                          if (canRemoveChat)
                            PopupMenuItem(
                              value: 'removeChat',
                              child: Text(strings.removeFromChat),
                            ),
                        ];

                        final name = member.displayName.isEmpty
                            ? member.userId
                            : member.displayName;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : style.surfaceSubtle,
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.cardRadius,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : style.border,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  RealtimeAvatar(
                                    name: name,
                                    avatarUrl: member.avatarUrl,
                                    size: 36,
                                  ),
                                  if (media != null || chatMember != null)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: RealtimeUiTokens.speakStrong,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              // Name & status details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: isDark
                                                  ? Colors.white
                                                  : style.text,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isHost) ...[
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: style.accent,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              strings.isZh ? '主持人' : 'Host',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: style.onAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (member.isSelf) ...[
                                          const SizedBox(width: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: style.primarySubtle,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: style.primaryBorder,
                                                width: 0.6,
                                              ),
                                            ),
                                            child: Text(
                                              strings.you,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: style.text,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 3,
                                      children: [
                                        if (media != null)
                                          () {
                                            final mediaParticipant = controller
                                                .snapshot
                                                .participants
                                                .where(
                                                  (p) =>
                                                      p.id ==
                                                      media.participantId,
                                                )
                                                .firstOrNull;
                                            final isMuted = member.isSelf
                                                ? controller.snapshot.localMuted
                                                : (mediaParticipant?.isMuted ??
                                                      false);
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1.5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : Colors.black.withValues(
                                                        alpha: 0.05,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isMuted
                                                        ? Icons.mic_off_rounded
                                                        : Icons.mic_rounded,
                                                    size: 11,
                                                    color: isMuted
                                                        ? Colors.redAccent
                                                        : RealtimeUiTokens
                                                              .speakStrong,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    strings.mediaOnline,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : style.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }(),
                                        if (chatMember != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .chat_bubble_outline_rounded,
                                                  size: 10,
                                                  color: Color(0xFF1D1D1F),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  strings.chatOnline,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : style.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Trailing management actions
                              if (actions.isNotEmpty)
                                PopupMenuButton<String>(
                                  tooltip: strings.isZh
                                      ? '管理成员'
                                      : 'Manage member',
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : style.textMuted,
                                  ),
                                  enabled: !controller.isPending(
                                    RealtimeRoomUiAction.participantManagement,
                                  ),
                                  onSelected: (action) => _manage(
                                    context,
                                    controller,
                                    action,
                                    media?.participantId ?? '',
                                    chatMember?.userId ?? '',
                                    member.displayName,
                                  ),
                                  itemBuilder: (_) => actions,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ParticipantActions extends StatelessWidget {
  const _ParticipantActions({required this.controller, required this.member});
  final RealtimeRoomUiController controller;
  final MediaParticipant member;

  @override
  Widget build(BuildContext context) {
    final caps = controller.room.media.managementCapabilities;
    final canManage =
        controller.room.media.isLogicalOwner &&
        !member.isLocal &&
        (caps.removeParticipant.supported ||
            caps.muteParticipant.supported ||
            caps.stopParticipantVideo.supported);
    if (!canManage) {
      return Icon(member.isMuted ? Icons.mic_off : Icons.mic, size: 18);
    }
    final strings = RealtimeStrings.of(context);
    return PopupMenuButton<String>(
      tooltip: strings.manageRoom,
      enabled: !controller.isPending(
        RealtimeRoomUiAction.participantManagement,
      ),
      onSelected: (value) async {
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) return;
        try {
          switch (value) {
            case 'mute':
              await controller.muteParticipant(member.id);
            case 'stopVideo':
              await controller.stopParticipantVideo(member.id);
            case 'remove':
              final approved = await showDialog<bool>(
                context: context,
                useRootNavigator: true,
                builder: (ctx) => RealtimeGlassDialog(
                  title: Text(strings.removeParticipant),
                  content: Text(member.displayName),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(strings.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(strings.removeMember),
                    ),
                  ],
                ),
              );
              if (approved == true) {
                await controller.removeParticipant(member.id);
              }
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
      },
      itemBuilder: (_) => [
        if (caps.muteParticipant.supported)
          PopupMenuItem(value: 'mute', child: Text(strings.muteParticipant)),
        if (caps.stopParticipantVideo.supported)
          PopupMenuItem(
            value: 'stopVideo',
            child: Text(strings.stopParticipantVideo),
          ),
        if (caps.removeParticipant.supported)
          PopupMenuItem(
            value: 'remove',
            child: Text(strings.removeParticipant),
          ),
      ],
    );
  }
}

/// Message timeline rendered separately from the send form.
class RealtimeChatMessageList extends StatelessWidget {
  const RealtimeChatMessageList({super.key});
  @override
  Widget build(BuildContext context) => const ChatMessageList();
}

/// Room-specific facade for the same composer used by standalone chat.
class RealtimeChatComposer extends StatelessWidget {
  const RealtimeChatComposer({super.key, this.hintText});
  final String? hintText;
  @override
  Widget build(BuildContext context) => ChatComposer(hintText: hintText);
}

/// Convenience grouping; consumers may place list and composer separately.
class RealtimeChatPanel extends StatelessWidget {
  const RealtimeChatPanel({super.key});

  @override
  Widget build(BuildContext context) => const ChatPanel();
}
