import 'package:test/test.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

AnnotationShape shape(String id, AnnotationTool tool) => AnnotationShape(
  id: id,
  tool: tool,
  points: const [AnnotationPoint(.1, .2), AnnotationPoint(.4, .5)],
  text: tool == AnnotationTool.text ? 'Lesson' : '',
);
void main() {
  test(
    'standalone session draws every tool, appends, undoes and clears',
    () async {
      final board = WhiteboardSession.local();
      await board.start();
      for (final tool in AnnotationTool.values) {
        await board.begin(
          shape(tool.name, tool),
          canvasId: board.canvas.canvasId,
        );
      }
      expect(board.canvas.shapes.length, 5);
      await board.append('pen', const [
        AnnotationPoint(.6, .7),
      ], canvasId: board.canvas.canvasId);
      expect(board.canvas.shapes.first.points.length, 3);
      await board.undo();
      expect(board.canvas.shapes.length, 4);
      await board.clear();
      expect(board.canvas.shapes, isEmpty);
      await board.dispose();
    },
  );
  test(
    'pages retain marks, reject delayed writes and cannot delete last page',
    () async {
      final board = WhiteboardSession.local(maxPages: 3);
      await board.start();
      final first = board.state!.activePageId,
          oldCanvas = board.canvas.canvasId;
      await board.begin(
        shape('first', AnnotationTool.circle),
        canvasId: oldCanvas,
      );
      await board.addPage();
      final second = board.state!.activePageId;
      await expectLater(
        board.begin(shape('late', AnnotationTool.pen), canvasId: oldCanvas),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await board.addPage();
      await expectLater(
        board.addPage(),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await board.deletePage(board.state!.activePageId);
      expect(board.state!.activePageId, second);
      await board.selectPage(first);
      expect(board.canvas.shapes.single.id, 'first');
      expect(board.canvas.canvasId, isNot(oldCanvas));
      await expectLater(
        board.begin(shape('late', AnnotationTool.pen), canvasId: oldCanvas),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await board.deletePage(first);
      expect(board.state!.activePageId, second);
      await expectLater(
        board.deletePage(second),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await board.dispose();
    },
  );
  test(
    'repository validates authority, revisions, coordinates and event replays',
    () async {
      final repo = MemoryWhiteboardRepository();
      final state = await repo.snapshot();
      final data = {
        'expectedRevision': state.revision,
        'pageId': state.activePageId,
        'canvasId': state.canvas.canvasId,
        ...shape('stroke', AnnotationTool.pen).toJson(),
      };
      final first = await repo.action(
        WhiteboardCommand(WhiteboardAction.begin, data, eventId: 'event-1'),
      );
      final replay = await repo.action(
        WhiteboardCommand(WhiteboardAction.begin, data, eventId: 'event-1'),
      );
      expect(replay.revision, first.revision);
      expect(replay.canvas.shapes.length, 1);
      await expectLater(
        repo.action(
          WhiteboardCommand(WhiteboardAction.clear, data, eventId: 'event-1'),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await expectLater(
        repo.action(
          WhiteboardCommand(WhiteboardAction.begin, data, eventId: 'event-2'),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await expectLater(
        repo.action(
          WhiteboardCommand(WhiteboardAction.begin, {
            ...data,
            'expectedRevision': first.revision,
            'id': 'bad',
            'points': [
              {'x': 2, 'y': 0},
            ],
          }, eventId: 'bad'),
        ),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidArgument,
          ),
        ),
      );
      await repo.close();
      final readOnly = WhiteboardSession.local(canEdit: false);
      await readOnly.start();
      await expectLater(
        readOnly.addPage(),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await readOnly.dispose();
    },
  );
  test(
    'automatic previous-page activation rejects earlier canvas writes',
    () async {
      final board = WhiteboardSession.local();
      await board.start();
      final oldCanvas = board.canvas.canvasId;
      await board.begin(shape('keep', AnnotationTool.pen), canvasId: oldCanvas);
      await board.addPage();
      await board.deletePage(board.state!.activePageId);
      expect(board.canvas.shapes.single.id, 'keep');
      expect(board.canvas.canvasId, isNot(oldCanvas));
      await expectLater(
        board.begin(shape('delayed', AnnotationTool.pen), canvasId: oldCanvas),
        throwsA(
          isA<RealtimeException>().having(
            (e) => e.code,
            'code',
            RealtimeErrorCode.invalidState,
          ),
        ),
      );
      await board.dispose();
    },
  );
  test(
    'late session loads current page and retained marks from shared repository',
    () async {
      final repo = MemoryWhiteboardRepository();
      final teacher = WhiteboardSession(repo, ownsRepository: false);
      await teacher.start();
      await teacher.addPage();
      await teacher.begin(
        shape('note', AnnotationTool.text),
        canvasId: teacher.canvas.canvasId,
      );
      final late = WhiteboardSession(repo, ownsRepository: false);
      await late.start();
      expect(late.state!.pages.length, 2);
      expect(late.canvas.shapes.single.text, 'Lesson');
      await teacher.clear();
      await late.refresh();
      expect(late.canvas.shapes, isEmpty);
      await teacher.dispose();
      await late.dispose();
      await repo.close();
    },
  );
}
