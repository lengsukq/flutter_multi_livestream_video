import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'chat_ui_controller.dart';
import 'chat_components_chat_ui_scope_state.dart';
import 'chat_components_chat_ui_inherited.dart';

class ChatUiScope extends StatefulWidget {
  const ChatUiScope({
    super.key,
    required this.session,
    required this.child,
    this.moderation,
    this.controller,
  });

  final ChatSession session;
  final ChatModeration? moderation;
  final ChatUiController? controller;
  final Widget child;

  static ChatUiController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ChatComponentsChatUiInherited>();
    assert(scope != null, 'ChatUiScope must be an ancestor');
    return scope!.controller;
  }

  @override
  State<ChatUiScope> createState() => ChatComponentsChatUiScopeState();
}
