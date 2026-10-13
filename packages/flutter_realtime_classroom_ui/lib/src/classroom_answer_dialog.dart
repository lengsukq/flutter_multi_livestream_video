import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
class ClassroomAnswerDialog extends StatefulWidget {
  const ClassroomAnswerDialog({
    required this.initialValue,
    required this.strings,
  });

  final String initialValue;
  final ClassroomStrings strings;

  @override
  State<ClassroomAnswerDialog> createState() => ClassroomAnswerDialogState();
}

class ClassroomAnswerDialogState extends State<ClassroomAnswerDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RealtimeGlassDialog(
    icon: Icons.question_answer_rounded,
    title: Text(widget.strings.t('answer')),
    content: TextField(
      controller: _controller,
      maxLength: 500,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: widget.strings.t('answer'),
        filled: true,
        fillColor: RealtimeUiTokens.surfaceSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          borderSide: const BorderSide(color: RealtimeUiTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          borderSide: const BorderSide(color: RealtimeUiTokens.border),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.strings.t('cancel')),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: RealtimeUiTokens.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          ),
        ),
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(widget.strings.t('submit')),
      ),
    ],
  );
}
