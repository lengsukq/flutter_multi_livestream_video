import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tool_kind.dart';

class ClassroomPublishToolDialog extends StatefulWidget {
  const ClassroomPublishToolDialog({
    required this.kind,
    required this.classroom,
    required this.strings,
    this.onActionError,
  });

  final ClassroomToolKind kind;
  final ClassroomSession classroom;
  final ClassroomStrings strings;
  final ValueChanged<RealtimeException>? onActionError;

  @override
  State<ClassroomPublishToolDialog> createState() =>
      ClassroomPublishToolDialogState();
}

class ClassroomPublishToolDialogState
    extends State<ClassroomPublishToolDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _seconds;
  late final TextEditingController _due;
  int? _correct;
  var _options = <String>[];
  Object? _dialogError;
  var _publishing = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _body = TextEditingController();
    _seconds = TextEditingController(text: '300');
    _due = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _seconds.dispose();
    _due.dispose();
    super.dispose();
  }

  List<String> _extractOptions(String text) => text
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind.name;
    final strings = widget.strings;
    final activity = kind == 'quiz' || kind == 'poll';
    final single = kind == 'announcement' || kind == 'focus';
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    final iconData = switch (kind) {
      'announcement' => Icons.campaign_outlined,
      'focus' => Icons.center_focus_strong,
      'homework' => Icons.assignment_outlined,
      'materials' => Icons.attach_file,
      'timer' => Icons.timer_outlined,
      'quiz' => Icons.quiz_outlined,
      'poll' => Icons.poll_outlined,
      _ => Icons.widgets_outlined,
    };

    final style = RealtimeStyle.of(context);

    return AlertDialog(
      backgroundColor: style.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        side: BorderSide(color: style.border),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: style.primarySubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: style.primaryBorder),
            ),
            child: Icon(iconData, size: 20, color: style.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              strings.t(kind),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: style.text,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                enabled: !_publishing,
                maxLength: single ? 1000 : 120,
                style: TextStyle(fontSize: 14, color: style.text),
                decoration: InputDecoration(
                  labelText: strings.t(single ? 'text' : 'title'),
                  labelStyle: TextStyle(color: style.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: BorderSide(color: style.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: BorderSide(color: style.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: BorderSide(color: style.primary, width: 1.5),
                  ),
                ),
              ),
              if (!single && kind != 'timer')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _body,
                    enabled: !_publishing,
                    maxLines: activity ? 5 : 3,
                    maxLength: 2000,
                    style: TextStyle(fontSize: 14, color: style.text),
                    onChanged: activity
                        ? (value) => setState(() {
                            final selected =
                                _correct != null && _correct! < _options.length
                                ? _options[_correct!]
                                : null;
                            _options = _extractOptions(value);
                            _correct =
                                selected != null &&
                                    _options
                                            .where((v) => v == selected)
                                            .length ==
                                        1
                                ? _options.indexOf(selected)
                                : null;
                            _dialogError = null;
                          })
                        : null,
                    decoration: InputDecoration(
                      labelText: strings.t(
                        activity
                            ? 'options'
                            : kind == 'materials'
                            ? 'link'
                            : 'text',
                      ),
                      labelStyle: TextStyle(color: style.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(
                          color: style.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (kind == 'timer')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _seconds,
                    enabled: !_publishing,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, color: style.text),
                    decoration: InputDecoration(
                      labelText: strings.t('seconds'),
                      labelStyle: TextStyle(color: style.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(
                          color: style.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (kind == 'homework')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _due,
                    enabled: !_publishing,
                    style: TextStyle(fontSize: 14, color: style.text),
                    decoration: InputDecoration(
                      labelText: 'YYYY-MM-DD (optional)',
                      labelStyle: TextStyle(color: style.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(
                          color: style.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (kind == 'quiz')
                DropdownButtonFormField<int>(
                  key: ValueKey((_options.join('\n'), _correct)),
                  initialValue: _correct,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.t('correct'),
                    labelStyle: TextStyle(color: style.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      borderSide: BorderSide(color: style.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      borderSide: BorderSide(color: style.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      borderSide: BorderSide(color: style.primary, width: 1.5),
                    ),
                  ),
                  items: List.generate(
                    _options.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(
                        '${index + 1}. ${_options[index]}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: style.text),
                      ),
                    ),
                  ),
                  onChanged: _publishing
                      ? null
                      : (value) => setState(() {
                          _correct = value;
                          _dialogError = null;
                        }),
                ),
              if (_publishing)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(
                    color: style.primary,
                    backgroundColor: style.primarySubtle,
                  ),
                ),
              if (_dialogError != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: style.dangerSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: style.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: style.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$_dialogError',
                          style: TextStyle(
                            color: style.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _publishing ? null : () => Navigator.of(context).pop(),
          child: Text(
            strings.t('cancel'),
            style: TextStyle(color: style.textMuted),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: style.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
            ),
          ),
          onPressed: _publishing
              ? null
              : () async {
                  if (activity) {
                    _options = _extractOptions(_body.text);
                    final invalid = _options.length < 2 || _options.length > 8
                        ? (zh ? '请输入 2–8 个选项。' : 'Enter 2–8 options.')
                        : _options.toSet().length != _options.length
                        ? (zh ? '选项不能重复。' : 'Options must be distinct.')
                        : kind == 'quiz' &&
                              (_correct == null || _correct! >= _options.length)
                        ? (zh
                              ? '请选择有效的正确答案。'
                              : 'Select a valid correct answer.')
                        : null;
                    if (invalid != null) {
                      setState(() => _dialogError = invalid);
                      return;
                    }
                  }
                  setState(() {
                    _publishing = true;
                    _dialogError = null;
                  });
                  try {
                    final session = widget.classroom;
                    switch (kind) {
                      case 'announcement':
                        await session.publishAnnouncement(_title.text.trim());
                      case 'focus':
                        await session.remindFocus(_title.text.trim());
                      case 'homework':
                        final dueText = _due.text.trim();
                        final dueAt = dueText.isEmpty
                            ? null
                            : DateTime.tryParse(dueText);
                        if (dueText.isNotEmpty && dueAt == null) {
                          throw const FormatException('Invalid due date');
                        }
                        await session.publishHomework(
                          title: _title.text.trim(),
                          instructions: _body.text.trim(),
                          dueAt: dueAt,
                        );
                      case 'materials':
                        await session.shareMaterial(
                          title: _title.text.trim(),
                          url: _body.text.trim(),
                        );
                      case 'timer':
                        final duration = int.tryParse(_seconds.text.trim());
                        if (duration == null) {
                          throw const FormatException(
                            'Use a duration in seconds',
                          );
                        }
                        await session.startTimer(
                          title: _title.text.trim(),
                          duration: Duration(seconds: duration),
                        );
                      case 'quiz':
                      case 'poll':
                        await session.publishActivity(
                          kind: kind == 'quiz'
                              ? ClassroomActivityKind.quiz
                              : ClassroomActivityKind.poll,
                          title: _title.text.trim(),
                          options: _options,
                          correctOption: kind == 'quiz' ? _correct : null,
                        );
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (error, stack) {
                    final failure = normalizeRealtimeException(
                      error,
                      domain: "classroom.ui.publish",
                      stackTrace: stack,
                    );
                    widget.onActionError?.call(failure);
                    if (context.mounted) {
                      setState(() {
                        _publishing = false;
                        _dialogError = failure;
                      });
                    }
                  }
                },
          child: Text(strings.t('publish')),
        ),
      ],
    );
  }
}
