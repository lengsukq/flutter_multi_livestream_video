import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';

class ChatComponentsChatAvatar extends StatelessWidget {
  const ChatComponentsChatAvatar({
    required this.name,
    this.avatarUrl,
    this.size = 30.0,
  });
  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) =>
      RealtimeAvatar(name: name, avatarUrl: avatarUrl, size: size);
}
