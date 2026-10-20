import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'shared_content_command.dart';
import 'shared_content_repository.dart';

/// Compatibility adapter over an existing classroom control plane.
/// Only the shared canvas is exposed to the shared-content session.
class ClassroomSharedContentRepository extends SharedContentRepository {
  ClassroomSharedContentRepository(this.repository, {this.classroom});
  final ClassroomRepository repository;
  final ClassroomSession? classroom;

  SharedContentState? _content(ClassroomState state) {
    final content = state.tools?.content;
    if (content == null) return null;
    return SharedContentState(
      mode: content.mode,
      whiteboard: content.whiteboard,
      screen: content.screen,
      canManage: content.canManage,
      canShareScreen: content.canShareScreen,
      canAnnotateScreen: content.canAnnotateScreen,
      revision: content.revision,
      snapshotRevision: state.revision,
    );
  }

  @override
  Stream<SharedContentState?> get states =>
      classroom?.states.map(_content) ?? const Stream.empty();

  @override
  Future<SharedContentState?> snapshot() async {
    final borrowed = classroom;
    if (borrowed != null) {
      await borrowed.refresh();
      return _content(borrowed.state!);
    }
    return _content(await repository.snapshot());
  }

  @override
  Future<SharedContentState?> action(SharedContentCommand command) async {
    final board = command.whiteboard;
    final translated = board != null
        ? ClassroomCommand.whiteboard(board)
        : ClassroomCommand.tool(
            ClassroomToolAction.values.firstWhere(
              (action) => action.wireName == command.action!.wireName,
            ),
            command.payload,
          );
    final borrowed = classroom;
    if (borrowed != null) {
      await borrowed.execute(translated);
      return _content(borrowed.state!);
    }
    return _content(await repository.action(translated));
  }

  @override
  void close() {
    if (classroom == null) repository.close();
  }
}
