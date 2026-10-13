import 'package:flutter/material.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';
import 'room_regions.dart';

class MediaRoomWaitingView extends StatelessWidget {
  const MediaRoomWaitingView({
    super.key,
    required this.roomCode,
    required this.copied,
    required this.onCopy,
  });
  final String roomCode;
  final bool copied;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.sheetRadius,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          opacity: 0.84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RoomWaitingPulse(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Icon(
                    Icons.wifi_tethering_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.onlyOneHere,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: style.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.shareRoomCode,
                textAlign: TextAlign.center,
                style: TextStyle(color: style.textMuted, fontSize: 13.5),
              ),
              const SizedBox(height: 18),
              RealtimeGlassButton(
                onPressed: onCopy,
                icon: copied ? Icons.check_rounded : Icons.copy_rounded,
                child: Text(
                  copied ? strings.copied : strings.copyRoom(roomCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
