import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_aws_chime/models/meeting.model.dart';
import 'package:flutter_aws_chime/models/message.model.dart';
import 'package:flutter_aws_chime/utils/snackbar.dart';

import 'icon.button.view.dart';

class ActionsView extends StatelessWidget {
  final messageTextController = TextEditingController();

  ActionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    return Positioned(
      left: 12,
      right: isPortrait ? 12 : max(12, MediaQuery.of(context).size.width - 560),
      bottom: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                messageFormContainer(context),
                const SizedBox(width: 4),
                IconButtonView(
                  icon: MeetingModel().getMuteStatus()
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                  iconColor: MeetingModel().getMuteStatus()
                      ? const Color(0xFFFB7185)
                      : Colors.white,
                  onTap: () async {
                    var res = await MeetingModel().toggleMute();
                    return res ? Icons.mic_off_rounded : Icons.mic_rounded;
                  },
                ),
                IconButtonView(
                  icon: MeetingModel().getVideoOn()
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  iconColor: MeetingModel().getVideoOn()
                      ? const Color(0xFF34D399)
                      : Colors.white70,
                  onTap: () async {
                    var res = await MeetingModel().toggleVideo();
                    return res
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded;
                  },
                ),
                IconButtonView(
                  icon: Icons.headphones_rounded,
                  onTap: () => showAudioDeviceDialog(context),
                ),
                IconButtonView(
                  icon: Icons.screen_rotation_rounded,
                  onTap: () async {
                    if (MediaQuery.of(context).orientation ==
                        Orientation.portrait) {
                      SystemChrome.setPreferredOrientations(
                          [DeviceOrientation.landscapeLeft]);
                    } else {
                      SystemChrome.setPreferredOrientations(
                          [DeviceOrientation.portraitUp]);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showAudioDeviceDialog(BuildContext context) async {
    String? device = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var selected = MeetingModel().selectedAudioDevice;
        var selectedIcon = const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF6366F1),
          size: 20,
        );
        var items = MeetingModel()
            .deviceList
            .whereType<String>()
            .map((e) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: selected == e
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == e
                          ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      e.toLowerCase().contains('speaker')
                          ? Icons.volume_up_rounded
                          : Icons.hearing_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      e,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context, e);
                    },
                    trailing: selected == e ? selectedIcon : null,
                  ),
                ))
            .toList();

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    '音频输出设备',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: items,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (device == null) {
      return;
    }

    MeetingModel().updateCurrentDevice(device);
  }

  Future<void> sendMessage(BuildContext context) async {
    if (messageTextController.text.trim().isEmpty) {
      showSnackBar(context, message: "发送内容不能为空");
      return;
    }
    try {
      var localAttendee = MeetingModel().getLocalAttendee();
      var message = messageTextController.text;
      var res = await MeetingModel().sendMessage(message);
      if (res) {
        MeetingModel().hideControlInSeconds();
        MeetingModel().receivedMessage.add(MessageModel(
            localAttendee.attendeeId,
            localAttendee.externalUserId,
            message,
            MeetingModel().topic,
            DateTime.now().millisecondsSinceEpoch));
        messageTextController.clear();
      } else {
        if (context.mounted) {
          showSnackBar(context, message: '发送失败，请重试');
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, message: e.toString());
      }
    }
  }

  Widget messageFormContainer(BuildContext context) {
    return Expanded(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: messageSendForm(context)),
            Padding(
              padding: const EdgeInsets.only(right: 2.0),
              child: IconButtonView(
                icon: Icons.arrow_upward_rounded,
                iconColor: const Color(0xFF818CF8),
                showBackgroundColor: false,
                onTap: () => sendMessage(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget messageSendForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: TextField(
        controller: messageTextController,
        onTap: () {
          MeetingModel().controlHideDelay?.cancel();
          MeetingModel().controlHideDelay = null;
        },
        onTapOutside: (evt) {
          FocusManager.instance.primaryFocus?.unfocus();
          MeetingModel().hideControlInSeconds();
        },
        onSubmitted: (value) => sendMessage(context),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
        ),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: '发送弹幕...',
          hintStyle: TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
