import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Room discovery presentation. Filtering stays local to the panel.
class DemoAvailableRooms extends StatefulWidget {
  const DemoAvailableRooms({
    super.key,
    required this.rooms,
    required this.error,
    required this.loading,
    required this.busy,
    required this.onRefresh,
    required this.onJoin,
  });

  final List<MediaRoomSummary> rooms;
  final String? error;
  final bool loading;
  final bool busy;
  final VoidCallback onRefresh;
  final ValueChanged<MediaRoomSummary> onJoin;

  @override
  State<DemoAvailableRooms> createState() => _DemoAvailableRoomsState();
}

class _DemoAvailableRoomsState extends State<DemoAvailableRooms> {
  MediaRoomMode? _filter;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = DemoStrings.of(context);
    final allRooms = widget.rooms;
    final rooms = _filter == null
        ? allRooms
        : allRooms.where((r) => r.roomMode == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.availableRooms,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                  ),
                  if (allRooms.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RealtimePill(
                      label: '${allRooms.length}',
                      foreground: style.primary,
                      background: style.primarySubtle,
                      borderColor: style.primaryBorder,
                    ),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              onPressed: widget.loading || widget.busy
                  ? null
                  : widget.onRefresh,
              icon: widget.loading
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
        if (allRooms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              RealtimePill(
                label: strings.allFilter,
                foreground: _filter == null ? Colors.white : style.textMuted,
                background: _filter == null
                    ? style.primary
                    : style.surfaceSubtle,
                borderColor: _filter == null ? style.primary : style.border,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: 6),
              RealtimePill(
                label: strings.meeting,
                icon: Icons.groups_rounded,
                foreground: _filter == MediaRoomMode.meeting
                    ? Colors.white
                    : style.primary,
                background: _filter == MediaRoomMode.meeting
                    ? style.primary
                    : style.primarySubtle,
                borderColor: _filter == MediaRoomMode.meeting
                    ? style.primary
                    : style.primaryBorder,
                onTap: () => setState(() => _filter = MediaRoomMode.meeting),
              ),
              const SizedBox(width: 6),
              RealtimePill(
                label: strings.live,
                icon: Icons.podcasts_rounded,
                foreground: _filter == MediaRoomMode.broadcast
                    ? Colors.white
                    : (style.isDark
                          ? const Color(0xFFFB7185)
                          : const Color(0xFFE11D48)),
                background: _filter == MediaRoomMode.broadcast
                    ? const Color(0xFFE11D48)
                    : (style.isDark
                          ? const Color(0xFF3B1219)
                          : const Color(0xFFFFF1F2)),
                borderColor: _filter == MediaRoomMode.broadcast
                    ? const Color(0xFFE11D48)
                    : (style.isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFECDD3)),
                onTap: () => setState(() => _filter = MediaRoomMode.broadcast),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (widget.error != null)
          Text(
            widget.error!,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
          )
        else if (rooms.isEmpty)
          RealtimeGlassSurface(
            radius: RealtimeUiTokens.cardRadius,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            shadow: false,
            child: Text(
              _filter == MediaRoomMode.broadcast
                  ? strings.noActiveLiveStreams
                  : (_filter == MediaRoomMode.meeting
                        ? strings.noActiveMeetings
                        : strings.noActiveRooms),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: style.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...rooms.map(
            (room) => RealtimeRoomCard(
              room: room,
              onJoin: widget.busy ? null : () => widget.onJoin(room),
            ),
          ),
      ],
    );
  }
}
