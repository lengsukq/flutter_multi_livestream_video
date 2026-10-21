import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'support/meeting_sharing_fixture.dart';

void main() {
  testWidgets(
    'ordinary meeting keeps the shared whiteboard without teaching features',
    (tester) async {
      final fixture = await MeetingSharingFixture.create(
        mode: SharedContentMode.whiteboard,
        teaching: false,
      );
      addTearDown(fixture.room.dispose);
      expect(
        fixture.room.sharedContent!.content?.mode,
        SharedContentMode.whiteboard,
      );
      expect(fixture.room.sharedContent!.status.error, isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: RealtimeUiTheme.light(),
          home: RealtimeMeetingPage(room: fixture.room, showClassroom: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.room.classroom, isNull);
      expect(find.byType(AnnotationSurface), findsWidgets);
      expect(find.byType(RealtimeDockSharedContentButton), findsOneWidget);
      expect(find.byTooltip('Raise hand'), findsNothing);
      expect(find.byType(RealtimeClassroomSidePanel), findsNothing);
      expect(fixture.room.sharedContent!.screenAnnotations.canEdit, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.room.dispose);
    },
  );

  testWidgets(
    'whiteboard rail appears on share and disappears on stop without resizing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await MeetingSharingFixture.create(
        mode: SharedContentMode.members,
        withTrack: false,
      );
      addTearDown(fixture.room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: RealtimeUiTheme.light(),
          home: RealtimeMeetingPage(room: fixture.room, showClassroom: false),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byType(RealtimeMeetingRail);
      expect(rail, findsOneWidget);
      expect(find.byType(WhiteboardToolRail), findsNothing);
      expect(find.byType(AnnotationSurface), findsNothing);

      // No re-mount or window resize: the mode changes exclusively through
      // the real classroom/shared-content state stream.
      await tester.runAsync(() => fixture.mode(SharedContentMode.whiteboard));
      await tester.pumpAndSettle();
      expect(find.byType(WhiteboardToolRail), findsOneWidget);
      expect(
        find.ancestor(of: find.byType(WhiteboardToolRail), matching: rail),
        findsOneWidget,
      );
      expect(find.byType(AnnotationSurface), findsWidgets);

      await tester.runAsync(() => fixture.mode(SharedContentMode.members));
      await tester.pumpAndSettle();
      expect(find.byType(WhiteboardToolRail), findsNothing);
      expect(find.byType(AnnotationSurface), findsNothing);
      expect(rail, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.room.dispose);
    },
  );
  testWidgets(
    'merged rail changes whiteboard tools and keeps meeting navigation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final f = await MeetingSharingFixture.create(
        mode: SharedContentMode.whiteboard,
        withTrack: false,
      );
      addTearDown(f.room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: RealtimeUiTheme.light(),
          home: RealtimeMeetingPage(room: f.room, showClassroom: false),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byType(RealtimeMeetingRail);
      expect(rail, findsOneWidget);
      expect(find.byType(WhiteboardToolRail), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(WhiteboardToolRail),
          matching: find.byType(RealtimeMeetingRail),
        ),
        findsOneWidget,
      );
      final peopleButton = find.descendant(
        of: rail,
        matching: find.byTooltip('Participants'),
      );
      expect(
        tester.getTopLeft(find.byType(WhiteboardToolRail)).dy,
        lessThan(tester.getTopLeft(peopleButton).dy),
        reason: 'Whiteboard tools should be above ordinary room controls',
      );

      final boardTools = find.byType(WhiteboardToolRail);
      final highlight = find.descendant(
        of: boardTools,
        matching: find.byTooltip('Highlight'),
      );
      await tester.ensureVisible(highlight);
      await tester.tap(highlight);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnnotationSurface>(find.byType(AnnotationSurface)).tool,
        AnnotationTool.highlight,
      );
      final pen = find.descendant(
        of: boardTools,
        matching: find.byTooltip('Pen'),
      );
      await tester.ensureVisible(pen);
      await tester.pumpAndSettle();
      await tester.tap(pen);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnnotationSurface>(find.byType(AnnotationSurface)).tool,
        AnnotationTool.pen,
      );
      final participants = find.descendant(
        of: rail,
        matching: find.byTooltip('Participants'),
      );
      await tester.ensureVisible(participants);
      await tester.tap(participants);
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingSidePanel), findsOneWidget);
      expect(find.byType(RealtimeClassroomSidePanel), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.byType(RealtimeMeetingRail), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(f.room.dispose);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    MeetingSharingFixture f, {
    bool strip = true,
    bool classroom = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RealtimeUiTheme.light(),
        home: RealtimeRoomUiScope(
          room: f.room,
          child: Scaffold(
            body: RealtimeMeetingStage(
              useGrid: false,
              showFilmstrip: strip,
              showClassroom: classroom,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder thumb(String id) => find.byKey(ValueKey('meeting-participant-$id'));
  Finder rendered(String id) => find.byKey(ValueKey('render-$id'));
  Finder getMain() => find.byType(RealtimeMeetingFilmstripStage);

  for (final local in [true, false]) {
    testWidgets(
      '${local ? 'local' : 'remote'} sharing keeps cameras visible and swaps locally without media commands',
      (tester) async {
        final f = await MeetingSharingFixture.create(localShare: local);
        addTearDown(f.room.dispose);
        await mount(tester, f, classroom: false);
        expect(rendered('screen'), findsOneWidget);
        expect(thumb('self'), findsOneWidget);
        expect(thumb('guest'), findsOneWidget);
        expect(thumb('off'), findsOneWidget);
        expect(rendered('camera-self'), findsOneWidget);
        final stripRect = tester.getRect(
          find.byType(RealtimeMeetingParticipantStrip),
        );
        expect(
          tester.getRect(rendered('screen')).bottom,
          lessThanOrEqualTo(stripRect.top),
        );
        await tester.tap(thumb('self'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RealtimeMeetingFilmstripStage>(getMain())
              .primaryParticipant
              .id,
          'self',
        );
        expect(rendered('screen'), findsOneWidget);
        expect(rendered('camera-self'), findsOneWidget);
        await tester.tap(thumb('guest'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RealtimeMeetingFilmstripStage>(getMain())
              .primaryParticipant
              .id,
          'guest',
        );
        await tester.tap(find.byTooltip('Return to shared content'));
        await tester.pumpAndSettle();
        expect(getMain(), findsNothing);
        expect(thumb('self'), findsOneWidget);
        expect(f.media.mutations, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'hidden strip frees stage space and preserves camera focus with an independent return action',
    (tester) async {
      final f = await MeetingSharingFixture.create();
      addTearDown(f.room.dispose);
      await mount(tester, f);
      await tester.tap(thumb('guest'));
      await tester.pumpAndSettle();
      final initialHeight = tester.getSize(getMain()).height;
      await mount(tester, f, strip: false);
      expect(find.byType(RealtimeMeetingParticipantStrip), findsNothing);
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(getMain())
            .primaryParticipant
            .id,
        'guest',
      );
      expect(tester.getSize(getMain()).height, greaterThan(initialHeight));
      await tester.tap(find.byKey(const ValueKey('meeting-return-to-content')));
      await tester.pumpAndSettle();
      expect(getMain(), findsNothing);
      expect(rendered('screen'), findsOneWidget);
      await mount(tester, f);
      expect(thumb('self'), findsOneWidget);
      expect(f.media.mutations, isEmpty);
    },
  );

  testWidgets(
    'pending direct share retains camera focus when the first track arrives',
    (tester) async {
      final f = await MeetingSharingFixture.create(
        localShare: true,
        withTrack: false,
      );
      addTearDown(f.room.dispose);
      await mount(tester, f);
      expect(thumb('self'), findsOneWidget);
      await tester.tap(thumb('guest'));
      await tester.pumpAndSettle();
      f.media.emit(
        f.media.current.copyWith(
          contentShareTrack: const SharingTrack('screen', 'self', screen: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(getMain())
            .primaryParticipant
            .id,
        'guest',
      );
      expect(rendered('screen'), findsOneWidget);
      expect(f.media.mutations, isEmpty);
    },
  );

  testWidgets(
    'leaving participant returns to sharing and sharing end restores the previous camera focus',
    (tester) async {
      final f = await MeetingSharingFixture.create(withTrack: false);
      addTearDown(f.room.dispose);
      await mount(tester, f);
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      f.media.emit(
        f.media.current.copyWith(
          contentShareTrack: const SharingTrack(
            'screen',
            'guest',
            screen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(getMain(), findsNothing);
      await tester.tap(thumb('guest'));
      await tester.pumpAndSettle();
      f.media.emit(
        f.media.current.copyWith(
          participants: f.media.current.participants
              .where((p) => p.id != 'guest')
              .toList(),
        ),
      );
      await tester.pumpAndSettle();
      expect(getMain(), findsNothing);
      f.media.emit(f.media.current.copyWith(clearContentShareTrack: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(getMain())
            .primaryParticipant
            .id,
        'self',
      );
      expect(f.media.mutations, isEmpty);
    },
  );

  testWidgets(
    'whiteboard preview is live and read only while mode changes and new shares reset focus',
    (tester) async {
      final f = await MeetingSharingFixture.create(
        mode: SharedContentMode.whiteboard,
        withTrack: false,
      );
      addTearDown(f.room.dispose);
      await mount(tester, f);
      expect(find.byType(WhiteboardView), findsOneWidget);
      final board = f.room.sharedContent!.whiteboard;
      final page = board.state!.activePageId;
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      expect(find.byType(WhiteboardView), findsNothing);
      final preview = tester.widget<AnnotationSurface>(
        find.byType(AnnotationSurface),
      );
      expect(preview.session, same(board));
      expect(preview.allowEditing, isFalse);
      expect(preview.enableNavigation, isFalse);
      expect(preview.toolbarPlacement, AnnotationToolbarPlacement.none);
      final state = board.state!;
      f.repository!.whiteboard = WhiteboardState(
        revision: state.revision + 1,
        canEdit: state.canEdit,
        pages: state.pages,
        activePageId: state.activePageId,
        canvas: AnnotationCanvas(
          canvasId: state.canvas.canvasId,
          shapes: [
            AnnotationShape(
              id: 'remote-stroke',
              tool: AnnotationTool.pen,
              points: const [
                AnnotationPoint(0.1, 0.1),
                AnnotationPoint(0.9, 0.9),
              ],
            ),
          ],
        ),
      );
      await f.room.classroom!.refresh();
      await tester.pumpAndSettle();
      expect(preview.session.canvas.shapes.single.id, 'remote-stroke');

      expect(find.byType(AnnotationToolbar), findsNothing);
      await tester.tap(find.byTooltip('Return to shared content'));
      await tester.pumpAndSettle();
      expect(board.state!.activePageId, page);
      expect(board.canvas.shapes.single.id, 'remote-stroke');
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      await f.mode(SharedContentMode.screen);
      await tester.pumpAndSettle();
      expect(getMain(), findsNothing);
      expect(thumb('self'), findsOneWidget);
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      await f.mode(SharedContentMode.screen, canvasId: 'screen-session-2');
      await tester.pumpAndSettle();
      expect(getMain(), findsNothing);
      expect(f.repository!.commands, isEmpty);
      expect(f.media.mutations, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(f.room.dispose);
    },
  );

  testWidgets(
    'authoritative screen owner rejects stale tracks in both main and preview',
    (tester) async {
      final f = await MeetingSharingFixture.create(
        mode: SharedContentMode.screen,
        withTrack: false,
      );
      addTearDown(f.room.dispose);
      f.media.emit(
        f.media.current.copyWith(
          contentShareTrack: const SharingTrack(
            'stale',
            'someone-else',
            screen: true,
          ),
        ),
      );
      await mount(tester, f);
      expect(rendered('stale'), findsNothing);
      expect(thumb('self'), findsOneWidget);
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      expect(rendered('stale'), findsNothing);
      f.media.emit(
        f.media.current.copyWith(
          contentShareTrack: const SharingTrack('valid', 'guest', screen: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(getMain())
            .primaryParticipant
            .id,
        'self',
      );
      expect(rendered('valid'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(f.room.dispose);
    },
  );

  testWidgets(
    'complete meeting page toggles thumbnails locally and restores them on a new room',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = await MeetingSharingFixture.create();
      final second = await MeetingSharingFixture.create();
      addTearDown(first.room.dispose);
      addTearDown(second.room.dispose);
      Widget page(MeetingSharingFixture f) => MaterialApp(
        home: RealtimeMeetingPage(room: f.room, showClassroom: false),
      );
      await tester.pumpWidget(page(first));
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingParticipantStrip), findsOneWidget);
      await tester.tap(find.byTooltip('Hide thumbnails'));
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingParticipantStrip), findsNothing);
      expect(rendered('screen'), findsOneWidget);
      first.media.emit(
        first.media.current.copyWith(clearContentShareTrack: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingParticipantStrip), findsNothing);
      first.media.emit(
        first.media.current.copyWith(
          contentShareTrack: const SharingTrack(
            'new-share',
            'guest',
            screen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show thumbnails'), findsOneWidget);
      await tester.tap(find.byTooltip('Show thumbnails'));
      await tester.pumpAndSettle();
      expect(thumb('self'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide thumbnails'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(second));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide thumbnails'), findsOneWidget);
      expect(thumb('self'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Participants'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Participants'));
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingSidePanel), findsOneWidget);
      final strip = tester.getRect(
        find.byType(RealtimeMeetingParticipantStrip),
      );
      final panel = tester.getRect(find.byType(RealtimeMeetingSidePanel));
      expect(strip.right, lessThanOrEqualTo(panel.left));

      expect(first.media.mutations, isEmpty);
      expect(second.media.mutations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sharing controls and previews fit compact, tablet and desktop panes with safe areas and large text',
    (tester) async {
      final f = await MeetingSharingFixture.create();
      addTearDown(f.room.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
      addTearDown(tester.view.resetViewPadding);
      for (final size in [
        const Size(320, 640),
        const Size(768, 900),
        const Size(1280, 800),
        const Size(740, 390),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: RealtimeStrings.supportedLocales,
            localizationsDelegates: RealtimeStrings.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 320 ? 2 : 1),
              ),
              child: child!,
            ),
            home: RealtimeMeetingPage(room: f.room, showClassroom: false),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('隐藏缩略图'), findsOneWidget);
        final strip = find.byType(RealtimeMeetingParticipantStrip);
        final dock = find.byType(RealtimeMeetingDock);
        expect(
          tester.getRect(strip).bottom,
          lessThanOrEqualTo(tester.getRect(dock).top),
        );
        await tester.tap(thumb('self'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('meeting-return-to-content')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byTooltip('隐藏缩略图'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('隐藏缩略图'));
        await tester.pumpAndSettle();
        expect(strip, findsNothing);
        expect(find.byTooltip('显示缩略图'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('meeting-return-to-content')),
        );
        await tester.pumpAndSettle();
        expect(rendered('screen'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('显示缩略图'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('显示缩略图'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'sharing replaces the layout bar and merges whiteboard tools into the meeting rail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final mode in [
        SharedContentMode.whiteboard,
        SharedContentMode.screen,
      ]) {
        final f = await MeetingSharingFixture.create(
          mode: mode,
          withTrack: mode == SharedContentMode.screen,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: RealtimeUiTheme.light(),
            home: RealtimeMeetingPage(room: f.room, showClassroom: false),
          ),
        );
        await tester.pumpAndSettle();

        // Shared content keeps the whole stage height: the camera layout row
        // only exists as rail toggles and is hidden while sharing.
        // There must be exactly one left-hand rail. Meeting navigation stays
        // reachable, and whiteboard controls append within the same scroller.
        expect(find.byType(RealtimeMeetingRail), findsOneWidget);
        if (mode == SharedContentMode.whiteboard) {
          expect(find.byType(WhiteboardToolRail), findsOneWidget);
          final rail = find.byType(RealtimeMeetingRail);
          expect(
            find.descendant(of: rail, matching: find.byTooltip('Participants')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: rail, matching: find.byTooltip('Pen')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: find.byType(WhiteboardView), matching: rail),
            findsNothing,
          );
        } else {
          expect(find.byType(WhiteboardToolRail), findsNothing);
        }
        // The thumbnail control stays reachable from the always-visible dock.
        expect(find.byTooltip('Hide thumbnails'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(f.room.dispose);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'whiteboard tools and participant previews fit a phone while preserving host extensions',
    (tester) async {
      final f = await MeetingSharingFixture.create(
        mode: SharedContentMode.whiteboard,
        withTrack: false,
      );
      addTearDown(f.room.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeMeetingPage(
            room: f.room,
            participantBuilder: (context, participant, renderer) => ColoredBox(
              key: ValueKey('custom-${participant.id}'),
              color: Colors.teal,
            ),
            stageOverlayBuilder: (_) => const Align(
              alignment: Alignment.topLeft,
              child: Text('Host overlay'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WhiteboardView), findsOneWidget);
      expect(find.byType(RealtimeMeetingParticipantStrip), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-self')), findsOneWidget);
      expect(find.text('Host overlay'), findsOneWidget);
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('custom-self')), findsOneWidget);
      expect(find.byType(AnnotationToolbar), findsNothing);
      await tester.tap(find.byKey(const ValueKey('meeting-return-to-content')));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: RealtimeMeetingPage(room: f.room),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WhiteboardView), findsOneWidget);
      expect(find.byType(RealtimeMeetingParticipantStrip), findsOneWidget);
      expect(f.repository!.commands, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(f.room.dispose);
    },
  );
  testWidgets(
    'camera focus survives sharing, responsive reparenting and return to the previous layout',
    (tester) async {
      final f = await MeetingSharingFixture.create(withTrack: false);
      addTearDown(f.room.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeMeetingPage(room: f.room, showClassroom: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(thumb('self'));
      await tester.pumpAndSettle();
      f.media.emit(
        f.media.current.copyWith(
          contentShareTrack: const SharingTrack(
            'screen',
            'guest',
            screen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RealtimeMeetingFilmstripStage), findsNothing);
      await tester.tap(thumb('guest'));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(getMain())
            .primaryParticipant
            .id,
        'guest',
      );
      f.media.emit(f.media.current.copyWith(clearContentShareTrack: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(getMain())
            .primaryParticipant
            .id,
        'self',
      );
      expect(f.media.mutations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
