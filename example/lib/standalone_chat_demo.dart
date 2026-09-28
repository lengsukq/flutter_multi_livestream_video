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
  void dispose() {
    _room.dispose();
    _name.dispose();
    super.dispose();
  }

  HttpStandaloneChatProvisioner _provisioner() => HttpStandaloneChatProvisioner(
    ChatBackendConfig.fromUrl(widget.backendUrl),
  );

  Future<void> _open({required bool create}) async {
    if (_busy) return;
    final provisioner = _provisioner();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final displayName = _name.text.trim().isEmpty
          ? 'Chat user'
          : _name.text.trim();
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
      if (!mounted) {
        await chatRoom.dispose();
        return;
      }
      _room.text = chatRoom.roomCode;
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => RealtimeChatView(
              session: chatRoom.session,
              moderation: chatRoom.room.moderation,
              roomCode: chatRoom.roomCode,
              title: 'Standalone Chat',
              showAppBar: true,
            ),
          ),
        );
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
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('Standalone Chat'),
      backgroundColor: Colors.white.withValues(alpha: .82),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    body: RealtimeAmbientBackground(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              RealtimeGlassSurface(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          color: RealtimeUiTokens.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Independent product chat',
                            style: TextStyle(
                              color: RealtimeUiTokens.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chat works independently from Meeting / Live and uses the same ChatSession UI when embedded with media.',
                      style: TextStyle(
                        color: RealtimeUiTokens.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _room,
                      decoration: _inputDecoration('Room code'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: _inputDecoration('Display name'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: RealtimeUiTokens.dangerSubtle,
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.controlRadius,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: RealtimeUiTokens.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _open(create: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: RealtimeUiTokens.primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.controlRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_comment_rounded),
                      label: const Text('Create chat room'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _open(create: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(
                          color: RealtimeUiTokens.borderStrong,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.controlRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Join chat room'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withValues(alpha: .78),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      borderSide: const BorderSide(color: RealtimeUiTokens.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      borderSide: const BorderSide(color: RealtimeUiTokens.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      borderSide: const BorderSide(color: RealtimeUiTokens.primary, width: 1.4),
    ),
  );
}
