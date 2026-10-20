import 'dart:async';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'shared_content_command.dart';

/// Inject a trusted control plane without creating a classroom session.
abstract class SharedContentRepository {
  Stream<SharedContentState?> get states => const Stream.empty();
  Future<SharedContentState?> snapshot();
  Future<SharedContentState?> action(SharedContentCommand command);
  FutureOr<void> close();
}
