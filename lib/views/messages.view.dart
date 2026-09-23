import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/models/meeting.model.dart';
import 'package:flutter_aws_chime/models/meeting.theme.model.dart';
import 'package:flutter_aws_chime/models/message.model.dart';

import '../utils/format.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  List<MessageModel> messages = [];
  late StreamSubscription<MessageModel?> sub;
  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    sub = MeetingModel().receivedMessage.listen((value) {
      if (value != null && mounted) {
        setState(() {
          messages.add(value);
        });
      }
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Positioned(
      left: 14,
      bottom: MeetingTheme().actionViewHeight + 16,
      child: Container(
        constraints: BoxConstraints(
          minHeight: 0,
          maxHeight: min(size.height / 2.5, MeetingTheme().messageViewHeight),
          maxWidth: MeetingTheme().messageViewWidth,
          minWidth: 0,
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: messages.length,
              itemBuilder: (context, index) => chatBubble(messages[index])),
        ),
      ),
    );
  }

  Widget chatBubble(MessageModel message) {
    final isSelf = MeetingModel().localAttendeeId.value == message.attendeeId;
    return Container(
      alignment: Alignment.topLeft,
      margin: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelf
                  ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelf
                    ? const Color(0xFF818CF8).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: shortTextWithAsterisk(message.externalUserId),
                    style: TextStyle(
                      color: isSelf ? const Color(0xFFA5B4FC) : const Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text: '  ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextSpan(
                    text: message.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
