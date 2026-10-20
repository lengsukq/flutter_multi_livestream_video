import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

import 'demo_strings.dart';

/// Authentic Tandem waiting room panel for room discovery.
/// Styled after Tandem Green Room `.waiting` panel with `.mini` action buttons.
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

  Color _avatarColor(String code) {
    const colors = [
      Color(0xFF2E6FD8),
      Color(0xFF7A5AF8),
      Color(0xFFE2742B),
      Color(0xFF2E8B57),
      Color(0xFF0E9E8E),
    ];
    return colors[code.hashCode.abs() % colors.length];
  }

  String _roomInitials(String code) {
    final cleaned = code.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.length >= 2) return cleaned.substring(0, 2).toUpperCase();
    if (cleaned.isNotEmpty) return cleaned.toUpperCase();
    return 'RM';
  }

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = DemoStrings.of(context);
    final displayFamily = RealtimeFonts.displayOf(context);
    final bodyFamily = RealtimeFonts.bodyOf(context);
    final allRooms = widget.rooms;
    final rooms = _filter == null
        ? allRooms
        : allRooms.where((r) => r.roomMode == _filter).toList();

    return RealtimeCardSurface(
      fillColor: style.surface,
      borderColor: style.border,
      radius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tandem header `.ph`
          Row(
            children: [
              Expanded(
                child: Text(
                  '${strings.availableRooms} (${allRooms.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: displayFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: style.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.refresh,
                style: IconButton.styleFrom(
                  backgroundColor: style.surfaceSubtle,
                  foregroundColor: style.textSecondary,
                  minimumSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: style.border),
                  ),
                ),
                onPressed: widget.loading || widget.busy
                    ? null
                    : widget.onRefresh,
                icon: widget.loading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: style.textSecondary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
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
                  foreground: _filter == null
                      ? Colors.white
                      : style.textSecondary,
                  background: _filter == null
                      ? style.text
                      : style.surfaceSubtle,
                  borderColor: _filter == null ? style.text : style.border,
                  onTap: () => setState(() => _filter = null),
                ),
                RealtimePill(
                  label: strings.meeting,
                  icon: Icons.groups_rounded,
                  foreground: _filter == MediaRoomMode.meeting
                      ? Colors.white
                      : style.textSecondary,
                  background: _filter == MediaRoomMode.meeting
                      ? style.text
                      : style.surfaceSubtle,
                  borderColor: _filter == MediaRoomMode.meeting
                      ? style.text
                      : style.border,
                  onTap: () => setState(() => _filter = MediaRoomMode.meeting),
                ),
                RealtimePill(
                  label: strings.live,
                  icon: Icons.sensors_rounded,
                  foreground: _filter == MediaRoomMode.broadcast
                      ? Colors.white
                      : style.textSecondary,
                  background: _filter == MediaRoomMode.broadcast
                      ? style.live
                      : style.surfaceSubtle,
                  borderColor: _filter == MediaRoomMode.broadcast
                      ? style.live
                      : style.border,
                  onTap: () =>
                      setState(() => _filter = MediaRoomMode.broadcast),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (widget.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: style.dangerSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: style.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: style.danger,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: TextStyle(
                        fontFamily: bodyFamily,
                        fontSize: 12,
                        color: style.danger,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: style.surfaceSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(color: style.border),
                    ),
                    child: Icon(
                      Icons.sensors_off_rounded,
                      size: 22,
                      color: style.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _filter == MediaRoomMode.broadcast
                        ? strings.noActiveLiveStreams
                        : (_filter == MediaRoomMode.meeting
                              ? strings.noActiveMeetings
                              : strings.noActiveRooms),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: displayFamily,
                      fontSize: 14,
                      color: style.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.liveDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: bodyFamily,
                      fontSize: 12,
                      color: style.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < rooms.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: style.borderSubtle),
                  _buildRoomRow(
                    context: context,
                    room: rooms[i],
                    style: style,
                    strings: strings,
                    displayFamily: displayFamily,
                    bodyFamily: bodyFamily,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRoomRow({
    required BuildContext context,
    required MediaRoomSummary room,
    required RealtimeStyle style,
    required DemoStrings strings,
    required String displayFamily,
    required String bodyFamily,
  }) {
    final realtimeStrings = RealtimeStrings.of(context);
    final isBroadcast = room.roomMode == MediaRoomMode.broadcast;
    final modeLabel = isBroadcast
        ? realtimeStrings.live
        : (room.meetingMode ?? MediaMeetingMode.classroom).label(
            isZh: realtimeStrings.isZh,
          );
    final summaryText = realtimeStrings.roomCardSummary(
      modeLabel,
      room.attendeeCount,
    );
    final scale = MediaQuery.textScalerOf(context).scale(12);
    final isCompact = scale >= 16 || MediaQuery.sizeOf(context).width < 420;

    if (isCompact) {
      return InkWell(
        onTap: widget.busy ? null : () => widget.onJoin(room),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _avatarColor(room.roomCode),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _roomInitials(room.roomCode),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          room.roomCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: displayFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: style.text,
                          ),
                        ),
                        Text(
                          summaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: bodyFamily,
                            fontSize: 11,
                            color: style.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isBroadcast ? style.live : style.text,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBroadcast
                      ? realtimeStrings.watchLive
                      : realtimeStrings.join,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.busy ? null : () => widget.onJoin(room),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _avatarColor(room.roomCode),
                shape: BoxShape.circle,
              ),
              child: Text(
                _roomInitials(room.roomCode),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.roomCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: displayFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: style.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: bodyFamily,
                      fontSize: 12,
                      color: style.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Tandem `.mini` action button
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isBroadcast ? style.live : style.text,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                isBroadcast ? realtimeStrings.watchLive : realtimeStrings.join,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
