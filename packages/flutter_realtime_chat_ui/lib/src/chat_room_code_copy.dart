import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatRoomCodeCopy extends StatelessWidget {
  const ChatRoomCodeCopy({super.key, required this.roomCode});
  final String roomCode;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: Localizations.localeOf(context).languageCode == 'zh'
        ? '复制房间码'
        : 'Copy room code',
    icon: const Icon(Icons.copy_outlined),
    onPressed: () {
      unawaited(Clipboard.setData(ClipboardData(text: roomCode)));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'zh'
                ? '房间码已复制'
                : 'Room code copied',
          ),
        ),
      );
    },
  );
}
