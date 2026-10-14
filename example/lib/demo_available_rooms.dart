import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Next-gen room discovery presentation aligned with Apple HIG.
/// Filtering stays local to the panel.
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
    final isDark = style.isDark;
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
              child: Text(
                '${strings.availableRooms} (${allRooms.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: strings.refresh,
              onPressed: widget.loading || widget.busy
                  ? null
                  : widget.onRefresh,
              icon: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (allRooms.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                    : style.textMuted,
                background: _filter == MediaRoomMode.broadcast
                    ? style.primary
                    : style.surfaceSubtle,
                borderColor: style.border,
                onTap: () => setState(() => _filter = MediaRoomMode.broadcast),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (widget.error != null)
          Text(
            widget.error!,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
          )
        else if (rooms.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.sensors_off_rounded,
                  size: 28,
                  color: style.textMuted.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
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
              ],
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
