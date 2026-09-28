import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

class StandaloneChatDemoPage extends StatefulWidget {
  const StandaloneChatDemoPage({
    super.key,
    required this.backendUrl,
    required this.sdk,
    required this.userId,
  });
  final String backendUrl;
  final RealtimeSdk sdk;
  final String userId;

  @override
  State<StandaloneChatDemoPage> createState() => _StandaloneChatDemoPageState();
}

class _StandaloneChatDemoPageState extends State<StandaloneChatDemoPage> {
  final _room = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _room.dispose(); _name.dispose(); super.dispose(); }

  HttpStandaloneChatProvisioner _provisioner() => HttpStandaloneChatProvisioner(
    ChatBackendConfig.fromUrl(widget.backendUrl),
  );

  Future<void> _open({required bool create}) async {
    if (_busy) return;
    final provisioner = _provisioner();
    setState(() { _busy = true; _error = null; });
    try {
      final displayName = _name.text.trim().isEmpty ? 'Chat user' : _name.text.trim();
      final RealtimeChatRoom chatRoom;
      if (create) {
        chatRoom = await widget.sdk.createChatRoom(
          provisioner: provisioner,
          userId: widget.userId,
          displayName: displayName,
          roomCode: _room.text.trim().isEmpty ? null : _room.text.trim(),
        );
      } else {
        final code = _room.text.trim();
        if (code.isEmpty) throw ArgumentError('Enter a chat room code.');
        chatRoom = await widget.sdk.joinChatRoom(
          provisioner: provisioner,
          roomCode: code,
          userId: widget.userId,
          displayName: displayName,
        );
      }
      if (!mounted) { await chatRoom.dispose(); return; }
      _room.text = chatRoom.roomCode;
      try {
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => RealtimeChatView(
            session: chatRoom.session,
            roomCode: chatRoom.roomCode,
            title: 'Standalone Chat',
            showAppBar: true,
          ),
        ));
      } finally {
        await chatRoom.dispose();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      provisioner.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Standalone Chat')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Chat works independently from Meeting / Live. The demo server only provisions provider credentials.', style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 20),
        TextField(controller: _room, decoration: const InputDecoration(labelText: 'Room code', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder())),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _busy ? null : () => _open(create: true), icon: const Icon(Icons.add_comment_rounded), label: const Text('Create chat room')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _busy ? null : () => _open(create: false), icon: const Icon(Icons.login_rounded), label: const Text('Join chat room')),
      ]),
    )),
  );
}
