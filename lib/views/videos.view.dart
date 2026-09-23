import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/views/pinch_view.dart';
import '../models/attendee.model.dart';
import '/views/video_tile.view.dart';

class VideosView extends StatelessWidget {
  final List<AttendeeModel> attendees;

  const VideosView({super.key, required this.attendees});

  @override
  Widget build(BuildContext context) {
    return _buildPageAttendees(attendees);
  }

  Widget _buildPageAttendees(List<AttendeeModel> attendees) {
    List<Widget> rows = [];

    if (attendees.length <= 2) {
      rows.addAll(attendees.map((e) => Expanded(child: _buildAttendeeItem(e))));
    } else {
      for (var i = 0; i < attendees.length / 2; i++) {
        var index = i * 2;
        rows.add(
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildAttendeeItem(attendees[index])),
                if (index + 1 < attendees.length)
                  Expanded(child: _buildAttendeeItem(attendees[index + 1]))
              ],
            ),
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: Column(
            children: rows,
          ),
        );
      },
    );
  }

  Widget _buildAttendeeItem(AttendeeModel item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasVideo = item.isVideoOn && item.videoTile?.tileId != null;

        Widget content = hasVideo
            ? PinchView(
                contentRatio: item.videoTile!.videoStreamContentWidth /
                    item.videoTile!.videoStreamContentHeight,
                child: VideoTileView(
                  paramsVT: item.videoTile!.tileId,
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF090D16),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            item.externalUserId.isNotEmpty
                                ? item.externalUserId.characters.first.toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          item.externalUserId,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (hasVideo)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          item.externalUserId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
