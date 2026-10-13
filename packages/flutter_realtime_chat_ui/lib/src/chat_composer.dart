import 'package:flutter/material.dart';
import 'chat_components_chat_composer_state.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, this.hintText});
  final String? hintText;
  @override
  State<ChatComposer> createState() => ChatComponentsChatComposerState();
}
