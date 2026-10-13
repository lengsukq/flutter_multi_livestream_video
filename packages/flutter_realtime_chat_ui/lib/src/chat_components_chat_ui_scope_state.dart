import 'package:flutter/material.dart';
import 'chat_ui_controller.dart';
import 'chat_ui_scope.dart';
import 'chat_components_chat_ui_inherited.dart';

class ChatComponentsChatUiScopeState extends State<ChatUiScope> {
  late ChatUiController _controller;
  late bool _owns;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _owns = widget.controller == null;
    _controller =
        widget.controller ??
        ChatUiController(widget.session, moderation: widget.moderation);
    assert(identical(_controller.session, widget.session));
  }

  @override
  void didUpdateWidget(covariant ChatUiScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session) ||
        !identical(oldWidget.moderation, widget.moderation) ||
        !identical(oldWidget.controller, widget.controller)) {
      if (_owns) _controller.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    if (_owns) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatComponentsChatUiInherited(
    controller: _controller,
    child: widget.child,
  );
}
