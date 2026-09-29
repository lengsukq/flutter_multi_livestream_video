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
    required this.displayName,
    this.embedded = false,
  });
  final String backendUrl;
  final RealtimeSdk sdk;
  final String userId;
  final String displayName;
  final bool embedded;

  @override
  State<StandaloneChatDemoPage> createState() => _StandaloneChatDemoPageState();
}

class _StandaloneChatDemoPageState extends State<StandaloneChatDemoPage> {
  final _room = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  void _generateRandomCode() {
    final code = '${100000 + (DateTime.now().millisecondsSinceEpoch % 900000)}';
    setState(() => _room.text = code);
  }

  HttpStandaloneChatProvisioner _provisioner() => HttpStandaloneChatProvisioner(
    ChatBackendConfig.fromUrl(widget.backendUrl),
  );

  Future<void> _open({required bool create}) async {
    if (_busy) return;
    final strings = RealtimeStrings.of(context);
    if (!create && _room.text.trim().isEmpty) {
      setState(() => _error = strings.enterChatRoomCode);
      return;
    }
    final provisioner = _provisioner();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final RealtimeChatRoom chatRoom;
      if (create) {
        chatRoom = await widget.sdk.createChatRoom(
          provisioner: provisioner,
          userId: widget.userId,
          displayName: widget.displayName,
          roomCode: _room.text.trim().isEmpty ? null : _room.text.trim(),
        );
      } else {
        final code = _room.text.trim();
        chatRoom = await widget.sdk.joinChatRoom(
          provisioner: provisioner,
          roomCode: code,
          userId: widget.userId,
          displayName: widget.displayName,
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
              moderation: chatRoom.moderation,
              roomCode: chatRoom.roomCode,
              title: strings.standaloneChat,
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
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          shrinkWrap: widget.embedded,
          physics: widget.embedded
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: widget.embedded
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (!widget.embedded) ...[
              Row(
                children: [
                  RealtimeGlassSurface(
                    radius: RealtimeUiTokens.pillRadius,
                    padding: EdgeInsets.zero,
                    opacity: .82,
                    shadow: false,
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: RealtimeUiTokens.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.standaloneChat,
                          style: const TextStyle(
                            color: RealtimeUiTokens.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.independentProductChat,
                          style: const TextStyle(
                            color: RealtimeUiTokens.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            RealtimeGlassSurface(
              radius: RealtimeUiTokens.cardRadius,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RealtimeSheetHeader(
                    title: strings.independentProductChat,
                    subtitle: strings.independentProductChatDescription,
                    icon: Icons.forum_outlined,
                  ),
                  const SizedBox(height: 22),
                  RealtimeGlassTextField(
                    controller: _room,
                    label: strings.roomCode,
                    prefixIcon: Icons.tag_rounded,
                    suffix: RealtimePill(
                      label: strings.randomCode,
                      icon: Icons.casino_outlined,
                      foreground: RealtimeUiTokens.primary,
                      background: RealtimeUiTokens.primarySubtle,
                      borderColor: RealtimeUiTokens.primaryBorder,
                      onTap: _busy ? null : _generateRandomCode,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: RealtimeUiTokens.surfaceSubtle.withValues(
                        alpha: .78,
                      ),
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      border: Border.all(color: RealtimeUiTokens.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          color: RealtimeUiTokens.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.displayName,
                                style: const TextStyle(
                                  color: RealtimeUiTokens.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.userId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RealtimeUiTokens.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.dangerSubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        border: Border.all(
                          color: RealtimeUiTokens.dangerBorder,
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: RealtimeUiTokens.danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  RealtimeGlassButton(
                    onPressed: _busy ? null : () => _open(create: true),
                    isLoading: _busy,
                    icon: Icons.add_comment_rounded,
                    child: Text(strings.createChatRoom),
                  ),
                  const SizedBox(height: 10),
                  RealtimeGlassButton(
                    onPressed: _busy ? null : () => _open(create: false),
                    secondary: true,
                    icon: Icons.login_rounded,
                    child: Text(strings.joinChatRoom),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RealtimeAmbientBackground(child: SafeArea(child: content)),
    );
  }
}
