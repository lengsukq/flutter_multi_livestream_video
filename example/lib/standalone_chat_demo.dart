import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'demo_strings.dart';

class StandaloneChatDemoPage extends StatefulWidget {
  const StandaloneChatDemoPage({
    super.key,
    required this.backendUrl,
    required this.realtime,
    required this.userId,
    required this.displayName,
    this.embedded = false,
    this.visible = true,
  });
  final String backendUrl;
  final Realtime realtime;
  final String userId;
  final String displayName;
  final bool embedded;
  final bool visible;

  @override
  State<StandaloneChatDemoPage> createState() => _StandaloneChatDemoPageState();
}

class _StandaloneChatDemoPageState extends State<StandaloneChatDemoPage> {
  final _room = TextEditingController();
  bool _busy = false;
  String? _error;
  List<ChatRoomSummary> _availableRooms = const [];
  bool _roomsLoading = false;
  bool _roomsRequestInFlight = false;
  String? _roomsError;
  Timer? _roomsTimer;

  @override
  void initState() {
    super.initState();
    if (widget.visible) unawaited(_refreshRooms());
    _roomsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (widget.visible && !_busy) unawaited(_refreshRooms(silent: true));
    });
  }

  @override
  void didUpdateWidget(covariant StandaloneChatDemoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible &&
        (!oldWidget.visible || oldWidget.backendUrl != widget.backendUrl)) {
      unawaited(_refreshRooms());
    }
  }

  @override
  void dispose() {
    _roomsTimer?.cancel();
    _room.dispose();
    super.dispose();
  }

  Future<void> _refreshRooms({bool silent = false}) async {
    if (_roomsRequestInFlight) return;
    final backendUrl = widget.backendUrl.trim();
    if (backendUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _availableRooms = const [];
          _roomsError = null;
        });
      }
      return;
    }

    _roomsRequestInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _roomsLoading = true;
        _roomsError = null;
      });
    }
    try {
      final rooms = await widget.realtime.listChatRooms();
      if (mounted && widget.backendUrl.trim() == backendUrl) {
        setState(() {
          _availableRooms = rooms;
          _roomsError = null;
        });
      }
    } catch (error) {
      if (!silent && mounted) setState(() => _roomsError = error.toString());
    } finally {
      _roomsRequestInFlight = false;
      if (!silent && mounted) setState(() => _roomsLoading = false);
    }
  }

  void _generateRandomCode() {
    final code = '${100000 + (DateTime.now().millisecondsSinceEpoch % 900000)}';
    setState(() => _room.text = code);
  }

  Future<void> _open({required bool create}) async {
    if (_busy) return;
    final strings = RealtimeStrings.of(context);
    if (!create && _room.text.trim().isEmpty) {
      setState(() => _error = strings.enterChatRoomCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roomCode = _room.text.trim();
      final request = create
          ? RealtimeRequest.create(
              type: RealtimeExperience.chat,
              user: RealtimeUser(id: widget.userId, name: widget.displayName),
              roomCode: roomCode.isEmpty ? null : roomCode,
            )
          : RealtimeRequest.join(
              type: RealtimeExperience.chat,
              user: RealtimeUser(id: widget.userId, name: widget.displayName),
              roomCode: roomCode,
            );
      final connection = await widget.realtime.open(request);
      final chatRoom = connection.chatRoom!;
      if (!mounted) {
        await connection.dispose();
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
        unawaited(_refreshRooms(silent: true));
      } finally {
        await connection.dispose();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
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
                  if (!widget.embedded) ...[
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
                  ],
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
                  const SizedBox(height: 22),
                  _buildAvailableRooms(),
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

  Widget _buildAvailableRooms() {
    final strings = DemoStrings.of(context);
    final rooms = _availableRooms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      strings.availableChatRooms,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: RealtimeUiTokens.text,
                      ),
                    ),
                  ),
                  if (rooms.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: '${rooms.length}',
                      foreground: RealtimeUiTokens.primary,
                      background: RealtimeUiTokens.primarySubtle,
                      borderColor: RealtimeUiTokens.primaryBorder,
                    ),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _roomsLoading || _roomsRequestInFlight || _busy
                  ? null
                  : () => _refreshRooms(),
              icon: _roomsLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: Text(strings.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_roomsError != null)
          Text(
            _roomsError!,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
          )
        else if (rooms.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
              border: Border.all(color: RealtimeUiTokens.border),
            ),
            child: Text(
              strings.noActiveChatRooms,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: RealtimeUiTokens.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          ...rooms.map(
            (room) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RealtimeGlassSurface(
                radius: RealtimeUiTokens.controlRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                opacity: 0.82,
                shadow: false,
                child: Row(
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 18,
                      color: RealtimeUiTokens.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.roomCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: RealtimeUiTokens.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            strings.chatProviderDisplayName(room.providerId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: RealtimeUiTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: DemoStrings.of(context).join,
                      icon: Icons.login_rounded,
                      foreground: RealtimeUiTokens.primary,
                      background: RealtimeUiTokens.primarySubtle,
                      borderColor: RealtimeUiTokens.primaryBorder,
                      onTap: _busy
                          ? null
                          : () {
                              _room.text = room.roomCode;
                              unawaited(_open(create: false));
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
