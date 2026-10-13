import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'classroom_command_presenter.dart';

typedef ClassroomToolCommand =
    Future<void> Function(Future<void> Function() action);

class ClassroomToolCommandBuilder extends StatefulWidget {
  const ClassroomToolCommandBuilder({
    super.key,
    required this.builder,
    this.onActionError,
  });
  final Widget Function(
    BuildContext context,
    ClassroomToolCommand run,
    bool pending,
  )
  builder;
  final ValueChanged<RealtimeException>? onActionError;
  @override
  State<ClassroomToolCommandBuilder> createState() =>
      _ClassroomToolCommandBuilderState();
}

class _ClassroomToolCommandBuilderState
    extends State<ClassroomToolCommandBuilder> {
  late final ClassroomCommandPresenter _commands = ClassroomCommandPresenter(
    onChanged: () {
      if (mounted) setState(() {});
    },
    onError: (error) => widget.onActionError?.call(error),
  );
  @override
  void dispose() {
    _commands.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _commands.run, _commands.pending);
}
