import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'demo_strings.dart';
import 'demo_composable_chat_page.dart';

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
  int _tabIndex = 0;
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
      if (!silent && mounted) {
        setState(
          () =>
              _roomsError = DemoStrings.of(context).displayRealtimeError(error),
        );
      }
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
            builder: (_) => DemoComposableChatPage(
              chatRoom: chatRoom,
              title: strings.standaloneChat,
            ),
          ),
        );
        unawaited(_refreshRooms(silent: true));
      } finally {
        await connection.dispose();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = DemoStrings.of(context).displayRealtimeError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                      icon: Icon(Icons.arrow_back_rounded, color: style.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.standaloneChat,
                          style: TextStyle(
                            color: style.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.independentProductChat,
                          style: TextStyle(
                            color: style.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 1. User Profile Card
            RealtimeGlassSurface(
              radius: RealtimeUiTokens.cardRadius,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: style.primarySubtle,
                    child: Text(
                      widget.displayName.isNotEmpty
                          ? widget.displayName.characters.first.toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: style.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RealtimeStyle.of(context).text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.userId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: RealtimeStyle.of(context).textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RealtimePill(
                    label: strings.chatOnline,
                    foreground: const Color(0xFF10B981),
                    background: const Color(0xFFECFDF5),
                    borderColor: const Color(0xFFA7F3D0),
                  ),
                ],
              ),
            ),

            // 2. Main Exploration Container
            RealtimeGlassSurface(
              radius: RealtimeUiTokens.cardRadius,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Segmented Tabs Header
                  RealtimeSegmentedTabs<int>(
                    selectedValue: _tabIndex,
                    onChanged: (val) => setState(() => _tabIndex = val),
                    tabs: [
                      RealtimeSegmentTab(
                        value: 0,
                        label: strings.exploreChatRooms,
                        icon: Icons.explore_outlined,
                        badge: _availableRooms.length,
                      ),
                      RealtimeSegmentTab(
                        value: 1,
                        label: strings.quickCreateRoom,
                        icon: Icons.add_comment_outlined,
                      ),
                      RealtimeSegmentTab(
                        value: 2,
                        label: strings.joinByCode,
                        icon: Icons.login_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: style.dangerSubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        border: Border.all(
                          color: style.isDark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFECDD3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: style.isDark
                              ? const Color(0xFFFCA5A5)
                              : style.danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  // Tab 0: Explore active rooms
                  if (_tabIndex == 0) _buildAvailableRooms(),

                  // Tab 1: Quick Create Room
                  if (_tabIndex == 1) ...[
                    RealtimeSheetHeader(
                      title: strings.createChatRoom,
                      subtitle: strings.independentProductChatDescription,
                      icon: Icons.add_comment_rounded,
                    ),
                    const SizedBox(height: 16),
                    RealtimeGlassTextField(
                      controller: _room,
                      label: strings.roomCode,
                      prefixIcon: Icons.tag_rounded,
                      suffix: RealtimePill(
                        label: strings.randomCode,
                        icon: Icons.casino_outlined,
                        foreground: style.primary,
                        background: style.primarySubtle,
                        borderColor: style.primaryBorder,
                        onTap: _busy ? null : _generateRandomCode,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RealtimeGlassButton(
                      onPressed: _busy ? null : () => _open(create: true),
                      isLoading: _busy,
                      icon: Icons.add_comment_rounded,
                      child: Text(strings.createChatRoom),
                    ),
                  ],

                  // Tab 2: Join by code
                  if (_tabIndex == 2) ...[
                    RealtimeSheetHeader(
                      title: strings.joinChatRoom,
                      subtitle: strings.enterChatRoomCode,
                      icon: Icons.login_rounded,
                    ),
                    const SizedBox(height: 16),
                    RealtimeGlassTextField(
                      controller: _room,
                      label: strings.roomCode,
                      prefixIcon: Icons.tag_rounded,
                    ),
                    const SizedBox(height: 16),
                    RealtimeGlassButton(
                      onPressed: _busy ? null : () => _open(create: false),
                      isLoading: _busy,
                      icon: Icons.login_rounded,
                      child: Text(strings.joinChatRoom),
                    ),
                  ],
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
    final style = RealtimeStyle.of(context);
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                  ),
                  if (rooms.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: '${rooms.length}',
                      foreground: style.primary,
                      background: style.primarySubtle,
                      borderColor: style.primaryBorder,
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
        const SizedBox(height: 10),
        if (_roomsError != null)
          Text(
            _roomsError!,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
          )
        else if (rooms.isEmpty)
          RealtimeGlassSurface(
            radius: RealtimeUiTokens.cardRadius,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            shadow: false,
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 32,
                  color: style.textMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.noActiveChatRooms,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: style.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
                  vertical: 12,
                ),
                opacity: 0.88,
                shadow: false,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.primarySubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(color: style.primaryBorder),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 20,
                        color: style.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.roomCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: style.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            strings.chatProviderDisplayName(room.providerId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: style.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: DemoStrings.of(context).join,
                      icon: Icons.login_rounded,
                      foreground: style.primary,
                      background: style.primarySubtle,
                      borderColor: style.primaryBorder,
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
