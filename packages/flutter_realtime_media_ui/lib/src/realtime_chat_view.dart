import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

/// Reusable chat surface for standalone and media-attached chat.
class RealtimeChatView extends StatefulWidget {
  const RealtimeChatView({super.key, required this.session, this.roomCode, this.title = 'Chat', this.showAppBar = false});
  final ChatSession session;
  final String? roomCode;
  final String title;
  final bool showAppBar;
  @override
  State<RealtimeChatView> createState() => _RealtimeChatViewState();
}

class _RealtimeChatViewState extends State<RealtimeChatView> {
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;
  @override
  void dispose() { _message.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<ChatConnectionState>(
      stream: widget.session.states,
      initialData: widget.session.state,
      builder: (context, stateSnapshot) => StreamBuilder<List<ChatMessage>>(
        stream: widget.session.messageSnapshots,
        initialData: widget.session.messages,
        builder: (context, messagesSnapshot) {
          final state = stateSnapshot.data ?? widget.session.state;
          final messages = messagesSnapshot.data ?? widget.session.messages;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text([if (widget.roomCode != null) 'Room ${widget.roomCode}', widget.session.providerId, state.name, '${messages.length} messages'].join(' · '), style: Theme.of(context).textTheme.bodySmall),
              ]))]),
            ),
            const Divider(height: 1),
            Expanded(child: messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(reverse: true, padding: const EdgeInsets.all(12), itemCount: messages.length, itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final identity = widget.session is ChatSessionIdentity
                      ? widget.session as ChatSessionIdentity
                      : null;
                  final own = message.userId == identity?.localUserId;
                  return Align(alignment: own ? Alignment.centerRight : Alignment.centerLeft, child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: own ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!own) Text(message.displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      Text(message.message),
                    ]),
                  ));
                })),
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            _composer(state),
          ]);
        },
      ),
    );
    return widget.showAppBar ? Scaffold(appBar: AppBar(title: Text(widget.title)), body: body) : body;
  }

  Widget _composer(ChatConnectionState state) {
    final enabled = state.isConnected && widget.session.capabilities.canSendMessage && !_sending;
    return SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
      Expanded(child: TextField(controller: _message, enabled: enabled, minLines: 1, maxLines: 4, onSubmitted: enabled ? (_) => unawaited(_send()) : null, decoration: InputDecoration(hintText: enabled ? 'Message…' : 'Chat is ${state.name}', border: const OutlineInputBorder(), isDense: true))),
      const SizedBox(width: 8),
      IconButton.filled(onPressed: enabled ? _send : null, icon: _sending ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
    ])));
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    try { await widget.session.sendMessage(text); _message.clear(); }
    catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _sending = false); }
  }
}
