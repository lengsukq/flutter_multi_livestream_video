import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Demo-only classroom copy for the green room and meeting workspace.
///
/// The SDK has no authoritative lesson title, waiting room, agenda or pinned
/// message. These values exist only to exercise the public host slots; a real
/// application replaces them with its own control-plane data.
abstract final class DemoClassroomSample {
  static const meetingTitle = 'Quadratics: finding the roots';
  static const meetingSubtitle =
      'Sample classroom · Algebra II · session 7 of 12';
  static const subject = 'Algebra II';
  static const scheduleLabel = 'Today';
  static const timeRangeLabel = '4:00 – 5:00 PM';
  static const enrolledCount = 6;
  static const pinnedMessage =
      'Try the sticky-note problem on your own board, then post your roots here.';

  /// A countdown four minutes out so the green room shows a live timer.
  static final DateTime _startsAt = DateTime.now().add(
    const Duration(minutes: 3, seconds: 58),
  );
  static DateTime startsAt() => _startsAt;

  static RealtimePreJoinSessionInfo sessionInfo() => RealtimePreJoinSessionInfo(
    title: meetingTitle,
    subject: subject,
    scheduleLabel: scheduleLabel,
    timeRangeLabel: timeRangeLabel,
    startsAt: startsAt(),
    enrolledCount: enrolledCount,
  );

  static const meetingInfo = RealtimeMeetingSessionInfo(
    title: meetingTitle,
    subtitle: meetingSubtitle,
  );

  static const waitingGuests = <RealtimePreJoinWaitingGuest>[
    RealtimePreJoinWaitingGuest(
      id: 'ava',
      name: 'Ava K.',
      note: 'Joined 2 min ago',
    ),
    RealtimePreJoinWaitingGuest(
      id: 'jonah',
      name: 'Jonah M.',
      note: 'Joined 1 min ago',
    ),
    RealtimePreJoinWaitingGuest(
      id: 'sofia',
      name: 'Sofia L.',
      note: 'Joined just now',
    ),
    RealtimePreJoinWaitingGuest(
      id: 'eli',
      name: 'Eli B.',
      note: 'Parent joining too',
    ),
  ];

  static const agenda = <RealtimePreJoinAgendaItem>[
    RealtimePreJoinAgendaItem(
      title: 'Warm-up: factor pairs',
      durationLabel: '5 min',
    ),
    RealtimePreJoinAgendaItem(
      title: 'Factoring x² + bx + c',
      durationLabel: '20 min',
    ),
    RealtimePreJoinAgendaItem(
      title: 'Roots on the graph',
      durationLabel: '15 min',
    ),
    RealtimePreJoinAgendaItem(
      title: 'Practice in breakout rooms',
      durationLabel: '15 min',
    ),
    RealtimePreJoinAgendaItem(
      title: 'Exit poll and homework',
      durationLabel: '5 min',
    ),
  ];

  static const materials = <RealtimePreJoinMaterial>[
    RealtimePreJoinMaterial(
      id: 'slides',
      title: 'Factoring slides.pdf',
      icon: Icons.description_outlined,
    ),
    RealtimePreJoinMaterial(
      id: 'practice',
      title: 'Practice B.pdf',
      icon: Icons.picture_as_pdf_outlined,
    ),
    RealtimePreJoinMaterial(
      id: 'exit-poll',
      title: 'Exit poll (3 questions)',
      icon: Icons.checklist_rounded,
    ),
  ];

  /// Shared product mark used by the Demo headers.
  static const brand = _DemoBrandMark();
}

class _DemoBrandMark extends StatelessWidget {
  const _DemoBrandMark();

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
              bottomLeft: Radius.circular(2),
            ),
          ),
          child: Text(
            'r',
            style: TextStyle(
              fontFamily: RealtimeFonts.displayOf(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: style.onAccent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Realtime Media',
          style: TextStyle(
            fontFamily: RealtimeFonts.displayOf(context),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: style.text,
          ),
        ),
      ],
    );
  }
}
