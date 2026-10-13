import 'classroom_state.dart';
import 'classroom_command.dart';

abstract interface class ClassroomRepository {
  Future<ClassroomState> snapshot();
  Future<ClassroomState> action(ClassroomCommand command);
  void close();
}
