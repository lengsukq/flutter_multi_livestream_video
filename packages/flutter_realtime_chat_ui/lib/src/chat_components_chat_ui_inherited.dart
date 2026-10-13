import 'package:flutter/material.dart';
import 'chat_ui_controller.dart';

class ChatComponentsChatUiInherited extends InheritedWidget {
  const ChatComponentsChatUiInherited({
    required this.controller,
    required super.child,
  });
  final ChatUiController controller;
  @override
  bool updateShouldNotify(ChatComponentsChatUiInherited oldWidget) =>
      !identical(controller, oldWidget.controller);
}
